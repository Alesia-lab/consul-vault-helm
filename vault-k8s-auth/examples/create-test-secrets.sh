#!/bin/bash
# Script para crear secretos de prueba en Vault usando la API REST
# Este script NO requiere el CLI de Vault, solo curl
# Estos secretos se usarán para probar el acceso desde pods

set -e

# Configurar estas variables según tu entorno
VAULT_ADDR="${VAULT_ADDR:-https://k8s-vault-vaultui-62506ffd89-622e5694cde0e9a6.elb.us-east-1.amazonaws.com}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
KV_MOUNT_PATH="${KV_MOUNT_PATH:-secret}"  # Path del KV v2 mount (default: secret)

if [ -z "$VAULT_TOKEN" ]; then
  echo "Error: VAULT_TOKEN no está configurado"
  echo "Exporta la variable: export VAULT_TOKEN='tu-token-aqui'"
  exit 1
fi

# Verificar que curl está disponible
if ! command -v curl &> /dev/null; then
  echo "Error: curl no está instalado"
  echo "Instala curl para usar este script"
  exit 1
fi

# Normalizar VAULT_ADDR (remover trailing slash)
VAULT_ADDR="${VAULT_ADDR%/}"

echo "=========================================="
echo "Creando secretos de prueba en Vault"
echo "=========================================="
echo "Vault Address: $VAULT_ADDR"
echo "KV Mount Path: $KV_MOUNT_PATH"
echo ""

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
    curl -k -s -f "${headers[@]}" "$url" || return 1
  elif [ "$method" = "PUT" ] || [ "$method" = "POST" ]; then
    curl -k -s -f -X "$method" "${headers[@]}" -d "$data" "$url" || return 1
  else
    echo "Error: Método HTTP no soportado: $method" >&2
    return 1
  fi
}

# Función para crear un secreto en KV v2
create_kv_secret() {
  local secret_path=$1
  shift
  local key_value_pairs=("$@")
  
  # Construir el JSON con los pares clave-valor
  local json_data="{"
  local first=true
  
  for pair in "${key_value_pairs[@]}"; do
    # Separar clave y valor (formato: key=value)
    local key="${pair%%=*}"
    local value="${pair#*=}"
    
    # Escapar comillas y caracteres especiales en el valor
    value=$(echo "$value" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    if [ "$first" = true ]; then
      first=false
    else
      json_data="${json_data},"
    fi
    
    json_data="${json_data}\"${key}\":\"${value}\""
  done
  
  json_data="${json_data}}"
  
  # Crear el payload completo para KV v2
  local payload="{\"data\":${json_data}}"
  
  # Hacer la petición PUT a la API
  local api_path="${KV_MOUNT_PATH}/data/${secret_path}"
  
  if vault_api_request "PUT" "$api_path" "$payload" > /dev/null; then
    return 0
  else
    return 1
  fi
}

# Verificar conexión a Vault
echo "Verificando conexión a Vault..."
# El endpoint /sys/health puede retornar códigos no-2xx (ej: 429 en standby)
# Por lo tanto, verificamos que la conexión funciona sin el flag -f
# Usamos -w para obtener el código HTTP y verificamos que obtuvimos una respuesta
health_check=$(curl -k -s -w "%{http_code}" -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/sys/health" -o /dev/null 2>&1)
curl_exit_code=$?

# Verificar que curl se ejecutó correctamente (no errores de conexión)
if [ $curl_exit_code -ne 0 ]; then
  echo "Error: No se puede conectar a Vault"
  echo "Verifica:"
  echo "  - VAULT_ADDR está correcto: $VAULT_ADDR"
  echo "  - El servidor de Vault es accesible"
  echo "  - No hay problemas de red o firewall"
  exit 1
fi

# Verificar que obtuvimos un código HTTP (cualquier código significa que el servidor responde)
if [ -z "$health_check" ]; then
  echo "Error: No se recibió respuesta del servidor de Vault"
  echo "Verifica que VAULT_ADDR sea correcto: $VAULT_ADDR"
  exit 1
fi

# Verificar que el token es válido (códigos 200, 429, 472, 473 son válidos para /sys/health)
# Códigos de error comunes: 403 (forbidden), 401 (unauthorized)
if echo "$health_check" | grep -qE "^(403|401)"; then
  echo "Error: VAULT_TOKEN no es válido o no tiene permisos"
  echo "Verifica que el token sea correcto y tenga los permisos necesarios"
  exit 1
fi

echo "✓ Conexión a Vault verificada"
echo ""

# Crear secretos de prueba
echo "1. Creando secreto ${KV_MOUNT_PATH}/chimera/database..."
if create_kv_secret "chimera/database" \
  "username=dbuser" \
  "password=dbpass123" \
  "host=db.example.com" \
  "port=5432"; then
  echo "   ✓ Secreto creado exitosamente"
else
  echo "   ✗ Error al crear el secreto"
  exit 1
fi

echo "2. Creando secreto ${KV_MOUNT_PATH}/chimera/api-key..."
if create_kv_secret "chimera/api-key" \
  "api_key=sk-1234567890abcdef" \
  "api_secret=secret-key-12345"; then
  echo "   ✓ Secreto creado exitosamente"
else
  echo "   ✗ Error al crear el secreto"
  exit 1
fi

echo "3. Creando secreto ${KV_MOUNT_PATH}/chimera/config..."
if create_kv_secret "chimera/config" \
  "environment=production" \
  "log_level=info" \
  "max_connections=100"; then
  echo "   ✓ Secreto creado exitosamente"
else
  echo "   ✗ Error al crear el secreto"
  exit 1
fi

echo ""
echo "=========================================="
echo "Secretos creados exitosamente"
echo "=========================================="
echo ""
echo "Secretos disponibles:"
echo "  - ${KV_MOUNT_PATH}/chimera/database"
echo "  - ${KV_MOUNT_PATH}/chimera/api-key"
echo "  - ${KV_MOUNT_PATH}/chimera/config"
echo ""
echo "Verificar secretos usando la API:"
echo "  curl -H \"X-Vault-Token: \$VAULT_TOKEN\" \\"
echo "    ${VAULT_ADDR}/v1/${KV_MOUNT_PATH}/data/chimera/database"
echo ""
