# Script para limpiar los recursos creados por setup-test.ps1 y create-test-secrets.ps1
# Este script elimina:
# - Secretos de prueba en Vault
# - Namespace y ServiceAccount en Kubernetes
# - Pods/Deployments de prueba
# Versión PowerShell

$ErrorActionPreference = "Stop"

$NAMESPACE = "app"
$SERVICE_ACCOUNT = "app-sa"
$VAULT_ADDR = if ($env:VAULT_ADDR) { $env:VAULT_ADDR } else { "https://k8s-vault-vaultui-62506ffd89-622e5694cde0e9a6.elb.us-east-1.amazonaws.com" }
$VAULT_TOKEN = $env:VAULT_TOKEN

Write-Host "=========================================="
Write-Host "Limpiando recursos de prueba"
Write-Host "=========================================="
Write-Host ""

# ============================================================================
# Limpiar recursos de Kubernetes
# ============================================================================

Write-Host "1. Limpiando recursos de Kubernetes..."

# Verificar si kubectl está disponible
$kubectlAvailable = $false
try {
    $null = Get-Command kubectl -ErrorAction Stop
    $kubectlAvailable = $true
}
catch {
    Write-Host "   ⚠️  kubectl no está disponible, saltando limpieza de Kubernetes" -ForegroundColor Yellow
}

if ($kubectlAvailable) {
    # Eliminar pods de prueba
    try {
        $null = kubectl get pod vault-test -n $NAMESPACE 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   - Eliminando pod vault-test..."
            kubectl delete pod vault-test -n $NAMESPACE --ignore-not-found=true 2>&1 | Out-Null
        }
    }
    catch {
        # Pod no existe, continuar
    }

    # Eliminar deployments de prueba
    try {
        $null = kubectl get deployment vault-test-app -n $NAMESPACE 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   - Eliminando deployment vault-test-app..."
            kubectl delete deployment vault-test-app -n $NAMESPACE --ignore-not-found=true 2>&1 | Out-Null
        }
    }
    catch {
        # Deployment no existe, continuar
    }

    # Eliminar otros deployments de prueba
    $deployments = @("vault-test-app-env-auto", "vault-test-app-env-simple")
    foreach ($deployment in $deployments) {
        try {
            $null = kubectl get deployment $deployment -n $NAMESPACE 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   - Eliminando deployment $deployment..."
                kubectl delete deployment $deployment -n $NAMESPACE --ignore-not-found=true 2>&1 | Out-Null
            }
        }
        catch {
            # Deployment no existe, continuar
        }
    }

    # Eliminar ServiceAccount
    try {
        $null = kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   - Eliminando ServiceAccount $SERVICE_ACCOUNT..."
            kubectl delete serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE --ignore-not-found=true 2>&1 | Out-Null
        }
    }
    catch {
        # ServiceAccount no existe, continuar
    }

    # Eliminar namespace (solo si está vacío)
    try {
        $null = kubectl get namespace $NAMESPACE 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            # Verificar si el namespace tiene otros recursos
            $resources = kubectl get all -n $NAMESPACE --no-headers 2>&1
            if ($LASTEXITCODE -eq 0 -and $resources.Count -eq 0) {
                Write-Host "   - Eliminando namespace $NAMESPACE (está vacío)..."
                kubectl delete namespace $NAMESPACE --ignore-not-found=true 2>&1 | Out-Null
            }
            else {
                Write-Host "   ⚠️  Namespace $NAMESPACE contiene otros recursos, no se eliminará automáticamente" -ForegroundColor Yellow
                Write-Host "   Para eliminarlo manualmente: kubectl delete namespace $NAMESPACE"
            }
        }
    }
    catch {
        # Namespace no existe, continuar
    }

    Write-Host "   ✓ Recursos de Kubernetes limpiados" -ForegroundColor Green
}

Write-Host ""

# ============================================================================
# Limpiar secretos de Vault
# ============================================================================

Write-Host "2. Limpiando secretos de Vault..."

