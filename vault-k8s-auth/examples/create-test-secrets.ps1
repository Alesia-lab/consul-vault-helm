# Script para crear secretos de prueba en Vault usando la API REST
# Este script NO requiere el CLI de Vault, solo Invoke-RestMethod (PowerShell nativo)
# Estos secretos se usarán para probar el acceso desde pods
# Versión PowerShell

$ErrorActionPreference = "Stop"

# Configurar estas variables según tu entorno
$VAULT_ADDR = if ($env:VAULT_ADDR) { $env:VAULT_ADDR } else { "https://k8s-vault-vaultui-62506ffd89-622e5694cde0e9a6.elb.us-east-1.amazonaws.com" }
$VAULT_TOKEN = $env:VAULT_TOKEN
$KV_MOUNT_PATH = if ($env:KV_MOUNT_PATH) { $env:KV_MOUNT_PATH } else { "secret" }

if (-not $VAULT_TOKEN) {
    Write-Host "Error: VAULT_TOKEN no esta configurado" -ForegroundColor Red
    Write-Host "Configura la variable: `$env:VAULT_TOKEN='tu-token-aqui'"
    exit 1
}

# Normalizar VAULT_ADDR (remover trailing slash)
$VAULT_ADDR = $VAULT_ADDR.TrimEnd('/')

Write-Host "=========================================="
Write-Host "Creando secretos de prueba en Vault"
Write-Host "=========================================="
Write-Host "Vault Address: $VAULT_ADDR"
Write-Host "KV Mount Path: $KV_MOUNT_PATH"
Write-Host ""

# Funcion para hacer requests a la API de Vault
function Invoke-VaultApiRequest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Method,
        
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [string]$Data,
        
        [Parameter(Mandatory=$false)]
        [switch]$ShowErrors
    )
    
    $url = "$VAULT_ADDR/v1/$Path"
    $headers = @{
        "X-Vault-Token" = $VAULT_TOKEN
        "Content-Type" = "application/json"
    }
    
    # Detectar si es PowerShell Core (6.0+) o Windows PowerShell (5.1)
    $isPowerShellCore = $PSVersionTable.PSVersion.Major -ge 6
    $isHttps = $url -like "https://*"
    
    # Configurar para ignorar certificados SSL si es necesario (solo para PowerShell 5.1 con HTTPS)
    if ($isHttps -and -not $isPowerShellCore) {
        # Para PowerShell 5.1, necesitamos configurar el callback de validación de certificados
        add-type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }
    
    try {
        $params = @{
            Uri = $url
            Method = $Method
            Headers = $headers
        }
        
        # Agregar -SkipCertificateCheck solo si es PowerShell Core y HTTPS
        if ($isHttps -and $isPowerShellCore) {
            $params['SkipCertificateCheck'] = $true
        }
        
        if ($Method -eq "GET") {
            $response = Invoke-RestMethod @params
            return $response
        }
        elseif ($Method -eq "PUT" -or $Method -eq "POST") {
            $params['Body'] = $Data
            $response = Invoke-RestMethod @params
            return $response
        }
        else {
            Write-Error "Error: Metodo HTTP no soportado: $Method"
            return $null
        }
    }
    catch {
        if ($ShowErrors) {
            Write-Host "   Error en peticion HTTP: $($_.Exception.Message)" -ForegroundColor Yellow
            if ($_.Exception.Response) {
                try {
                    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $responseBody = $reader.ReadToEnd()
                    Write-Host "   Respuesta del servidor: $responseBody" -ForegroundColor Yellow
                }
                catch {
                    # No se pudo leer la respuesta
                }
            }
        }
        return $null
    }
    finally {
        # Restaurar la política de certificados por defecto si la cambiamos
        if ($isHttps -and -not $isPowerShellCore) {
            [System.Net.ServicePointManager]::CertificatePolicy = $null
        }
    }
}

# Funcion para crear un secreto en KV v2
function New-KvSecret {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SecretPath,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$KeyValuePairs
    )
    
    # Construir el objeto JSON con los pares clave-valor
    $dataObject = @{}
    foreach ($key in $KeyValuePairs.Keys) {
        $dataObject[$key] = $KeyValuePairs[$key]
    }
    
    # Crear el payload completo para KV v2
    $payload = @{
        data = $dataObject
    } | ConvertTo-Json -Compress
    
    # Hacer la peticion PUT a la API
    $apiPath = "$KV_MOUNT_PATH/data/$SecretPath"
    
    $result = Invoke-VaultApiRequest -Method "PUT" -Path $apiPath -Data $payload -ShowErrors
    return $result -ne $null
}

# Verificar conexion a Vault
Write-Host "Verificando conexion a Vault..."

