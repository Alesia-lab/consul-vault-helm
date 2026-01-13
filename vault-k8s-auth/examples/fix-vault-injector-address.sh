#!/bin/bash
# Script para verificar y corregir la configuración del vault-injector
# Este script verifica si el vault-injector tiene configurada la dirección correcta de Vault
# y proporciona comandos para corregirla si es necesario

set -e

VAULT_ADDRESS="${1:-}"
NAMESPACE="${NAMESPACE:-vault}"
RELEASE_NAME="${RELEASE_NAME:-vault-injector}"

echo "=========================================="
echo "Verificando configuración del vault-injector"
echo "=========================================="
echo ""

# Verificar si helm está disponible
if ! command -v helm &> /dev/null; then
    echo "[ERROR] Helm no está disponible"
    echo "Instala Helm para usar este script"
    exit 1
fi
echo "[OK] Helm está disponible"

# Verificar si kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl no está disponible"
    echo "Instala kubectl para usar este script"
    exit 1
fi
echo "[OK] kubectl está disponible"

echo ""

# Verificar si el release existe
echo "1. Verificando release de Helm..."
if helm list -n "$NAMESPACE" --filter "$RELEASE_NAME" &> /dev/null; then
    echo "   [OK] Release '$RELEASE_NAME' encontrado en namespace '$NAMESPACE'"
else
    echo "   [ADVERTENCIA] Release '$RELEASE_NAME' no encontrado en namespace '$NAMESPACE'"
    echo ""
    echo "El vault-injector no está instalado o tiene un nombre diferente."
    echo "Para instalarlo, ejecuta:"
    echo ""
    echo "  helm install $RELEASE_NAME hashicorp/vault \\"
    echo "    --namespace $NAMESPACE \\"
    echo "    --create-namespace \\"
    echo "    --set server.enabled=false \\"
    echo "    --set injector.enabled=true \\"
    echo "    --set injector.externalVaultAddr=\"TU_VAULT_ADDRESS\""
    echo ""
    exit 0
fi

echo ""

# Obtener valores actuales
echo "2. Obteniendo configuración actual del vault-injector..."
if helm get values "$RELEASE_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo "   [OK] Configuración obtenida"
    echo ""
    echo "   Valores actuales:"
    helm get values "$RELEASE_NAME" -n "$NAMESPACE"
    echo ""
    
    # Verificar externalVaultAddr
    VALUES=$(helm get values "$RELEASE_NAME" -n "$NAMESPACE")
    if echo "$VALUES" | grep -q "externalVaultAddr:" && ! echo "$VALUES" | grep -q "externalVaultAddr: \"\""; then
        echo "   [OK] externalVaultAddr está configurado"
    else
        echo "   [ADVERTENCIA] externalVaultAddr no está configurado o está vacío"
    fi
    
    if echo "$VALUES" | grep -q "VAULT_ADDR:" && ! echo "$VALUES" | grep -q "VAULT_ADDR: \"\""; then
        echo "   [OK] VAULT_ADDR está configurado"
    else
        echo "   [ADVERTENCIA] VAULT_ADDR no está configurado o está vacío"
    fi
else
    echo "   [ERROR] No se pudo obtener la configuración"
    exit 1
fi

echo ""

# Si se proporcionó una dirección, mostrar comando para actualizar
if [ -n "$VAULT_ADDRESS" ]; then
    echo "3. Actualizando el vault-injector..."
    echo ""
    helm upgrade "$RELEASE_NAME" hashicorp/vault -n "$NAMESPACE" --reuse-values \
      --set injector.externalVaultAddr="$VAULT_ADDRESS" \
      --set injector.agentDefaults.extraEnvironmentVars.VAULT_ADDR="$VAULT_ADDRESS" \
      --set injector.agentDefaults.extraEnvironmentVars.VAULT_SKIP_VERIFY="true"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "   [OK] Vault-injector actualizado exitosamente"
        echo ""
        echo "   IMPORTANTE: Debes recrear los pods para que usen la nueva configuración:"
        echo "   kubectl delete pod -n app -l app=vault-test"
    else
        echo ""
        echo "   [ERROR] Error al actualizar el vault-injector"
        exit 1
    fi
else
    echo "3. Para actualizar el vault-injector, ejecuta este script con la dirección de Vault:"
    echo ""
    echo "   ./fix-vault-injector-address.sh \"https://tu-vault-address.com\""
    echo ""
    echo "   O configura las variables de entorno:"
    echo "   export VAULT_ADDRESS=\"https://tu-vault-address.com\""
    echo "   ./fix-vault-injector-address.sh"
    echo ""
fi

echo "=========================================="
echo "Verificación completada"
echo "=========================================="
echo ""
