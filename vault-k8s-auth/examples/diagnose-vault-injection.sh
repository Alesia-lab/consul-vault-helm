#!/bin/bash
# Script de diagnóstico para problemas con Vault Agent Sidecar Injector

set -e

POD_NAME="${1:-vault-test}"
NAMESPACE="${2:-app}"

echo "=========================================="
echo "Diagnóstico de Vault Agent Injection"
echo "=========================================="
echo "Pod: $POD_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Verificar que el pod existe
if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
  echo "❌ Error: Pod '$POD_NAME' no existe en namespace '$NAMESPACE'"
  exit 1
fi

echo "1. Verificando que el vault-injector está instalado..."
INJECTOR_FOUND=false

# Buscar diferentes nombres posibles del injector
if kubectl get deployment -A 2>/dev/null | grep -qE "(vault-agent-injector|vault-injector|vault-k8s)"; then
  echo "   ✓ vault-injector encontrado"
  kubectl get deployment -A | grep -E "(vault-agent-injector|vault-injector|vault-k8s)"
  INJECTOR_FOUND=true
elif kubectl get pods -A 2>/dev/null | grep -qE "(vault-agent-injector|vault-injector|vault-k8s)"; then
  echo "   ✓ vault-injector encontrado (como pod)"
  kubectl get pods -A | grep -E "(vault-agent-injector|vault-injector|vault-k8s)"
  INJECTOR_FOUND=true
else
  echo "   ❌ vault-injector NO encontrado"
  echo ""
  echo "   El vault-injector debe estar instalado para que funcione la inyección."
  echo "   Buscando en todos los namespaces..."
  echo ""
  # Buscar en todos los namespaces posibles
  for ns in vault default kube-system; do
    if kubectl get deployment -n "$ns" 2>/dev/null | grep -q injector; then
      echo "   Posible injector encontrado en namespace '$ns':"
      kubectl get deployment -n "$ns" | grep injector
      INJECTOR_FOUND=true
    fi
  done
  
  if [ "$INJECTOR_FOUND" = false ]; then
    echo "   ⚠️  No se encontró vault-injector en ningún namespace"
    echo ""
    echo "   Para instalar el vault-injector, puedes usar:"
    echo "   1. Helm: helm install vault hashicorp/vault --set injector.enabled=true"
    echo "   2. O seguir la guía en: examples/INSTALL-INJECTOR.md"
  fi
fi
echo ""

echo "2. Verificando contenedores en el pod..."
CONTAINERS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}')
echo "   Contenedores: $CONTAINERS"

if echo "$CONTAINERS" | grep -q vault-agent; then
  echo "   ✓ vault-agent sidecar está presente"
else
  echo "   ❌ vault-agent sidecar NO está presente"
  echo "   El vault-injector no inyectó el sidecar"
fi
echo ""

echo "3. Verificando anotaciones del pod..."
ANNOTATIONS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations}' | jq -r 'to_entries[] | select(.key | startswith("vault.hashicorp.com")) | "\(.key)=\(.value)"' 2>/dev/null || kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations}' | grep -o 'vault\.hashicorp\.com/[^,}]*' || echo "No se pudieron obtener anotaciones")

if [ -n "$ANNOTATIONS" ]; then
  echo "   Anotaciones de Vault encontradas:"
  echo "$ANNOTATIONS" | while read -r ann; do
    echo "     - $ann"
  done
else
  echo "   ❌ No se encontraron anotaciones de Vault"
fi
echo ""

echo "4. Verificando ServiceAccount..."
SA=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.serviceAccountName}')
echo "   ServiceAccount: $SA"

if kubectl get serviceaccount "$SA" -n "$NAMESPACE" &> /dev/null; then
  echo "   ✓ ServiceAccount existe"
else
  echo "   ❌ ServiceAccount NO existe"
fi
echo ""

echo "5. Verificando logs del vault-agent (últimas 20 líneas)..."
if kubectl logs "$POD_NAME" -n "$NAMESPACE" -c vault-agent --tail=20 2>&1 | head -20; then
  echo ""
else
  echo "   ❌ No se pudieron obtener logs del vault-agent"
  echo "   Esto puede indicar que el sidecar no se inyectó correctamente"
fi
echo ""

echo "6. Verificando volumen /vault/secrets..."
if kubectl exec "$POD_NAME" -n "$NAMESPACE" -c test -- ls -la /vault/secrets/ 2>&1 | head -10; then
  echo "   ✓ Directorio /vault/secrets existe y es accesible"
  echo ""
  echo "   Contenido de /vault/secrets:"
  kubectl exec "$POD_NAME" -n "$NAMESPACE" -c test -- ls -la /vault/secrets/ 2>&1 || echo "   (vacío o no accesible)"
else
  echo "   ❌ No se puede acceder a /vault/secrets"
  echo "   Verifica que el volumen esté montado correctamente"
fi
echo ""

echo "7. Verificando eventos del pod..."
echo "   Eventos recientes:"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$POD_NAME" --sort-by='.lastTimestamp' | tail -5
echo ""

echo "8. Verificando configuración de Vault (requiere acceso a Vault)..."
echo "   Para verificar manualmente:"
echo "   vault read auth/kubernetes-cluster-b/role/app-readonly"
echo "   vault read auth/kubernetes-cluster-b/config"
echo ""

echo "=========================================="
echo "Diagnóstico completado"
echo "=========================================="
echo ""
echo "Comandos útiles para debugging:"
echo "  # Ver todos los logs del vault-agent"
echo "  kubectl logs $POD_NAME -n $NAMESPACE -c vault-agent"
echo ""
echo "  # Ver eventos del pod"
echo "  kubectl describe pod $POD_NAME -n $NAMESPACE"
echo ""
echo "  # Verificar anotaciones"
echo "  kubectl get pod $POD_NAME -n $NAMESPACE -o yaml | grep -A 20 annotations"
echo ""
