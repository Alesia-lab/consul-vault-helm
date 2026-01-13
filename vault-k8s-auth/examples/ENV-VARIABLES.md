# Inyección de Variables de Entorno desde Vault

Este documento explica cómo usar las anotaciones `agent-inject-secret-env-*` para inyectar secretos de Vault como variables de entorno en los contenedores.

## Configuración

### Anotaciones Requeridas

Para inyectar secretos como variables de entorno, necesitas dos anotaciones:

1. **`vault.hashicorp.com/agent-inject-secret-env-<nombre>`**: Especifica el path del secreto en Vault
2. **`vault.hashicorp.com/agent-inject-template-env-<nombre>`**: Template que define cómo se formatean las variables

### Ejemplo

```yaml
annotations:
  vault.hashicorp.com/agent-inject-secret-env-database: "secret/data/app/database"
  vault.hashicorp.com/agent-inject-template-env-database: |
    {{- with secret "secret/data/app/database" -}}
    DB_USERNAME={{ .Data.data.username }}
    DB_PASSWORD={{ .Data.data.password }}
    {{- end }}
```

## Cómo Funciona

1. El vault-agent crea un archivo en `/vault/secrets/env-<nombre>` con el contenido del template
2. El archivo contiene las variables en formato `KEY=VALUE` (una por línea)
3. **IMPORTANTE**: El archivo NO se carga automáticamente como variables de entorno
4. Necesitas modificar el comando del contenedor para cargar el archivo antes de ejecutar la aplicación

## Configuración del Contenedor

### Opción 1: Cargar en el Comando Principal (Recomendado)

Modifica el `command` y `args` del contenedor para cargar el archivo antes de ejecutar la aplicación:

```yaml
containers:
- name: app
  image: nginx:alpine
  command: ["/bin/sh", "-c"]
  args:
    - |
      # Cargar variables de entorno desde archivos generados por vault-agent
      if [ -f /vault/secrets/env-database ]; then
        set -a  # Automáticamente exporta todas las variables
        . /vault/secrets/env-database  # Cargar el archivo
        set +a
      fi
      # Ejecutar la aplicación principal
      exec nginx -g "daemon off;"
```

### Opción 2: Usar un Entrypoint Script

Crea un script de entrada que cargue las variables:

```yaml
containers:
- name: app
  image: nginx:alpine
  command: ["/bin/sh", "-c"]
  args:
    - |
      # Cargar todas las variables de entorno disponibles
      for env_file in /vault/secrets/env-*; do
        if [ -f "$env_file" ]; then
          set -a
          . "$env_file"
          set +a
        fi
      done
      # Ejecutar la aplicación
      exec nginx -g "daemon off;"
```

## Verificación

### Verificar que el Archivo Existe

```bash
kubectl exec <pod-name> -n <namespace> -c <container> -- cat /vault/secrets/env-database
```

Debería mostrar:
```
DB_USERNAME=dbuser
DB_PASSWORD=dbpass123
```

### Verificar Variables en el Proceso Principal

```bash
# Ver variables en el proceso principal (PID 1)
kubectl exec <pod-name> -n <namespace> -c <container> -- \
  cat /proc/1/environ | tr '\0' '\n' | grep DB_USERNAME
```

### Verificar Variables en un Shell Interactivo

Si haces `kubectl exec` en el pod, las variables NO estarán disponibles automáticamente porque estás creando un nuevo shell. Para cargarlas:

```bash
kubectl exec -it <pod-name> -n <namespace> -c <container> -- /bin/sh
# Dentro del shell:
source /vault/secrets/env-database
echo $DB_USERNAME
```

## Diferencia entre Archivos y Variables de Entorno

### Archivos (agent-inject-secret-*)

- **Anotación**: `vault.hashicorp.com/agent-inject-secret-<nombre>`
- **Ubicación**: `/vault/secrets/<nombre>`
- **Uso**: Leer directamente desde el archivo
- **Ventaja**: No requiere modificar el comando del contenedor

```yaml
annotations:
  vault.hashicorp.com/agent-inject-secret-database: "secret/data/app/database"
  vault.hashicorp.com/agent-inject-template-database: |
    {{- with secret "secret/data/app/database" -}}
    DB_USERNAME={{ .Data.data.username }}
    DB_PASSWORD={{ .Data.data.password }}
    {{- end }}
```

Uso en la aplicación:
```bash
# Leer desde archivo
DB_USERNAME=$(grep DB_USERNAME /vault/secrets/database | cut -d= -f2)
```

### Variables de Entorno (agent-inject-secret-env-*)

- **Anotación**: `vault.hashicorp.com/agent-inject-secret-env-<nombre>`
- **Ubicación**: `/vault/secrets/env-<nombre>`
- **Uso**: Cargar como variables de entorno
- **Ventaja**: Compatible con aplicaciones que esperan variables de entorno
- **Desventaja**: Requiere modificar el comando del contenedor

```yaml
annotations:
  vault.hashicorp.com/agent-inject-secret-env-database: "secret/data/app/database"
  vault.hashicorp.com/agent-inject-template-env-database: |
    {{- with secret "secret/data/app/database" -}}
    DB_USERNAME={{ .Data.data.username }}
    DB_PASSWORD={{ .Data.data.password }}
    {{- end }}
```

Uso en la aplicación:
```bash
# Las variables ya están disponibles como $DB_USERNAME, $DB_PASSWORD
echo $DB_USERNAME
```

## Ejemplo Completo

Ver `test-deployment.yaml` para un ejemplo completo que muestra:
- Inyección de secretos como archivos
- Inyección de secretos como variables de entorno
- Configuración del comando del contenedor para cargar variables

## Troubleshooting

### Las Variables No Están Disponibles

1. **Verificar que el archivo existe:**
   ```bash
   kubectl exec <pod> -c <container> -- ls -la /vault/secrets/env-*
   ```

2. **Verificar el contenido del archivo:**
   ```bash
   kubectl exec <pod> -c <container> -- cat /vault/secrets/env-database
   ```

3. **Verificar que el comando del contenedor carga el archivo:**
   ```bash
   kubectl get pod <pod> -o yaml | grep -A 10 "command:"
   ```

4. **Verificar logs del vault-agent:**
   ```bash
   kubectl logs <pod> -c vault-agent
   ```

### Las Variables Están Vacías

- Verificar que los secretos existen en Vault
- Verificar que el role tiene permisos para leer los secretos
- Verificar el formato del template (debe ser `KEY=VALUE`)

## Referencias

- [Vault Agent Injector Annotations](https://www.vaultproject.io/docs/platform/k8s/injector/annotations)
- [Vault Agent Templates](https://www.vaultproject.io/docs/agent/template)
