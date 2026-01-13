# Guía de Testing - Probar Kubernetes Auth en Cluster-B

Esta guía te ayudará a probar la configuración de Kubernetes Auth usando un pod simple con Vault Agent Sidecar Injector.

## Prerrequisitos

1. **Vault Agent Sidecar Injector** instalado en el cluster-b
2. **ServiceAccount** creado que coincida con los roles configurados
3. **Secretos** creados en Vault para probar el acceso

## Paso 1: Crear Secretos en Vault

Primero, crea algunos secretos de prueba en Vault:

**Opción A: Usar el script (Recomendado - usa API REST, no requiere CLI de Vault)**

```bash
# Configurar variables
export VAULT_ADDR="https://k8s-vault-vaultui-62506ffd89-622e5694cde0e9a6.elb.us-east-1.amazonaws.com"
export VAULT_TOKEN="tu-token-aqui"

# Ejecutar script (solo requiere curl)
cd examples
./create-test-secrets.sh
```

**Opción B: Usar CLI de Vault (si lo tienes instalado)**

```bash
# Conectarse a Vault
export VAULT_ADDR="https://k8s-vault-vaultui-62506ffd89-622e5694cde0e9a6.elb.us-east-1.amazonaws.com"
export VAULT_TOKEN="tu-token-aqui"

# Crear secretos de prueba en KV v2
vault kv put secret/app/database \
  username="dbuser" \
  password="dbpass123"

vault kv put secret/app/api-key \
  api_key="sk-1234567890abcdef"
```

**Nota**: El script `create-test-secrets.sh` usa la API REST de Vault directamente, por lo que solo requiere `curl` y no necesita el CLI de Vault instalado.

## Paso 2: Crear ServiceAccount en Kubernetes

Crea un ServiceAccount que coincida con los roles configurados:

```bash
# En el cluster-b
kubectl create namespace app
kubectl create serviceaccount app-sa -n app
```

## Paso 3: Desplegar Pod de Prueba

Crea un pod simple con las anotaciones de vault-injector:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: vault-test
  namespace: app
  annotations:
    # Habilitar vault-injector
    vault.hashicorp.com/agent-inject: "true"
    
    # Auth method a usar
    vault.hashicorp.com/agent-inject-secret-database: "secret/data/app/database"
    vault.hashicorp.com/agent-inject-template-database: |
      {{- with secret "secret/data/app/database" -}}
      username={{ .Data.data.username }}
      password={{ .Data.data.password }}
      {{- end }}
    
    # Segundo secreto de ejemplo
    vault.hashicorp.com/agent-inject-secret-api-key: "secret/data/app/api-key"
    vault.hashicorp.com/agent-inject-template-api-key: |
      {{- with secret "secret/data/app/api-key" -}}
      API_KEY={{ .Data.data.api_key }}
      {{- end }}
    
    # Role de Kubernetes Auth a usar
    vault.hashicorp.com/role: "app-readonly"
    
    # Auth path (debe coincidir con el configurado en Terraform)
    vault.hashicorp.com/auth-path: "auth/kubernetes-cluster-b"
spec:
  serviceAccountName: app-sa
  containers:
  - name: test
    image: busybox:latest
    command: ["/bin/sh", "-c", "sleep 3600"]
EOF
```

## Paso 4: Verificar que Funciona

```bash
# Ver logs del vault-agent (sidecar inyectado)
kubectl logs vault-test -n app -c vault-agent

# Ver logs del contenedor principal
kubectl logs vault-test -n app -c test

# Verificar que los secretos están montados
kubectl exec vault-test -n app -c test -- ls -la /vault/secrets/

# Ver contenido de los secretos
kubectl exec vault-test -n app -c test -- cat /vault/secrets/database
kubectl exec vault-test -n app -c test -- cat /vault/secrets/api-key
```

## Ejemplo Completo con Deployment

Para un ejemplo más realista, usa un Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-test-app
  namespace: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault-test
  template:
    metadata:
      labels:
        app: vault-test
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "app-readonly"
        vault.hashicorp.com/auth-path: "auth/kubernetes-cluster-b"
        vault.hashicorp.com/agent-inject-secret-database: "secret/data/app/database"
        vault.hashicorp.com/agent-inject-template-database: |
          {{- with secret "secret/data/app/database" -}}
          DB_USERNAME={{ .Data.data.username }}
          DB_PASSWORD={{ .Data.data.password }}
          {{- end }}
    spec:
      serviceAccountName: app-sa
      containers:
      - name: app
        image: nginx:alpine
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: vault-database
              key: DB_USERNAME
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: vault-database
              key: DB_PASSWORD
```

## Troubleshooting

### Paso 1: Ejecutar Diagnóstico Automático

```bash
cd examples
./diagnose-vault-injection.sh vault-test app
```