$connectionOk = $false
try {
    $healthUrl = "$VAULT_ADDR/v1/sys/health"
    $healthHeaders = @{
        "X-Vault-Token" = $VAULT_TOKEN
    }
    
    # Detectar versión de PowerShell para usar el método apropiado
    $isPowerShellCore = $PSVersionTable.PSVersion.Major -ge 6
    $isHttps = $healthUrl -like "https://*"
    
    # Configurar para ignorar certificados SSL si es necesario (solo para PowerShell 5.1 con HTTPS)
    if ($isHttps -and -not $isPowerShellCore) {
        add-type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }
    
    try {
        $webParams = @{
            Uri = $healthUrl
            Method = "Get"
            Headers = $healthHeaders
            UseBasicParsing = $true
        }
        
        # Agregar -SkipCertificateCheck solo si es PowerShell Core y HTTPS
        if ($isHttps -and $isPowerShellCore) {
            $webParams['SkipCertificateCheck'] = $true
        }
        
        $healthResponse = Invoke-WebRequest @webParams
        $statusCode = $healthResponse.StatusCode
        
        # Verificar que el token es valido (codigos 200, 429, 472, 473 son validos para /sys/health)
        # Codigos de error comunes: 403 (forbidden), 401 (unauthorized)
        if ($statusCode -eq 403 -or $statusCode -eq 401) {
            Write-Host "Error: VAULT_TOKEN no es valido o no tiene permisos" -ForegroundColor Red
            Write-Host "Verifica que el token sea correcto y tenga los permisos necesarios"
            exit 1
        }
        $connectionOk = $true
    }
    catch {
        # Intentar obtener el codigo de estado si esta disponible
        $statusCode = $null
        if ($null -ne $_.Exception) {
            if ($null -ne $_.Exception.Response) {
                try {
                    $statusCode = $_.Exception.Response.StatusCode.value__
                }
                catch {
                    # No se puede obtener el codigo de estado
                }
            }
        }
        
        if ($null -ne $statusCode) {
            if ($statusCode -eq 403 -or $statusCode -eq 401) {
                Write-Host "Error: VAULT_TOKEN no es valido o no tiene permisos" -ForegroundColor Red
                Write-Host "Verifica que el token sea correcto y tenga los permisos necesarios"
                exit 1
            }
            # Otros codigos (429, 472, 473) son validos para health check
            $connectionOk = $true
        }
    }
    finally {
        # Restaurar la política de certificados por defecto si la cambiamos
        if ($isHttps -and -not $isPowerShellCore) {
            [System.Net.ServicePointManager]::CertificatePolicy = $null
        }
    }
}
catch {
    Write-Host "Error: No se puede conectar a Vault" -ForegroundColor Red
    Write-Host "Verifica:"
    Write-Host "  - VAULT_ADDR esta correcto: $VAULT_ADDR"
    Write-Host "  - El servidor de Vault es accesible"
    Write-Host "  - No hay problemas de red o firewall"
    exit 1
}

if ($connectionOk) {
    Write-Host "[OK] Conexion a Vault verificada" -ForegroundColor Green
}

Write-Host ""

# Crear secretos de prueba
Write-Host "1. Creando secreto ${KV_MOUNT_PATH}/app/database..."
$dbSecret = @{
    username = "dbuser"
    password = "dbpass123"
    host = "db.example.com"
    port = "5432"
}
if (New-KvSecret -SecretPath "app/database" -KeyValuePairs $dbSecret) {
    Write-Host "   [OK] Secreto creado exitosamente" -ForegroundColor Green
}
else {
    Write-Host "   [ERROR] Error al crear el secreto" -ForegroundColor Red
    exit 1
}

Write-Host "2. Creando secreto ${KV_MOUNT_PATH}/app/api-key..."
$apiSecret = @{
    api_key = "sk-1234567890abcdef"
    api_secret = "secret-key-12345"
}
if (New-KvSecret -SecretPath "app/api-key" -KeyValuePairs $apiSecret) {
    Write-Host "   [OK] Secreto creado exitosamente" -ForegroundColor Green
}
else {
    Write-Host "   [ERROR] Error al crear el secreto" -ForegroundColor Red
    exit 1
}

Write-Host "3. Creando secreto ${KV_MOUNT_PATH}/app/config..."
$configSecret = @{
    environment = "production"
    log_level = "info"
    max_connections = "100"
}
if (New-KvSecret -SecretPath "app/config" -KeyValuePairs $configSecret) {
    Write-Host "   [OK] Secreto creado exitosamente" -ForegroundColor Green
}
else {
    Write-Host "   [ERROR] Error al crear el secreto" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Secretos creados exitosamente"
Write-Host "=========================================="
Write-Host ""
Write-Host "Secretos disponibles:"
Write-Host "  - ${KV_MOUNT_PATH}/app/database"
Write-Host "  - ${KV_MOUNT_PATH}/app/api-key"
Write-Host "  - ${KV_MOUNT_PATH}/app/config"
Write-Host ""
Write-Host "Verificar secretos usando la API:"
Write-Host "  Invoke-RestMethod -Uri `"${VAULT_ADDR}/v1/${KV_MOUNT_PATH}/data/app/database`" -Headers @{`"X-Vault-Token`"=`"`$env:VAULT_TOKEN`"} -SkipCertificateCheck"
Write-Host ""
