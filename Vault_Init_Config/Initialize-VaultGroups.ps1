#!/usr/bin/env pwsh
# Requiere: vault CLI configurado, VAULT_ADDR y VAULT_TOKEN establecidos

param(
    [switch]$SkipGitHubAuth
)

# Colores para output
$ErrorColor = "Red"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$InfoColor = "Cyan"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-VaultConnection {
    Write-ColorOutput "`n[INFO] Verificando conexión con Vault..." $InfoColor
    
    if (-not (Get-Command vault -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "[ERROR] El comando 'vault' no está disponible en el PATH" $ErrorColor
        exit 1
    }
    
    if (-not $env:VAULT_ADDR) {
        Write-ColorOutput "[ERROR] La variable de ambiente VAULT_ADDR no está configurada" $ErrorColor
        exit 1
    }
    
    if (-not $env:VAULT_TOKEN) {
        Write-ColorOutput "[ERROR] La variable de ambiente VAULT_TOKEN no está configurada" $ErrorColor
        exit 1
    }
    
    $status = vault status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "[ERROR] No se pudo conectar a Vault. Verifique VAULT_ADDR y VAULT_TOKEN" $ErrorColor
        Write-ColorOutput $status $ErrorColor
        exit 1
    }
    
    Write-ColorOutput "[OK] Conexión con Vault establecida correctamente" $SuccessColor
}

function Get-PolicyContent {
    param([string]$PolicyName)
    
    $policyFile = Join-Path $PSScriptRoot "$PolicyName-policy.hcl"
    if (Test-Path $policyFile) {
        return Get-Content $policyFile -Raw
    }
    Write-ColorOutput "[ERROR] No se encontró el archivo de política: $policyFile" $ErrorColor
    return $null
}

function Test-PolicyExists {
    param([string]$PolicyName)
    
    $result = vault policy read $PolicyName 2>&1
    return $LASTEXITCODE -eq 0
}

function Get-PolicyFromVault {
    param([string]$PolicyName)
    
    try {
        $result = vault policy read $PolicyName 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        return $null
    }
    return $null
}

function New-VaultPolicy {
    param(
        [string]$PolicyName,
        [string]$PolicyContent
    )
    
    Write-ColorOutput "`n[INFO] Verificando política: $PolicyName" $InfoColor
    
    $exists = Test-PolicyExists -PolicyName $PolicyName
    $expectedContent = $PolicyContent.Trim()
    
    if ($exists) {
        $currentContent = (Get-PolicyFromVault -PolicyName $PolicyName).Trim()
        
        if ($null -eq $currentContent) {
            Write-ColorOutput "[ADVERTENCIA] La política '$PolicyName' existe pero no se pudo leer su contenido" $WarningColor
            Write-ColorOutput "[ADVERTENCIA] Se omitirá la creación/actualización de esta política" $WarningColor
            return $false
        }
        
        # Normalizar comparación (eliminar espacios en blanco extra, normalizar line endings)
        $currentNormalized = ($currentContent -replace '\r\n', "`n" -replace '\r', "`n") -replace '[ \t]+', ' ' -replace '\n\s*\n', "`n" -replace '^\s+|\s+$', ''
        $expectedNormalized = ($expectedContent -replace '\r\n', "`n" -replace '\r', "`n") -replace '[ \t]+', ' ' -replace '\n\s*\n', "`n" -replace '^\s+|\s+$', ''
        
        if ($currentNormalized -eq $expectedNormalized) {
            Write-ColorOutput "[OK] La política '$PolicyName' ya existe y coincide con la esperada" $SuccessColor
            return $true
        } else {
            Write-ColorOutput "[ADVERTENCIA] La política '$PolicyName' ya existe pero NO coincide con la esperada" $WarningColor
            Write-ColorOutput "[ADVERTENCIA] Se omitirá la creación/actualización de esta política" $WarningColor
            return $false
        }
    } else {
        # Crear política temporal
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            Set-Content -Path $tempFile -Value $PolicyContent -NoNewline
            
            $result = vault policy write $PolicyName $tempFile 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "[OK] Política '$PolicyName' creada exitosamente" $SuccessColor
                return $true
            } else {
                Write-ColorOutput "[ERROR] No se pudo crear la política '$PolicyName': $result" $ErrorColor
                return $false
            }
        } finally {
            Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
        }
    }
}

function Test-GroupExists {
    param([string]$GroupName)
    
    $result = vault identity group list -format=json 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $false
    }
    
    $groups = $result | ConvertFrom-Json
    if ($groups.data.keys) {
        return $groups.data.keys -contains $GroupName
    }
    return $false
}

function Get-GroupInfo {
    param([string]$GroupName)
    
    try {
        $result = vault identity group read -name $GroupName -format=json 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $result | ConvertFrom-Json
        }
    } catch {
        return $null
    }
    return $null
}

