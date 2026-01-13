# Script para configurar el entorno de prueba en Cluster-B
# Este script crea los recursos necesarios para probar Kubernetes Auth
# Versión PowerShell

$ErrorActionPreference = "Stop"

$NAMESPACE = "app"
$SERVICE_ACCOUNT = "app-sa"

Write-Host "=========================================="
Write-Host "Configurando entorno de prueba"
Write-Host "=========================================="

# 1. Crear namespace
Write-Host "1. Creando namespace '$NAMESPACE'..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 2. Crear ServiceAccount
Write-Host "2. Creando ServiceAccount '$SERVICE_ACCOUNT'..."
kubectl create serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

Write-Host ""
Write-Host "=========================================="
Write-Host "Configuración completada"
Write-Host "=========================================="
Write-Host ""
Write-Host "ServiceAccount creado: $SERVICE_ACCOUNT en namespace $NAMESPACE"
Write-Host ""
Write-Host "Próximos pasos:"
Write-Host "1. Crear secretos en Vault:"
Write-Host "   vault kv put secret/app/database username=dbuser password=dbpass"
Write-Host "   vault kv put secret/app/api-key api_key=sk-1234567890"
Write-Host ""
Write-Host "2. Desplegar pod de prueba:"
Write-Host "   kubectl apply -f examples/test-pod.yaml"
Write-Host ""
Write-Host "3. Verificar logs:"
Write-Host "   kubectl logs vault-test -n app -c vault-agent"
Write-Host "   kubectl exec vault-test -n app -c test -- cat /vault/secrets/database"
Write-Host ""
