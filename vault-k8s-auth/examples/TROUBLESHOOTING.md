# Troubleshooting - Vault Agent Sidecar Injection

Esta guía te ayudará a diagnosticar y resolver problemas comunes con la inyección de secretos de Vault.

## ⚠️ Problema Más Común: Vault Injector No Instalado

Si el diagnóstico muestra "vault-agent-injector NO encontrado", **el injector no está instalado**.

**Solución**: Consulta `INSTALL-INJECTOR.md` para instrucciones de instalación.

El injector es **requerido** para que funcione la inyección de secretos. Sin él, el sidecar `vault-agent` no se inyectará en los pods.

## Problema: Los secretos no se inyectan en /vault/secrets

### Paso 1: Ejecutar Script de Diagnóstico

```bash
cd examples
./diagnose-vault-injection.sh vault-test app
```

Este script verificará:
- Si el vault-injector está instalado
- Si el sidecar vault-agent se inyectó
- Las anotaciones del pod
- Los logs del vault-agent
- El volumen /vault/secrets

### Paso 2: Verificar Requisitos Básicos

#### 1. Vault Injector Instalado

```bash
# Verificar que el vault-injector está corriendo
kubectl get deployment -A | grep vault-agent-injector

# Ver logs del injector
kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector --tail=50
```

**Si no está instalado:**
- El vault-injector debe estar instalado en el cluster
- Normalmente se instala con Helm: `helm install vault hashicorp/vault`
- O como parte de la instalación de Vault

#### 2. Volumen Compartido Requerido

**IMPORTANTE**: El vault-injector requiere un volumen compartido entre el contenedor principal y el sidecar.

El volumen debe estar definido en el spec del pod:

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

**Si falta el volumen:**
- Los secretos no se pueden montar
- El vault-agent no puede escribir los archivos
- Verifica que el volumen esté en el spec ANTES de aplicar

#### 3. Anotaciones Correctas

Verifica que todas las anotaciones necesarias estén presentes:

```bash
kubectl get pod vault-test -n app -o yaml | grep -A 30 annotations
```

Anotaciones requeridas:
- `vault.hashicorp.com/agent-inject: "true"`
- `vault.hashicorp.com/role: "app-readonly"`
- `vault.hashicorp.com/auth-path: "auth/kubernetes-cluster-b"`
- `vault.hashicorp.com/agent-inject-secret-<nombre>: "secret/data/..."`

#### 4. ServiceAccount y Role Coinciden

```bash
# Verificar ServiceAccount del pod
kubectl get pod vault-test -n app -o jsonpath='{.spec.serviceAccountName}'

# Verificar que el role en Vault permite este ServiceAccount
vault read auth/kubernetes-cluster-b/role/app-readonly
```

El role debe tener:
- `bound_service_account_names` que incluya el ServiceAccount del pod
- `bound_service_account_namespaces` que incluya el namespace del pod

#### 5. Logs del Vault-Agent

```bash
# Ver logs completos del vault-agent
kubectl logs vault-test -n app -c vault-agent

# Ver logs en tiempo real
kubectl logs vault-test -n app -c vault-agent -f
```

**Errores comunes en los logs:**

1. **"error authenticating":**
   - El token de Kubernetes no es válido
   - El role no existe o no coincide con el ServiceAccount
   - El auth path es incorrecto

2. **"permission denied" o "no path found":**
   - La política no permite acceso al path del secreto
   - El path del secreto es incorrecto
   - El secreto no existe en Vault

3. **"connection refused" o "no route to host":**
   - El pod no puede alcanzar Vault
   - Verifica `vault.hashicorp.com/agent-pre-populate-only` si está configurado

### Paso 3: Verificar Configuración en Vault

```bash
# 1. Verificar que el auth backend está configurado
vault read auth/kubernetes-cluster-b/config

# 2. Verificar que el role existe
vault list auth/kubernetes-cluster-b/role
vault read auth/kubernetes-cluster-b/role/app-readonly

# 3. Verificar que las políticas existen
vault policy list
vault policy read app-readonly-policy

# 4. Verificar que los secretos existen
vault kv get secret/app/database
vault kv get secret/app/api-key
```