function New-VaultGroup {
    param(
        [string]$GroupName,
        [string[]]$Policies
    )
    
    Write-ColorOutput "`n[INFO] Verificando grupo: $GroupName" $InfoColor
    
    $exists = Test-GroupExists -GroupName $GroupName
    
    if ($exists) {
        $groupInfo = Get-GroupInfo -GroupName $GroupName
        if ($groupInfo) {
            $currentPolicies = @()
            if ($groupInfo.data.policies) {
                $currentPolicies = $groupInfo.data.policies
            }
            
            # Comparar políticas (orden no importa)
            $policiesMatch = ($currentPolicies.Count -eq $Policies.Count) -and 
                            (Compare-Object $currentPolicies $Policies | Measure-Object).Count -eq 0
            
            if ($policiesMatch) {
                Write-ColorOutput "[OK] El grupo '$GroupName' ya existe y tiene las políticas correctas" $SuccessColor
                return $true
            } else {
                Write-ColorOutput "[ADVERTENCIA] El grupo '$GroupName' ya existe pero NO tiene las políticas esperadas" $WarningColor
                Write-ColorOutput "[ADVERTENCIA] Políticas actuales: $($currentPolicies -join ', ')" $WarningColor
                Write-ColorOutput "[ADVERTENCIA] Políticas esperadas: $($Policies -join ', ')" $WarningColor
                Write-ColorOutput "[ADVERTENCIA] Se omitirá la creación/actualización de este grupo" $WarningColor
                return $false
            }
        }
    } else {
        # Crear el grupo
        $policiesArg = $Policies -join ','
        # Escapar el nombre del grupo si contiene espacios o caracteres especiales
        $groupNameEscaped = "`"$GroupName`""
        $result = vault identity group create -name="$GroupName" -type=internal -policies=$policiesArg 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[OK] Grupo '$GroupName' creado exitosamente con políticas: $policiesArg" $SuccessColor
            return $true
        } else {
            Write-ColorOutput "[ERROR] No se pudo crear el grupo '$GroupName': $result" $ErrorColor
            return $false
        }
    }
}

function Enable-GitHubAuth {
    Write-ColorOutput "`n[INFO] Configurando autenticación GitHub..." $InfoColor
    
    # Verificar si GitHub auth ya está habilitado
    $authMethods = vault auth list -format=json 2>&1 | ConvertFrom-Json
    $githubEnabled = $false
    
    if ($authMethods.data) {
        $githubEnabled = $authMethods.data.PSObject.Properties.Name -contains "github/"
    }
    
    if ($githubEnabled) {
        Write-ColorOutput "[OK] El método de autenticación GitHub ya está habilitado" $SuccessColor
    } else {
        Write-ColorOutput "[INFO] Habilitando método de autenticación GitHub..." $InfoColor
        $result = vault auth enable github 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "[ERROR] No se pudo habilitar GitHub auth: $result" $ErrorColor
            return $false
        }
        Write-ColorOutput "[OK] Método de autenticación GitHub habilitado" $SuccessColor
    }
    
    # Solicitar información para configurar GitHub
    Write-ColorOutput "`n[INFO] Configuración de GitHub Authentication" $InfoColor
    $orgName = Read-Host "Ingrese el nombre de la organización de GitHub"
    
    if ([string]::IsNullOrWhiteSpace($orgName)) {
        Write-ColorOutput "[ERROR] El nombre de la organización no puede estar vacío" $ErrorColor
        return $false
    }
    
    # Configurar la organización
    $result = vault write auth/github/config organization=$orgName 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "[ERROR] No se pudo configurar la organización GitHub: $result" $ErrorColor
        return $false
    }
    Write-ColorOutput "[OK] Organización GitHub configurada: $orgName" $SuccessColor
    
    # Crear el role para GitHub que asigna la política developer
    $roleName = "github-developer-role"
    Write-ColorOutput "[INFO] Creando role de GitHub: $roleName" $InfoColor
    
    # Verificar si el role ya existe
    $roleExists = $false
    try {
        $existingRole = vault read auth/github/role/$roleName -format=json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $roleExists = $true
            $roleData = $existingRole | ConvertFrom-Json
            if ($roleData.data.policies -contains "developer-policy") {
                Write-ColorOutput "[OK] El role '$roleName' ya existe y tiene la política correcta" $SuccessColor
                return $true
            } else {
                Write-ColorOutput "[ADVERTENCIA] El role '$roleName' ya existe pero NO tiene la política esperada" $WarningColor
                Write-ColorOutput "[ADVERTENCIA] Se omitirá la creación/actualización de este role" $WarningColor
                return $false
            }
        }
    } catch {
        # Role no existe, continuar
    }
    
    if (-not $roleExists) {
        # Crear el role con la política developer
        $result = vault write auth/github/role/$roleName policies=developer-policy 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[OK] Role '$roleName' creado exitosamente con política 'developer-policy'" $SuccessColor
            return $true
        } else {
            Write-ColorOutput "[ERROR] No se pudo crear el role GitHub: $result" $ErrorColor
            return $false
        }
    }
    
    return $true
}

