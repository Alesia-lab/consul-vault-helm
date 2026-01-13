# Configuración de Vault para Cualquier Cluster

Este documento explica cómo configurar el proyecto `vault-k8s-auth-consumers` para que funcione en cualquier cluster Kubernetes, incluyendo la solución a problemas comunes de conectividad.

## Problema Común: Error de DNS "no such host"

### Síntoma

Al desplegar un pod con vault-agent inyectado, puedes ver errores como:

```
error="Put \"http://vault-injector.vault.svc:8200/v1/auth/kubernetes/login\": dial tcp: lookup vault-injector.vault.svc on 172.20.0.10:53: no such host"
```

### Causa

El vault-agent está intentando conectarse a la dirección por defecto `vault-injector.vault.svc:8200`, que solo funciona cuando Vault está desplegado en el mismo cluster. Si Vault está en otro cluster o es externo, esta dirección no existe.

### Solución

Hay dos formas de resolver este problema:

#### Opción 1: Configurar VAULT_ADDR en el vault-injector (Recomendado)

El módulo `vault_injector` ahora configura automáticamente `VAULT_ADDR` en todos los pods inyectados a través de `agentDefaults.extraEnvironmentVars`. Esto se hace en el archivo `modules/vault_injector/values.yaml.tpl`.

**Asegúrate de que `vault_address` esté correctamente configurado en `terraform.tfvars`:**

```hcl
vault_address = "https://tu-vault-address.com"
```

#### Opción 2: Especificar VAULT_ADDR en cada pod (Alternativa)

Si necesitas una configuración específica por pod, puedes agregar la anotación `vault.hashicorp.com/agent-extra-env` en el pod:

```yaml
annotations:
  vault.hashicorp.com/agent-extra-env: |
    VAULT_ADDR=https://tu-vault-address.com
```

## Configuración Paso a Paso

### 1. Configurar el Cluster Consumidor

```bash
cd vault-k8s-auth-consumers/cluster-X  # Reemplaza X con el nombre de tu cluster

# Copiar y editar terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
```

### 2. Editar terraform.tfvars

Asegúrate de configurar correctamente:

```hcl
# Nombre del cluster
cluster_name = "cluster-X"
aws_region   = "us-east-1"

# Configuración del Vault Agent Injector
install_vault_injector = true

# ⚠️ IMPORTANTE: Dirección de Vault accesible desde el cluster
# Puede ser:
# - Una URL externa: https://vault.example.com
# - Un Load Balancer: https://k8s-vault-vaultui-xxxxx.elb.us-east-1.amazonaws.com
# - Un servicio interno (si Vault está en el mismo cluster): http://vault.vault.svc:8200
vault_address = "https://tu-vault-address.com"

# Deshabilitar verificación TLS solo si usas certificados autofirmados
vault_skip_tls_verify = true  # Solo para desarrollo/testing
```

### 3. Aplicar la Configuración

```bash
# Configurar credenciales AWS para el cluster
export AWS_PROFILE=cluster-x-profile

# Configurar kubeconfig
kubectl config use-context cluster-x-context

# Inicializar y aplicar
terraform init
terraform plan
terraform apply
```

### 4. Verificar la Instalación

```bash
# Verificar que el vault-injector está corriendo
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector

# Verificar la configuración del vault-injector
kubectl get deployment -n vault vault-injector -o yaml | grep -A 5 externalVaultAddr

# Verificar que el ServiceAccount existe
kubectl get serviceaccount -n kube-system vault-auth-reviewer
```

### 5. Probar con un Pod

Crea un pod de prueba (ver `vault-k8s-auth/examples/test-pod.yaml`) y verifica que:

1. El vault-agent se inyecta correctamente
2. El vault-agent puede conectarse a Vault
3. Los secretos se inyectan correctamente

```bash
# Aplicar el pod de prueba
kubectl apply -f ../../vault-k8s-auth/examples/test-pod.yaml

# Verificar que el vault-agent está corriendo
kubectl get pod vault-test -n app

# Ver logs del vault-agent
kubectl logs vault-test -n app -c vault-agent-init

# Verificar que los secretos están disponibles
kubectl exec vault-test -n app -c test -- ls -la /vault/secrets
```