### Paso 4: Verificar Conectividad

```bash
# Desde dentro del pod, verificar que puede alcanzar Vault
kubectl exec vault-test -n app -c test -- wget -O- https://vault-address/v1/sys/health

# Verificar variables de entorno del vault-agent
kubectl exec vault-test -n app -c vault-agent -- env | grep VAULT
```

## Problemas Comunes y Soluciones

### Problema 1: "vault-agent sidecar no está presente"

**Causa**: El vault-injector no está instalado o no está funcionando.

**Solución**:
```bash
# Verificar que el injector está corriendo
kubectl get pods -A | grep vault-agent-injector

# Si no está, instalarlo (ejemplo con Helm)
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault --set injector.enabled=true
```

### Problema 2: "Error authenticating"

**Causa**: El ServiceAccount o namespace no coinciden con el role.

**Solución**:
1. Verificar el ServiceAccount del pod:
   ```bash
   kubectl get pod vault-test -n app -o jsonpath='{.spec.serviceAccountName}'
   ```

2. Verificar el role en Vault:
   ```bash
   vault read auth/kubernetes-cluster-b/role/app-readonly
   ```

3. Asegurar que coinciden:
   - ServiceAccount del pod debe estar en `bound_service_account_names`
   - Namespace del pod debe estar en `bound_service_account_namespaces`

### Problema 3: "Permission denied" al leer secretos

**Causa**: La política no permite acceso al path del secreto.

**Solución**:
1. Verificar la política:
   ```bash
   vault policy read app-readonly-policy
   ```

2. Verificar que el path del secreto está permitido:
   - El path en la anotación: `secret/data/app/database`
   - La política debe permitir: `path "secret/data/app/*"`

3. Actualizar la política si es necesario (en Terraform o manualmente)

### Problema 4: "No route to host" o "Connection refused"

**Causa**: El pod no puede alcanzar Vault.

**Solución**:
1. Verificar la dirección de Vault:
   ```bash
   kubectl exec vault-test -n app -c vault-agent -- env | grep VAULT_ADDR
   ```

2. Verificar conectividad:
   ```bash
   kubectl exec vault-test -n app -c vault-agent -- wget -O- $VAULT_ADDR/v1/sys/health
   ```

3. Si Vault está en otro cluster/red, verificar:
   - Network policies
   - Service mesh (Istio, Linkerd)
   - Firewall rules

### Problema 5: Archivos en /vault/secrets están vacíos o no existen

**Causa**: El volumen no está montado correctamente o el vault-agent no escribió los archivos.

**Solución**:
1. Verificar que el volumen está montado:
   ```bash
   kubectl exec vault-test -n app -c test -- ls -la /vault/secrets/
   ```

2. Verificar logs del vault-agent para errores

3. Verificar que el volumen está definido en el spec del pod (ver ejemplo arriba)

## Comandos Útiles de Debugging

```bash
# Ver todos los contenedores del pod
kubectl get pod vault-test -n app -o jsonpath='{.spec.containers[*].name}'

# Ver anotaciones completas
kubectl get pod vault-test -n app -o yaml | grep -A 50 annotations

# Ver eventos del pod
kubectl describe pod vault-test -n app

# Ver logs del injector
kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector --tail=100

# Ejecutar shell en el vault-agent
kubectl exec -it vault-test -n app -c vault-agent -- /bin/sh

# Verificar archivos desde el vault-agent
kubectl exec vault-test -n app -c vault-agent -- ls -la /vault/secrets/
```

## Verificación Final

Una vez resuelto el problema, verifica que todo funciona:

```bash
# 1. Verificar que los archivos existen
kubectl exec vault-test -n app -c test -- ls -la /vault/secrets/

# 2. Ver contenido de los secretos
kubectl exec vault-test -n app -c test -- cat /vault/secrets/database
kubectl exec vault-test -n app -c test -- cat /vault/secrets/api-key

# 3. Verificar logs del vault-agent (debe mostrar éxito)
kubectl logs vault-test -n app -c vault-agent | tail -20
```
