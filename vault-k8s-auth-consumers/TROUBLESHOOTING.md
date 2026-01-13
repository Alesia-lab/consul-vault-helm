# Troubleshooting - Vault Kubernetes Auth

Este documento describe problemas comunes y sus soluciones al configurar Vault con Kubernetes Auth.

## Problema: Error "no such host" al autenticarse

### Síntoma

Los logs del vault-agent muestran:

```
error="Put \"http://vault-injector.vault.svc:8200/v1/auth/kubernetes/login\": dial tcp: lookup vault-injector.vault.svc on 172.20.0.10:53: no such host"
```

### Causa

El vault-injector no tiene configurada la dirección de Vault (`externalVaultAddr` y `VAULT_ADDR`). Esto hace que el vault-agent intente conectarse a la dirección por defecto `vault-injector.vault.svc:8200`, que solo existe cuando Vault está en el mismo cluster.

### Solución Rápida (Helm Directo)

Si necesitas una solución inmediata sin re-aplicar Terraform:

```bash
# Actualizar el Helm release directamente
helm upgrade vault-injector hashicorp/vault -n vault --reuse-values \
  --set injector.externalVaultAddr="https://tu-vault-address.com" \
  --set injector.agentDefaults.extraEnvironmentVars.VAULT_ADDR="https://tu-vault-address.com" \
  --set injector.agentDefaults.extraEnvironmentVars.VAULT_SKIP_VERIFY="true"

# Recrear los pods para que usen la nueva configuración
kubectl delete pod vault-test -n app
kubectl apply -f test-pod.yaml
```

### Solución Permanente (Terraform)

1. **Crear o actualizar `terraform.tfvars`:**

```bash
cd vault-k8s-auth-consumers/cluster-b
cp terraform.tfvars.example terraform.tfvars
```

2. **Editar `terraform.tfvars` y asegurarse de que tiene:**

```hcl
vault_address = "https://tu-vault-address.com"
vault_skip_tls_verify = true  # Solo para desarrollo/testing
```

3. **Re-aplicar Terraform:**

```bash
terraform plan
terraform apply
```

4. **Verificar la configuración del Helm release:**

```bash
helm get values vault-injector -n vault | grep -A 5 externalVaultAddr
```

Debería mostrar:
```yaml
injector:
  externalVaultAddr: "https://tu-vault-address.com"
  agentDefaults:
    extraEnvironmentVars:
      VAULT_ADDR: "https://tu-vault-address.com"
```

5. **Recrear los pods afectados:**

```bash
# Eliminar pods existentes para que se recreen con la nueva configuración
kubectl delete pod vault-test -n app
kubectl apply -f test-pod.yaml
```

## Verificación

### 1. Verificar que el vault-injector tiene la configuración correcta

```bash
# Ver variables de entorno del deployment
kubectl get deployment vault-injector-agent-injector -n vault -o yaml | grep -A 3 AGENT_INJECT_VAULT_ADDR

# Debe mostrar:
# - name: AGENT_INJECT_VAULT_ADDR
#   value: https://tu-vault-address.com
```

### 2. Verificar que el pod puede conectarse a Vault

```bash
# Ver logs del vault-agent
kubectl logs vault-test -n app -c vault-agent-init

# Debe mostrar:
# [INFO] agent.auth.handler: authentication successful
# [INFO] agent: (runner) rendered "(dynamic)" => "/vault/secrets/..."
```

### 3. Verificar que los secretos están disponibles

```bash
# Listar secretos inyectados
kubectl exec vault-test -n app -c test -- ls -la /vault/secrets/

# Ver contenido de un secreto
kubectl exec vault-test -n app -c test -- cat /vault/secrets/database
```

## Problema: El vault-agent se conecta pero falla la autenticación

### Síntoma

Los logs muestran errores de autenticación como:
```
[ERROR] agent.auth.handler: error authenticating: error="* errors=\"[permission denied]"
```

### Causa

- El role de Kubernetes Auth no existe en Vault
- El ServiceAccount no coincide con el role configurado
- El auth path es incorrecto

### Solución

1. **Verificar que el role existe en Vault:**

```bash
export VAULT_ADDR="https://tu-vault-address.com"
export VAULT_TOKEN="tu-token"

vault read auth/kubernetes-cluster-b/role/app-readonly
```

2. **Verificar que el ServiceAccount coincide:**

```bash
# Ver ServiceAccount del pod
kubectl get pod vault-test -n app -o jsonpath='{.spec.serviceAccountName}'

# Verificar que el role en Vault permite este ServiceAccount
vault read auth/kubernetes-cluster-b/role/app-readonly | grep bound_service_account
```

3. **Verificar el auth path en las anotaciones del pod:**

```bash
kubectl get pod vault-test -n app -o jsonpath='{.metadata.annotations.vault\.hashicorp\.com/auth-path}'

# Debe coincidir con el auth path configurado en Terraform
```

## Problema: El vault-agent no se inyecta

### Síntoma

El pod no tiene el contenedor `vault-agent` o `vault-agent-init`.

### Causa

- El MutatingWebhookConfiguration no está configurado correctamente
- El vault-injector no está corriendo
- Las anotaciones del pod son incorrectas

### Solución

1. **Verificar que el MutatingWebhookConfiguration existe:**

```bash
kubectl get mutatingwebhookconfiguration | grep vault
```

2. **Verificar que el vault-injector está corriendo:**

```bash
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector
```

3. **Verificar las anotaciones del pod:**

```bash
kubectl get pod vault-test -n app -o yaml | grep -A 20 annotations
```

Debe tener:
- `vault.hashicorp.com/agent-inject: "true"`
- `vault.hashicorp.com/role: "nombre-del-role"`
- `vault.hashicorp.com/auth-path: "auth/kubernetes-cluster-b"`

## Problema: Los secretos no se renderizan

### Síntoma

Los secretos no aparecen en `/vault/secrets/` o están vacíos.

### Causa

- Los secretos no existen en Vault
- El role no tiene permisos para leer los secretos
- El template tiene errores de sintaxis

### Solución

1. **Verificar que los secretos existen en Vault:**

```bash
vault kv get secret/app/database
```

2. **Verificar que el role tiene permisos:**

```bash
# Ver las políticas del role
vault read auth/kubernetes-cluster-b/role/app-readonly | grep token_policies

# Verificar que la política permite leer el path
vault policy read app-readonly-policy
```

3. **Verificar los logs del vault-agent para errores de template:**

```bash
kubectl logs vault-test -n app -c vault-agent
```

## Comandos Útiles de Diagnóstico

```bash
# Ver configuración completa del vault-injector
helm get values vault-injector -n vault

# Ver variables de entorno del vault-agent en un pod
kubectl exec vault-test -n app -c vault-agent-init -- env | grep VAULT

# Ver configuración JSON del vault-agent
kubectl exec vault-test -n app -c vault-agent-init -- env | grep VAULT_CONFIG | cut -d= -f2 | base64 -d | jq .

# Probar conectividad a Vault desde el cluster
kubectl run test-curl --image=curlimages/curl --rm -it -- curl -k https://tu-vault-address.com/v1/sys/health

# Ver eventos del pod
kubectl describe pod vault-test -n app

# Ver logs del vault-injector
kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector
```

## Referencias

- [Vault Agent Injector Documentation](https://www.vaultproject.io/docs/platform/k8s/injector)
- [Kubernetes Auth Method](https://www.vaultproject.io/docs/auth/kubernetes)
- Ver también `CLUSTER-SETUP.md` para configuración paso a paso
