# Instalación del Vault Agent Injector

El Vault Agent Injector es un componente de Kubernetes que inyecta automáticamente el sidecar `vault-agent` en los pods que tienen las anotaciones apropiadas.

## Verificar si ya está Instalado

```bash
# Buscar deployments del injector
kubectl get deployment -A | grep -i injector

# Buscar pods del injector
kubectl get pods -A | grep -i injector

# Buscar en namespace específico (común: vault, default)
kubectl get deployment -n vault | grep injector
kubectl get pods -n vault | grep injector
```

## Opción 1: Instalación con Helm (Recomendado)

### Prerrequisitos

```bash
# Agregar el repositorio de HashiCorp
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

### Instalación Solo del Injector

Si Vault ya está instalado en otro lugar y solo necesitas el injector:

```bash
# Instalar solo el injector en el namespace 'vault'
helm install vault-injector hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set server.enabled=false \
  --set injector.enabled=true \
  --set injector.externalVaultAddr="https://tu-vault-address.com"
```

**Importante**: Reemplaza `https://tu-vault-address.com` con la dirección real de tu Vault.

### Instalación Completa (Vault + Injector)

Si necesitas instalar Vault completo:

```bash
# Instalar Vault con injector habilitado
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set injector.enabled=true
```

## Opción 2: Instalación Manual con YAML

### 1. Crear Namespace

```bash
kubectl create namespace vault
```

### 2. Crear ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-agent-injector
  namespace: vault
```

### 3. Crear ConfigMap con Configuración

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-agent-injector-config
  namespace: vault
data:
  VAULT_ADDR: "https://tu-vault-address.com"
  # O usar externalVaultAddr si Vault está fuera del cluster
```

### 4. Aplicar Deployment del Injector

Necesitarás el YAML del deployment. Puedes obtenerlo de:
- La documentación oficial de HashiCorp
- O usar Helm con `--dry-run` para generar el YAML:

```bash
helm template vault hashicorp/vault \
  --set server.enabled=false \
  --set injector.enabled=true \
  --set injector.externalVaultAddr="https://tu-vault-address.com" \
  > vault-injector.yaml

# Revisar y aplicar
kubectl apply -f vault-injector.yaml
```

## Opción 3: Si Vault está en Otro Cluster

Si Vault está desplegado en otro cluster o fuera de Kubernetes:

```bash
helm install vault-injector hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set server.enabled=false \
  --set injector.enabled=true \
  --set injector.externalVaultAddr="https://k8s-vault-vaultui-62506ffd89-622e5694cde0e9a6.elb.us-east-1.amazonaws.com"
```

**Nota**: Asegúrate de que el injector pueda alcanzar Vault desde el cluster.

## Verificar la Instalación

### 1. Verificar que el Injector está Corriendo

```bash
# Ver deployment
kubectl get deployment -n vault vault-agent-injector

# Ver pods
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector

# Ver logs
kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector
```

### 2. Verificar MutatingWebhookConfiguration

El injector crea un `MutatingWebhookConfiguration` que intercepta la creación de pods:

```bash
kubectl get mutatingwebhookconfiguration | grep vault

# Ver detalles
kubectl get mutatingwebhookconfiguration vault-agent-injector-cfg -o yaml
```

### 3. Probar con un Pod de Prueba

```bash
# Aplicar el pod de prueba
kubectl apply -f test-pod.yaml

# Verificar que el sidecar se inyectó
kubectl get pod vault-test -n app -o jsonpath='{.spec.containers[*].name}'
# Debe mostrar: test vault-agent

# Ver logs del vault-agent
kubectl logs vault-test -n app -c vault-agent
```

## Configuración Adicional

### Configurar Vault Address

Si Vault está en otro lugar, configura la dirección:

```bash
# Usando Helm values
helm upgrade vault-injector hashicorp/vault \
  --set injector.externalVaultAddr="https://tu-vault-address.com" \
  --reuse-values

# O editando el ConfigMap
kubectl edit configmap vault-agent-injector-config -n vault
```

### Configurar TLS

Si Vault usa certificados autofirmados:

```bash
# Agregar CA certificate al injector
kubectl create secret generic vault-ca \
  --from-file=ca.crt=/path/to/ca.crt \
  -n vault

# Configurar en Helm
helm upgrade vault-injector hashicorp/vault \
  --set injector.tlsSecretName=vault-ca \
  --reuse-values
```

## Troubleshooting

### El Injector no Inyecta el Sidecar

1. **Verificar que el MutatingWebhook está configurado:**
   ```bash
   kubectl get mutatingwebhookconfiguration vault-agent-injector-cfg
   ```

2. **Verificar logs del injector:**
   ```bash
   kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector
   ```

3. **Verificar eventos del pod:**
   ```bash
   kubectl describe pod vault-test -n app
   ```

### El Injector no Puede Alcanzar Vault

1. **Verificar conectividad desde el pod del injector:**
   ```bash
   kubectl exec -n vault -l app.kubernetes.io/name=vault-agent-injector -- wget -O- $VAULT_ADDR/v1/sys/health
   ```

2. **Verificar configuración de red:**
   - Network Policies
   - Service Mesh (Istio, Linkerd)
   - Firewall rules

### Errores de Certificado

Si ves errores de certificado:

```bash
# Verificar certificado de Vault
openssl s_client -connect tu-vault-address.com:443 -showcerts

# Configurar skip TLS verify (solo para desarrollo)
# Editar el deployment del injector
kubectl edit deployment vault-agent-injector -n vault
# Agregar variable de entorno: VAULT_SKIP_VERIFY=true
```

## Desinstalación

```bash
# Si instalaste con Helm
helm uninstall vault-injector -n vault

# Limpiar recursos manualmente si es necesario
kubectl delete mutatingwebhookconfiguration vault-agent-injector-cfg
kubectl delete namespace vault  # Solo si no hay otros recursos
```

## Referencias

- [HashiCorp Vault Helm Chart](https://github.com/hashicorp/vault-helm)
- [Vault Agent Injector Documentation](https://www.vaultproject.io/docs/platform/k8s/injector)
- [Vault Agent Injector GitHub](https://github.com/hashicorp/vault-k8s)