Este script verificará automáticamente:
- Si el vault-injector está instalado
- Si el sidecar se inyectó correctamente
- Las anotaciones del pod
- Los logs del vault-agent
- El volumen /vault/secrets

### Paso 2: Verificar Requisitos Básicos

**IMPORTANTE**: El volumen compartido es REQUERIDO. Asegúrate de que el pod tenga:

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: vault-secrets
      mountPath: /vault/secrets
      readOnly: true
  volumes:
  - name: vault-secrets
    emptyDir: {}
```

### Problemas Comunes

#### Error: "vault-agent sidecar no está presente"

**Causa**: El vault-injector no está instalado o no está funcionando.

**Solución**:
```bash
# Verificar que el injector está corriendo
kubectl get pods -A | grep vault-agent-injector

# Ver logs del injector
kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector
```

#### Error: "permission denied" o "no path found"

**Causa**: La política no permite acceso al path o el path no existe.

**Solución**:
1. Verificar que el secreto existe: `vault kv get secret/app/database`
2. Verificar la política: `vault policy read app-readonly-policy`
3. Verificar que el role tiene la política: `vault read auth/kubernetes-cluster-b/role/app-readonly`

#### Error: "role not found" o "error authenticating"

**Causa**: El role no existe, el auth path es incorrecto, o el ServiceAccount/namespace no coinciden.

**Solución**:
1. Verificar que el role existe: `vault list auth/kubernetes-cluster-b/role`
2. Verificar el auth path en las anotaciones: `vault.hashicorp.com/auth-path: "auth/kubernetes-cluster-b"`
3. Verificar que el ServiceAccount del pod coincide con `bound_service_account_names` del role
4. Verificar que el namespace del pod coincide con `bound_service_account_namespaces` del role

#### Error: Archivos no aparecen en /vault/secrets

**Causa**: El volumen no está montado o el vault-agent no escribió los archivos.

**Solución**:
1. Verificar que el volumen está definido en el spec del pod
2. Ver logs del vault-agent: `kubectl logs vault-test -n app -c vault-agent`
3. Verificar que no hay errores de autenticación o permisos

### Ver Logs del Vault Agent

```bash
# Ver logs del sidecar
kubectl logs <pod-name> -n <namespace> -c vault-agent

# Ver logs con más detalle
kubectl logs <pod-name> -n <namespace> -c vault-agent -f

# Ver eventos del pod
kubectl describe pod <pod-name> -n <namespace>
```

### Guía Completa de Troubleshooting

Para una guía más detallada, consulta `examples/TROUBLESHOOTING.md`.

## Verificar Configuración en Vault

```bash
# Verificar auth backend configurado
vault read auth/kubernetes-cluster-b/config

# Listar roles
vault list auth/kubernetes-cluster-b/role

# Ver detalles de un role
vault read auth/kubernetes-cluster-b/role/app-readonly

# Verificar políticas
vault policy list
vault policy read app-readonly-policy
```

## Limpiar Recursos de Prueba

Para limpiar todos los recursos creados durante el testing:

```bash
cd examples

# Configurar variables de Vault
export VAULT_ADDR="https://tu-vault.example.com"
export VAULT_TOKEN="tu-token"

# Ejecutar script de limpieza (usa API REST, no requiere CLI de Vault)
./clean.sh
```

El script `clean.sh` elimina:
- ✅ Pods y Deployments de prueba (`vault-test`, `vault-test-app`)
- ✅ ServiceAccount `app-sa` en namespace `app`
- ✅ Namespace `app` (solo si está vacío)
- ✅ Secretos de Vault: `secret/app/database`, `secret/app/api-key`, `secret/app/config`

**Nota**: 
- El namespace solo se elimina automáticamente si está vacío. Si contiene otros recursos, deberás eliminarlo manualmente si es necesario.
- El script `clean.sh` usa la API REST de Vault directamente, por lo que solo requiere `curl` (no necesita el CLI de Vault instalado).

### Limpieza Manual

Si prefieres limpiar manualmente:

**Kubernetes:**
```bash
kubectl delete pod vault-test -n app
kubectl delete deployment vault-test-app -n app
kubectl delete serviceaccount app-sa -n app
kubectl delete namespace app  # Solo si está vacío
```

**Vault (usando API REST):**
```bash
# Eliminar secretos usando DELETE en el metadata path (KV v2)
curl -X DELETE \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  ${VAULT_ADDR}/v1/secret/metadata/app/database

curl -X DELETE \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  ${VAULT_ADDR}/v1/secret/metadata/app/api-key

curl -X DELETE \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  ${VAULT_ADDR}/v1/secret/metadata/app/config
```

**Vault (usando CLI, si lo tienes instalado):**
```bash
vault kv delete secret/app/database
vault kv delete secret/app/api-key
vault kv delete secret/app/config
```