$KV_MOUNT_PATH = if ($env:KV_MOUNT_PATH) { $env:KV_MOUNT_PATH } else { "secret" }

# Verificar conexión a Vault
if (-not $VAULT_TOKEN) {
    Write-Host "   ⚠️  VAULT_TOKEN no está configurado" -ForegroundColor Yellow
    Write-Host "   Configura la variable: `$env:VAULT_TOKEN='tu-token-aqui'"
}
else {
    # Normalizar VAULT_ADDR (remover trailing slash)
    $VAULT_ADDR = $VAULT_ADDR.TrimEnd('/')
    
    # Función para hacer requests a la API de Vault
    function Invoke-VaultApiRequest {
        param(
            [Parameter(Mandatory=$true)]
            [string]$Method,
            
            [Parameter(Mandatory=$true)]
            [string]$Path
        )
        
        $url = "$VAULT_ADDR/v1/$Path"
        $headers = @{
            "X-Vault-Token" = $VAULT_TOKEN
            "Content-Type" = "application/json"
        }
        
        try {
            if ($Method -eq "GET") {
                $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -SkipCertificateCheck
                return $response
            }
            elseif ($Method -eq "DELETE") {
                $response = Invoke-RestMethod -Uri $url -Method Delete -Headers $headers -SkipCertificateCheck
                return $response
            }
            else {
                return $null
            }
        }
        catch {
            return $null
        }
    }
    
    # Verificar conexión
    try {
        $healthUrl = "$VAULT_ADDR/v1/sys/health"
        $healthHeaders = @{
            "X-Vault-Token" = $VAULT_TOKEN
        }
        $null = Invoke-WebRequest -Uri $healthUrl -Method Get -Headers $healthHeaders -SkipCertificateCheck -UseBasicParsing
    }
    catch {
        Write-Host "   ⚠️  No se puede conectar a Vault" -ForegroundColor Yellow
        Write-Host "   Verifica VAULT_ADDR y VAULT_TOKEN"
    }
    
    # Eliminar secretos usando DELETE en el metadata path (KV v2)
    $secrets = @(
        "app/database",
        "app/api-key",
        "app/config"
    )

    foreach ($secret in $secrets) {
        # Verificar si el secreto existe antes de eliminarlo
        $checkPath = "$KV_MOUNT_PATH/data/$secret"
        $exists = Invoke-VaultApiRequest -Method "GET" -Path $checkPath
        
        if ($exists) {
            Write-Host "   - Eliminando ${KV_MOUNT_PATH}/${secret}..."
            # En KV v2, se elimina usando el metadata path
            $deletePath = "$KV_MOUNT_PATH/metadata/$secret"
            $null = Invoke-VaultApiRequest -Method "DELETE" -Path $deletePath
        }
    }

    # Verificar si quedan secretos en el directorio app
    try {
        $listPath = "$KV_MOUNT_PATH/metadata/app"
        $listResponse = Invoke-VaultApiRequest -Method "GET" -Path $listPath
        
        if ($listResponse) {
            if ($listResponse.data -and $listResponse.data.keys) {
                Write-Host "   ⚠️  Directorio ${KV_MOUNT_PATH}/app contiene otros secretos, no se elimina" -ForegroundColor Yellow
            }
            else {
                Write-Host "   - Directorio ${KV_MOUNT_PATH}/app está vacío o no existe"
            }
        }
    }
    catch {
        # No se pudo verificar, continuar
    }

    Write-Host "   ✓ Secretos de Vault limpiados" -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Limpieza completada"
Write-Host "=========================================="
Write-Host ""
Write-Host "Recursos eliminados:"
Write-Host "  ✓ Pods y Deployments de prueba"
Write-Host "  ✓ ServiceAccount: $SERVICE_ACCOUNT"
Write-Host "  ✓ Secretos de Vault: secret/app/*"
Write-Host ""
Write-Host "Nota: El namespace '$NAMESPACE' solo se elimina si está vacío."
Write-Host "      Si contiene otros recursos, elimínalo manualmente si es necesario."
Write-Host ""
