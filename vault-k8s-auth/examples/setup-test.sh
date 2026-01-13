#!/bin/bash
# Script para configurar el entorno de prueba en Cluster-B
# Este script crea los recursos necesarios para probar Kubernetes Auth

set -e

NAMESPACE="default"
SERVICE_ACCOUNT="app-sa"

echo "=========================================="
echo "Configurando entorno de prueba"
echo "=========================================="

# 1. Crear namespace
echo "1. Creando namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# 2. Crear ServiceAccount
echo "2. Creando ServiceAccount '$SERVICE_ACCOUNT'..."
kubectl create serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=========================================="
echo "Configuración completada"
echo "=========================================="
echo ""
echo "ServiceAccount creado: $SERVICE_ACCOUNT en namespace $NAMESPACE"
echo ""
echo "Próximos pasos:"
echo "1. Crear secretos en Vault:"
echo "   vault kv put secret/app/database username=dbuser password=dbpass"
echo "   vault kv put secret/app/api-key api_key=sk-1234567890"
echo ""
echo "2. Desplegar pod de prueba:"
echo "   kubectl apply -f examples/test-pod.yaml"
echo ""
echo "3. Verificar logs:"
echo "   kubectl logs vault-test -n app -c vault-agent"
echo "   kubectl exec vault-test -n app -c test -- cat /vault/secrets/database"
echo ""
