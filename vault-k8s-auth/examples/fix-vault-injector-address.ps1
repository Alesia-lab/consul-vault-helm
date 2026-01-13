# Script para verificar y corregir la configuración del vault-injector
# Este script verifica si el vault-injector tiene configurada la dirección correcta de Vault
# y proporciona comandos para corregirla si es necesario

param(
    [Parameter(Mandatory=$false)]
    [string]$VaultAddress = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "vault",
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseName = "vault-injector"
)

Write-Host "=========================================="
Write-Host "Verificando configuracion del vault-injector"
Write-Host "=========================================="
Write-Host ""

# Verificar si helm esta disponible
try {
    $null = Get-Command helm -ErrorAction Stop
    Write-Host "[OK] Helm esta disponible" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Helm no esta disponible" -ForegroundColor Red
    Write-Host "Instala Helm para usar este script"
    exit 1
}

# Verificar si kubectl esta disponible
try {
    $null = Get-Command kubectl -ErrorAction Stop
    Write-Host "[OK] kubectl esta disponible" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] kubectl no esta disponible" -ForegroundColor Red
    Write-Host "Instala kubectl para usar este script"
    exit 1
}

Write-Host ""

# Verificar si el release existe
Write-Host "1. Verificando release de Helm..."
$releaseExists = $false
try {
    $release = helm list -n $Namespace --filter $ReleaseName -o json 2>&1 | ConvertFrom-Json
    if ($release -and $release.Count -gt 0) {
        $releaseExists = $true
        Write-Host "   [OK] Release '$ReleaseName' encontrado en namespace '$Namespace'" -ForegroundColor Green
    }
    else {
        Write-Host "   [ADVERTENCIA] Release '$ReleaseName' no encontrado en namespace '$Namespace'" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   [ADVERTENCIA] No se pudo verificar el release: $($_.Exception.Message)" -ForegroundColor Yellow
}

if (-not $releaseExists) {
    Write-Host ""
    Write-Host "El vault-injector no esta instalado o tiene un nombre diferente."
    Write-Host "Para instalarlo, ejecuta:"
    Write-Host ""
    Write-Host "  helm install $ReleaseName hashicorp/vault \`" -ForegroundColor Cyan
    Write-Host "    --namespace $Namespace \`" -ForegroundColor Cyan
    Write-Host "    --create-namespace \`" -ForegroundColor Cyan
    Write-Host "    --set server.enabled=false \`" -ForegroundColor Cyan
    Write-Host "    --set injector.enabled=true \`" -ForegroundColor Cyan
    Write-Host "    --set injector.externalVaultAddr=`"TU_VAULT_ADDRESS`""
    Write-Host ""
    exit 0
}

Write-Host ""

# Obtener valores actuales
Write-Host "2. Obteniendo configuracion actual del vault-injector..."
try {
    $currentValues = helm get values $ReleaseName -n $Namespace 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [OK] Configuracion obtenida" -ForegroundColor Green
        Write-Host ""
        Write-Host "   Valores actuales:" -ForegroundColor Yellow
        Write-Host $currentValues
        Write-Host ""
        
        # Verificar externalVaultAddr
        $hasExternalAddr = $currentValues -match "externalVaultAddr"
        $hasVaultAddr = $currentValues -match "VAULT_ADDR"
        
        if (-not $hasExternalAddr -or ($hasExternalAddr -and ($currentValues | Select-String "externalVaultAddr:\s*`"`""))) {
            Write-Host "   [ADVERTENCIA] externalVaultAddr no esta configurado o esta vacio" -ForegroundColor Yellow
        }
        else {
            Write-Host "   [OK] externalVaultAddr esta configurado" -ForegroundColor Green
        }
        
        if (-not $hasVaultAddr -or ($hasVaultAddr -and ($currentValues | Select-String "VAULT_ADDR:\s*`"`""))) {
            Write-Host "   [ADVERTENCIA] VAULT_ADDR no esta configurado o esta vacio" -ForegroundColor Yellow
        }
        else {
            Write-Host "   [OK] VAULT_ADDR esta configurado" -ForegroundColor Green
        }
    }
    else {
        Write-Host "   [ERROR] No se pudo obtener la configuracion" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "   [ERROR] Error al obtener configuracion: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Si se proporciono una direccion, mostrar comando para actualizar
if ($VaultAddress) {
    Write-Host "3. Comando para actualizar el vault-injector:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   helm upgrade $ReleaseName hashicorp/vault -n $Namespace --reuse-values \`" -ForegroundColor White
    Write-Host "     --set injector.externalVaultAddr=`"$VaultAddress`" \`" -ForegroundColor White
    Write-Host "     --set injector.agentDefaults.extraEnvironmentVars.VAULT_ADDR=`"$VaultAddress`" \`" -ForegroundColor White
    Write-Host "     --set injector.agentDefaults.extraEnvironmentVars.VAULT_SKIP_VERIFY=`"true`"" -ForegroundColor White
    Write-Host ""
    Write-Host "   Despues de ejecutar este comando, necesitaras recrear los pods:" -ForegroundColor Yellow
    Write-Host "   kubectl delete pod -n app -l app=vault-test" -ForegroundColor White
    Write-Host ""
    
    $confirm = Read-Host "   ¿Deseas ejecutar este comando ahora? (S/N)"
    if ($confirm -eq "S" -or $confirm -eq "s" -or $confirm -eq "Y" -or $confirm -eq "y") {
        Write-Host ""
        Write-Host "   Ejecutando comando..." -ForegroundColor Cyan
        helm upgrade $ReleaseName hashicorp/vault -n $Namespace --reuse-values `
          --set injector.externalVaultAddr="$VaultAddress" `
          --set injector.agentDefaults.extraEnvironmentVars.VAULT_ADDR="$VaultAddress" `
          --set injector.agentDefaults.extraEnvironmentVars.VAULT_SKIP_VERIFY="true"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "   [OK] Vault-injector actualizado exitosamente" -ForegroundColor Green
            Write-Host ""
            Write-Host "   IMPORTANTE: Debes recrear los pods para que usen la nueva configuracion:" -ForegroundColor Yellow
            Write-Host "   kubectl delete pod -n app -l app=vault-test" -ForegroundColor White
        }
        else {
            Write-Host ""
            Write-Host "   [ERROR] Error al actualizar el vault-injector" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "3. Para actualizar el vault-injector, ejecuta este script con el parametro -VaultAddress:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   .\fix-vault-injector-address.ps1 -VaultAddress `"https://tu-vault-address.com`"" -ForegroundColor White
    Write-Host ""
}

Write-Host "=========================================="
Write-Host "Verificacion completada"
Write-Host "=========================================="
Write-Host ""