function Enable-ResponseWrapping {
    Write-ColorOutput "`n[INFO] Configurando Response Wrapping..." $InfoColor
    
    # Response Wrapping está habilitado por defecto en Vault
    # Configurar TTL máximo de wrapping (1 hora = 3600 segundos)
    $maxWrappingTTL = "3600s"
    
    # Verificar configuración actual de wrapping
    $currentConfig = vault read sys/config/wrapping -format=json 2>&1
    $needsUpdate = $true
    
    if ($LASTEXITCODE -eq 0) {
        $configData = $currentConfig | ConvertFrom-Json
        if ($configData.data.max_wrapping_ttl -eq $maxWrappingTTL) {
            Write-ColorOutput "[OK] Response Wrapping ya está configurado con TTL máximo de 1 hora" $SuccessColor
            $needsUpdate = $false
        } else {
            Write-ColorOutput "[INFO] TTL máximo actual: $($configData.data.max_wrapping_ttl)" $InfoColor
            Write-ColorOutput "[INFO] Actualizando TTL máximo a 1 hora..." $InfoColor
        }
    } else {
        Write-ColorOutput "[INFO] Configurando TTL máximo de Response Wrapping a 1 hora..." $InfoColor
    }
    
    if ($needsUpdate) {
        # Configurar el TTL máximo de wrapping
        $result = vault write sys/config/wrapping max_wrapping_ttl=$maxWrappingTTL 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[OK] Response Wrapping configurado con TTL máximo de 1 hora" $SuccessColor
        } else {
            Write-ColorOutput "[ADVERTENCIA] No se pudo configurar el TTL máximo de wrapping: $result" $WarningColor
            Write-ColorOutput "[ADVERTENCIA] Verifique que el token tenga permisos de sudo en sys/config/wrapping" $WarningColor
            return $false
        }
    }
    
    # Verificar que las políticas incluyen acceso a wrapping y cubbyhole
    Write-ColorOutput "[OK] Todos los grupos tienen acceso a Response Wrapping a través de sus políticas" $SuccessColor
    Write-ColorOutput "[INFO] Las políticas incluyen acceso a sys/wrapping/* y cubbyhole/*" $InfoColor
    
    return $true
}

# Función principal
function Main {
    Write-ColorOutput "`n========================================" $InfoColor
    Write-ColorOutput "  Inicialización de Vault Groups" $InfoColor
    Write-ColorOutput "========================================`n" $InfoColor
    
    # Verificar conexión
    Test-VaultConnection
    
    # Definir grupos y sus políticas
    $groups = @{
        "Admin" = @("admin-policy")
        "Security Admin" = @("security-admin-policy")
        "Operation" = @("operation-policy")
        "Developer" = @("developer-policy")
    }
    
    # Crear políticas
    Write-ColorOutput "`n=== Creando Políticas ===" $InfoColor
    $policiesCreated = @{}
    
    foreach ($policyName in @("admin-policy", "security-admin-policy", "operation-policy", "developer-policy")) {
        $policyContent = Get-PolicyContent -PolicyName $policyName.Replace("-policy", "")
        if ($policyContent) {
            $policiesCreated[$policyName] = New-VaultPolicy -PolicyName $policyName -PolicyContent $policyContent
        }
    }
    
    # Crear grupos
    Write-ColorOutput "`n=== Creando Grupos ===" $InfoColor
    $groupsCreated = @{}
    
    foreach ($groupName in $groups.Keys) {
        $policies = $groups[$groupName]
        $groupsCreated[$groupName] = New-VaultGroup -GroupName $groupName -Policies $policies
    }
    
    # Configurar GitHub Auth
    if (-not $SkipGitHubAuth) {
        Write-ColorOutput "`n=== Configurando GitHub Authentication ===" $InfoColor
        Enable-GitHubAuth | Out-Null
    } else {
        Write-ColorOutput "`n[INFO] Configuración de GitHub Authentication omitida (flag -SkipGitHubAuth)" $InfoColor
    }
    
    # Configurar Response Wrapping
    Write-ColorOutput "`n=== Configurando Response Wrapping ===" $InfoColor
    Enable-ResponseWrapping | Out-Null
    
    # Resumen
    Write-ColorOutput "`n========================================" $InfoColor
    Write-ColorOutput "  Resumen de la Inicialización" $InfoColor
    Write-ColorOutput "========================================`n" $InfoColor
    
    Write-ColorOutput "Políticas:" $InfoColor
    foreach ($policy in $policiesCreated.Keys) {
        $status = if ($policiesCreated[$policy]) { "[OK]" } else { "[OMITIDO]" }
        $color = if ($policiesCreated[$policy]) { $SuccessColor } else { $WarningColor }
        Write-ColorOutput "  $status $policy" $color
    }
    
    Write-ColorOutput "`nGrupos:" $InfoColor
    foreach ($group in $groupsCreated.Keys) {
        $status = if ($groupsCreated[$group]) { "[OK]" } else { "[OMITIDO]" }
        $color = if ($groupsCreated[$group]) { $SuccessColor } else { $WarningColor }
        Write-ColorOutput "  $status $group" $color
    }
    
    Write-ColorOutput "`n[OK] Inicialización completada" $SuccessColor
}

# Ejecutar función principal
Main
