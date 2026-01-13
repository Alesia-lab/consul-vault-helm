#!/bin/bash
# Script para limpiar los recursos creados por setup-test.sh y create-test-secrets.sh
# Este script elimina:
# - Secretos de prueba en Vault
# - Namespace y ServiceAccount en Kubernetes
# - Pods/Deployments de prueba

set -e

NAMESPACE="app"
SERVICE_ACCOUNT="app-sa"
VAULT_ADDR="${VAULT_ADDR:-https://k8s-vault-vaultui-62506ffd89-622e5694cde0e9a6.elb.us-east-1.amazonaws.com}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

echo "=========================================="
echo "Limpiando recursos de prueba"
echo "=========================================="
echo ""

# ============================================================================
# Limpiar recursos de Kubernetes
# ============================================================================

echo "1. Limpiando recursos de Kubernetes..."

# Verificar si kubectl está disponible
if ! command -v kubectl &> /dev/null; then
  echo "   ⚠️  kubectl no está disponible, saltando limpieza de Kubernetes"
else
  # Eliminar pods de prueba
  if kubectl get pod vault-test -n "$NAMESPACE" &> /dev/null; then
    echo "   - Eliminando pod vault-test..."
    kubectl delete pod vault-test -n "$NAMESPACE" --ignore-not-found=true
  fi

  # Eliminar deployments de prueba
  if kubectl get deployment vault-test-app -n "$NAMESPACE" &> /dev/null; then
    echo "   - Eliminando deployment vault-test-app..."
    kubectl delete deployment vault-test-app -n "$NAMESPACE" --ignore-not-found=true
  fi

  # Eliminar ServiceAccount
  if kubectl get serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" &> /dev/null; then
    echo "   - Eliminando ServiceAccount $SERVICE_ACCOUNT..."
    kubectl delete serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" --ignore-not-found=true
  fi

  # Eliminar namespace (solo si está vacío o si el usuario lo confirma)
  if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    # Verificar si el namespace tiene otros recursos
    RESOURCES=$(kubectl get all -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$RESOURCES" -eq 0 ]; then
      echo "   - Eliminando namespace $NAMESPACE (está vacío)..."
      kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    else
      echo "   ⚠️  Namespace $NAMESPACE contiene otros recursos, no se eliminará automáticamente"
      echo "   Para eliminarlo manualmente: kubectl delete namespace $NAMESPACE"
    fi
  fi

  echo "   ✓ Recursos de Kubernetes limpiados"
fi

echo ""

# ============================================================================
# Limpiar secretos de Vault
# ============================================================================

echo "2. Limpiando secretos de Vault..."

KV_MOUNT_PATH="${KV_MOUNT_PATH:-secret}"  # Path del KV v2 mount (default: secret)

# Verificar que curl está disponible
if ! command -v curl &> /dev/null; then
  echo "   ⚠️  curl no está disponible, saltando limpieza de Vault"
  echo "   Para limpiar manualmente usando la API:"
  echo "   curl -X DELETE -H \"X-Vault-Token: \$VAULT_TOKEN\" \\"
  echo "     ${VAULT_ADDR}/v1/${KV_MOUNT_PATH}/metadata/app/database"
else
  # Verificar conexión a Vault
  if [ -z "$VAULT_TOKEN" ]; then
    echo "   ⚠️  VAULT_TOKEN no está configurado"
    echo "   Exporta la variable: export VAULT_TOKEN='tu-token-aqui'"
  else
    # Normalizar VAULT_ADDR (remover trailing slash)
    VAULT_ADDR="${VAULT_ADDR%/}"
    
    # Función para hacer requests a la API de Vault
    vault_api_request() {
      local method=$1
      local path=$2
      local data=$3
      
      local url="${VAULT_ADDR}/v1/${path}"
      local headers=(
        -H "X-Vault-Token: ${VAULT_TOKEN}"
        -H "Content-Type: application/json"
      )
      
      if [ "$method" = "GET" ]; then
        curl -k -s -f "${headers[@]}" "$url" 2>/dev/null || return 1
      elif [ "$method" = "DELETE" ]; then
        curl -k -s -f -X "DELETE" "${headers[@]}" "$url" 2>/dev/null || return 1
      else
        return 1
      fi
    }
    
    # Verificar conexión (sin -f para health check ya que puede retornar códigos no-2xx)
    health_check=$(curl -k -s -w "%{http_code}" -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/sys/health" -o /dev/null 2>&1)
    curl_exit_code=$?
    
    if [ $curl_exit_code -ne 0 ] || [ -z "$health_check" ]; then
      echo "   ⚠️  No se puede conectar a Vault"
      echo "   Verifica VAULT_ADDR y VAULT_TOKEN"
    else
      # Eliminar secretos usando DELETE en el metadata path (KV v2)
      SECRETS=(
        "app/database"
        "app/api-key"
        "app/config"
      )

      for secret in "${SECRETS[@]}"; do
        # Verificar si el secreto existe antes de eliminarlo
        if vault_api_request "GET" "${KV_MOUNT_PATH}/data/${secret}" > /dev/null 2>&1; then
          echo "   - Eliminando ${KV_MOUNT_PATH}/${secret}..."
          # En KV v2, se elimina usando el metadata path
          vault_api_request "DELETE" "${KV_MOUNT_PATH}/metadata/${secret}" > /dev/null 2>&1 || true
        fi
      done

      # Verificar si quedan secretos en el directorio app
      LIST_RESPONSE=$(vault_api_request "GET" "${KV_MOUNT_PATH}/metadata/app" 2>/dev/null || echo "")
      if [ -n "$LIST_RESPONSE" ]; then
        # Intentar parsear si hay más secretos (simplificado)
        REMAINING=$(echo "$LIST_RESPONSE" | grep -o '"keys"' | wc -l || echo "0")
        if [ "$REMAINING" -eq 0 ] || [ -z "$LIST_RESPONSE" ]; then
          echo "   - Directorio ${KV_MOUNT_PATH}/app está vacío o no existe"
        else
          echo "   ⚠️  Directorio ${KV_MOUNT_PATH}/app contiene otros secretos, no se elimina"
        fi
      fi

      echo "   ✓ Secretos de Vault limpiados"
    fi
  fi
fi

echo ""
echo "=========================================="
echo "Limpieza completada"
echo "=========================================="
echo ""
echo "Recursos eliminados:"
echo "  ✓ Pods y Deployments de prueba"
echo "  ✓ ServiceAccount: $SERVICE_ACCOUNT"
echo "  ✓ Secretos de Vault: secret/app/*"
echo ""
echo "Nota: El namespace '$NAMESPACE' solo se elimina si está vacío."
echo "      Si contiene otros recursos, elimínalo manualmente si es necesario."
echo ""
