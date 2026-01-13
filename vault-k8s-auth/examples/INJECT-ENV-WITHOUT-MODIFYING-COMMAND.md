# Inyectar Variables de Entorno sin Modificar el Comando

Este documento explica cómo inyectar variables de entorno desde Vault **sin modificar el comando de inicialización** de tu microservicio, similar a como funcionan los secretos de Kubernetes.

## El Problema

Cuando usas secretos de Kubernetes, puedes hacer:

```yaml
containers:
- name: app
  image: myapp:latest
  envFrom:
  - secretRef:
      name: my-secrets
  # El comando original se ejecuta sin modificaciones
```

Pero con Vault, el vault-agent crea **archivos** en `/vault/secrets/`, no variables de entorno directamente. Esto significa que necesitas cargar esos archivos manualmente.

## Soluciones

### Opción 1: Script Wrapper Automático (Recomendado)

Usa un init container que crea un script wrapper que se ejecuta automáticamente antes del comando original:

```yaml
initContainers:
- name: vault-env-loader
  image: busybox:latest
  command: ["/bin/sh", "-c"]
  args:
    - |
      # Esperar a que vault-agent genere los archivos
      while [ ! -f /vault/secrets/env-database ]; do sleep 1; done
      
      # Crear script wrapper
      cat > /shared/vault-env-loader.sh << 'EOF'
      #!/bin/sh
      # Cargar variables de entorno
      for env_file in /vault/secrets/env-*; do
        [ -f "$env_file" ] && set -a && . "$env_file" && set +a
      done
      # Ejecutar comando original
      exec "$@"
      EOF
      chmod +x /shared/vault-env-loader.sh
  volumeMounts:
  - name: vault-secrets
    mountPath: /vault/secrets
  - name: shared-scripts
    mountPath: /shared

containers:
- name: app
  image: nginx:alpine
  # Usar el wrapper como entrypoint
  command: ["/shared/vault-env-loader.sh"]
  args: ["nginx", "-g", "daemon off;"]
  volumeMounts:
  - name: shared-scripts
    mountPath: /shared
```

**Ventajas:**
- ✅ No modificas el comando original de tu aplicación
- ✅ Funciona con cualquier imagen
- ✅ Las variables están disponibles automáticamente

**Desventajas:**
- Requiere un volumen compartido
- Requiere un init container

### Opción 2: Wrapper Inline Simple

Para casos más simples, puedes usar un wrapper inline:

```yaml
containers:
- name: app
  image: nginx:alpine
  command: ["/bin/sh", "-c"]
  args:
    - |
      # Cargar variables (si existen)
      [ -f /vault/secrets/env-database ] && set -a && . /vault/secrets/env-database && set +a || true
      # Ejecutar comando original
      exec nginx -g "daemon off;"
```

**Ventajas:**
- ✅ Simple y directo
- ✅ No requiere init container ni volúmenes adicionales

**Desventajas:**
- ❌ Modifica ligeramente el comando (pero no la lógica de la app)

### Opción 3: Usar Secretos de Kubernetes como Intermediario

Crea un init container que lea los archivos de Vault y los convierta en un Secret de Kubernetes:

```yaml
initContainers:
- name: vault-to-k8s-secret
  image: bitnami/kubectl:latest
  command: ["/bin/sh", "-c"]
  args:
    - |
      # Leer archivos de vault y crear un Secret
      DB_USERNAME=$(grep DB_USERNAME /vault/secrets/env-database | cut -d= -f2)
      DB_PASSWORD=$(grep DB_PASSWORD /vault/secrets/env-database | cut -d= -f2)
      
      kubectl create secret generic vault-env \
        --from-literal=DB_USERNAME="$DB_USERNAME" \
        --from-literal=DB_PASSWORD="$DB_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
  volumeMounts:
  - name: vault-secrets
    mountPath: /vault/secrets

containers:
- name: app
  image: nginx:alpine
  envFrom:
  - secretRef:
      name: vault-env
  # Comando original sin modificaciones
```

**Ventajas:**
- ✅ Funciona exactamente como secretos de Kubernetes
- ✅ No requiere modificar el comando

**Desventajas:**
- ❌ Requiere permisos RBAC para crear Secrets
- ❌ Más complejo de implementar

## Comparación con Secretos de Kubernetes

| Característica | Secretos de K8s | Vault (Archivos) | Vault (Wrapper) |
|---------------|-----------------|------------------|------------------|
| Inyección automática | ✅ Sí | ❌ No | ✅ Sí (con wrapper) |
| Modificar comando | ❌ No necesario | ✅ Sí | ⚠️ Mínimo |
| Compatibilidad | ✅ Total | ⚠️ Requiere cambios | ✅ Alta |
| Actualización dinámica | ❌ No | ✅ Sí | ✅ Sí |

## Recomendación

Para microservicios que **no quieres modificar**, usa la **Opción 1 (Script Wrapper Automático)**:

1. Es transparente para tu aplicación
2. No requiere modificar la lógica de tu microservicio
3. Funciona con cualquier imagen
4. Las variables están disponibles automáticamente

Ver `test-deployment-env-auto.yaml` para un ejemplo completo.

## Ejemplo Completo

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-microservice
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "app-readonly"
        vault.hashicorp.com/agent-inject-secret-env-database: "secret/data/app/db"
        vault.hashicorp.com/agent-inject-template-env-database: |
          {{- with secret "secret/data/app/db" -}}
          DB_USERNAME={{ .Data.data.username }}
          DB_PASSWORD={{ .Data.data.password }}
          {{- end }}
    spec:
      initContainers:
      - name: vault-env-loader
        image: busybox:latest
        command: ["/bin/sh", "-c"]
        args:
          - |
            while [ ! -f /vault/secrets/env-database ]; do sleep 1; done
            cat > /shared/load-env.sh << 'EOF'
            #!/bin/sh
            for f in /vault/secrets/env-*; do
              [ -f "$f" ] && set -a && . "$f" && set +a
            done
            exec "$@"
            EOF
            chmod +x /shared/load-env.sh
        volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
        - name: shared-scripts
          mountPath: /shared
      
      containers:
      - name: app
        image: my-microservice:latest
        # Tu aplicación se ejecuta normalmente, las variables están disponibles
        command: ["/shared/load-env.sh"]
        args: []  # Usa el ENTRYPOINT original de la imagen
        volumeMounts:
        - name: shared-scripts
          mountPath: /shared
      
      volumes:
      - name: shared-scripts
        emptyDir: {}
```

## Notas Importantes

1. **Timing**: El init container debe esperar a que `vault-agent-init` termine de generar los archivos
2. **Volúmenes**: Necesitas un volumen compartido entre el init container y el contenedor principal
3. **ENTRYPOINT vs CMD**: Si tu imagen tiene ENTRYPOINT, el wrapper lo ejecutará automáticamente
4. **Múltiples archivos**: El wrapper carga todos los archivos `env-*` automáticamente

## Referencias

- Ver `test-deployment-env-auto.yaml` para ejemplo completo con init container
- Ver `test-deployment-env-simple.yaml` para versión simplificada
- [Vault Agent Injector Documentation](https://www.vaultproject.io/docs/platform/k8s/injector)