## Configuración para Diferentes Escenarios

### Escenario 1: Vault en Otro Cluster (AWS ELB)

```hcl
vault_address = "https://k8s-vault-vaultui-xxxxx.elb.us-east-1.amazonaws.com"
vault_skip_tls_verify = true  # Si el certificado es autofirmado
```

**Requisitos:**
- El cluster debe poder alcanzar la URL del Load Balancer
- Los Security Groups deben permitir el tráfico
- Si usas certificados autofirmados, `vault_skip_tls_verify = true`

### Escenario 2: Vault en el Mismo Cluster

```hcl
vault_address = "http://vault.vault.svc:8200"
vault_skip_tls_verify = false
```

**Requisitos:**
- Vault debe estar desplegado en el namespace `vault`
- El servicio debe llamarse `vault`

### Escenario 3: Vault Externo (Internet)

```hcl
vault_address = "https://vault.example.com"
vault_skip_tls_verify = false  # Usar certificados válidos
```

**Requisitos:**
- El cluster debe tener acceso a Internet
- El certificado SSL debe ser válido
- Considerar usar un VPN o red privada para mayor seguridad

## Solución Rápida si el Problema Ya Existe

Si ya tienes el vault-injector instalado pero con la configuración incorrecta, puedes actualizarlo directamente con Helm:

```bash
# Actualizar el Helm release con la dirección correcta de Vault
helm upgrade vault-injector hashicorp/vault -n vault --reuse-values \
  --set injector.externalVaultAddr="https://tu-vault-address.com" \
  --set injector.agentDefaults.extraEnvironmentVars.VAULT_ADDR="https://tu-vault-address.com" \
  --set injector.agentDefaults.extraEnvironmentVars.VAULT_SKIP_VERIFY="true"

# Recrear los pods para que usen la nueva configuración
kubectl delete pod vault-test -n app
kubectl apply -f ../../vault-k8s-auth/examples/test-pod.yaml
```

**Nota**: Esta es una solución temporal. Para una solución permanente, re-aplica Terraform después de configurar `terraform.tfvars` correctamente.

## Troubleshooting

### El vault-agent no puede conectarse a Vault

1. **Verificar la dirección de Vault:**
   ```bash
   # Desde un pod en el cluster
   kubectl run test-curl --image=curlimages/curl --rm -it -- curl -k https://tu-vault-address.com/v1/sys/health
   ```

2. **Verificar la configuración del vault-injector:**
   ```bash
   kubectl get deployment -n vault vault-injector -o yaml | grep -A 10 externalVaultAddr
   ```

3. **Verificar variables de entorno en el pod:**
   ```bash
   kubectl exec vault-test -n app -c vault-agent-init -- env | grep VAULT
   ```

### El vault-agent se conecta pero falla la autenticación

1. **Verificar que el auth path es correcto:**
   ```yaml
   vault.hashicorp.com/auth-path: "auth/kubernetes-cluster-X"
   ```

2. **Verificar que el role existe en Vault:**
   ```bash
   vault read auth/kubernetes-cluster-X/role/app-readonly
   ```

3. **Verificar que el ServiceAccount tiene los permisos correctos:**
   ```bash
   kubectl get serviceaccount app-sa -n app
   kubectl get rolebinding -n app
   ```

### El vault-agent no se inyecta

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

## Mejores Prácticas

1. **Usar certificados válidos en producción:** Nunca usar `vault_skip_tls_verify = true` en producción
2. **Configurar VAULT_ADDR en el vault-injector:** Esto asegura que todos los pods usen la misma configuración
3. **Usar nombres de cluster consistentes:** El auth path debe coincidir con el nombre del cluster
4. **Monitorear los logs:** Revisar regularmente los logs del vault-agent para detectar problemas temprano
5. **Probar en un entorno de desarrollo primero:** Validar la configuración antes de aplicarla en producción

## Referencias

- [Vault Agent Injector Documentation](https://www.vaultproject.io/docs/platform/k8s/injector)
- [Kubernetes Auth Method](https://www.vaultproject.io/docs/auth/kubernetes)
- [Terraform Vault Provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)
