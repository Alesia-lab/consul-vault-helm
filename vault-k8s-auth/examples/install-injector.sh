#!/bin/bash
# Script para instalar Vault Agent Injector usando Helm
# Este script instala solo el injector (no el servidor de Vault)

set -e

# Configuración
VAULT_ADDR="${VAULT_ADDR:-https://k8s-vault-vaultui-62506ffd89-622e5694cde0e9a6.elb.us-east-1.amazonaws.com}"
NAMESPACE="${NAMESPACE:-vault}"
RELEASE_NAME="${RELEASE_NAME:-vault-injector}"

echo "=========================================="
echo "Instalación de Vault Agent Injector"
echo "=========================================="
echo "Vault Address: $VAULT_ADDR"
echo "Namespace: $NAMESPACE"
echo "Release Name: $RELEASE_NAME"
echo ""

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
  echo "❌ Error: kubectl no está instalado"
  exit 1
fi

# Verificar que helm está disponible
if ! command -v helm &> /dev/null; then
  echo "❌ Error: helm no está instalado"
  echo ""
  echo "Instala Helm con:"
  echo "  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
  exit 1
fi

# Verificar conexión al cluster
echo "1. Verificando conexión al cluster..."
if ! kubectl cluster-info &> /dev/null; then
  echo "   ❌ No se puede conectar al cluster de Kubernetes"
  echo "   Verifica tu kubeconfig"
  exit 1
fi
echo "   ✓ Conexión al cluster verificada"
echo ""

# Agregar repositorio de HashiCorp
echo "2. Agregando repositorio de HashiCorp..."
if helm repo list | grep -q hashicorp; then
  echo "   ✓ Repositorio hashicorp ya existe, actualizando..."
  helm repo update hashicorp
else
  echo "   Agregando repositorio hashicorp..."
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm repo update
fi
echo "   ✓ Repositorio configurado"
echo ""

# Crear namespace si no existe
echo "3. Creando namespace '$NAMESPACE'..."
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
  echo "   ✓ Namespace '$NAMESPACE' ya existe"
else
  kubectl create namespace "$NAMESPACE"
  echo "   ✓ Namespace '$NAMESPACE' creado"
fi
echo ""

# Verificar si ya está instalado
echo "4. Verificando si el injector ya está instalado..."
if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
  echo "   ⚠️  El release '$RELEASE_NAME' ya está instalado"
  read -p "   ¿Deseas actualizarlo? (y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "   Instalación cancelada"
    exit 0
  fi
  echo "   Actualizando release..."
  helm upgrade "$RELEASE_NAME" hashicorp/vault \
    --namespace "$NAMESPACE" \
    --set server.enabled=false \
    --set injector.enabled=true \
    --set injector.externalVaultAddr="$VAULT_ADDR" \
    --wait \
    --timeout 5m
  echo "   ✓ Release actualizado"
else
  echo "   Instalando vault-injector..."
  helm install "$RELEASE_NAME" hashicorp/vault \
    --namespace "$NAMESPACE" \
    --set server.enabled=false \
    --set injector.enabled=true \
    --set injector.externalVaultAddr="$VAULT_ADDR" \
    --wait \
    --timeout 5m
  echo "   ✓ Vault injector instalado"
fi
echo ""

# Verificar instalación
echo "5. Verificando instalación..."
sleep 5

# Verificar deployment
if kubectl get deployment "$RELEASE_NAME-agent-injector" -n "$NAMESPACE" &> /dev/null; then
  echo "   ✓ Deployment encontrado"
  kubectl get deployment "$RELEASE_NAME-agent-injector" -n "$NAMESPACE"
else
  echo "   ⚠️  Deployment no encontrado con el nombre esperado"
  echo "   Buscando deployments en namespace '$NAMESPACE':"
  kubectl get deployment -n "$NAMESPACE"
fi
echo ""

# Verificar pods
echo "6. Verificando pods..."
PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault-agent-injector --no-headers 2>/dev/null | wc -l)
if [ "$PODS" -gt 0 ]; then
  echo "   ✓ Pods del injector encontrados:"
  kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault-agent-injector
  echo ""
  echo "   Estado de los pods:"
  kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault-agent-injector -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'
else
  echo "   ⚠️  No se encontraron pods del injector"
  echo "   Esto puede ser normal si aún se están creando"
fi
echo ""

# Verificar MutatingWebhookConfiguration
echo "7. Verificando MutatingWebhookConfiguration..."
if kubectl get mutatingwebhookconfiguration | grep -q vault; then
  echo "   ✓ MutatingWebhookConfiguration encontrado:"
  kubectl get mutatingwebhookconfiguration | grep vault
else
  echo "   ⚠️  MutatingWebhookConfiguration no encontrado"
  echo "   Esto puede tardar unos segundos en crearse"
fi
echo ""

echo "=========================================="
echo "Instalación completada"
echo "=========================================="
echo ""
echo "Próximos pasos:"
echo ""
echo "1. Verificar que el injector está corriendo:"
echo "   kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=vault-agent-injector"
echo ""
echo "2. Ver logs del injector (si hay problemas):"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=vault-agent-injector"
echo ""
echo "3. Probar con un pod de prueba:"
echo "   kubectl delete pod vault-test -n app 2>/dev/null || true"
echo "   kubectl apply -f test-pod.yaml"
echo ""
echo "4. Verificar que el sidecar se inyectó:"
echo "   kubectl get pod vault-test -n app -o jsonpath='{.spec.containers[*].name}'"
echo "   # Debe mostrar: test vault-agent"
echo ""
echo "5. Ejecutar diagnóstico:"
echo "   ./diagnose-vault-injection.sh vault-test app"
echo ""
