# Ejemplos de Testing

Este directorio contiene ejemplos para probar la configuración de Kubernetes Auth en Cluster-B.

## ⚠️ Prerrequisito Importante

**El Vault Agent Injector debe estar instalado en el cluster** para que funcione la inyección de secretos.

### Instalación Rápida

Si el diagnóstico muestra que el injector no está instalado, puedes instalarlo fácilmente:

```bash
# Opción 1: Usar el script automatizado (recomendado)
./install-injector.sh

# Opción 2: Instalación manual con Helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault-injector hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set server.enabled=false \
  --set injector.enabled=true \
  --set injector.externalVaultAddr="https://tu-vault-address.com"
```

Para más detalles, consulta `INSTALL-INJECTOR.md`.

## Archivos

- `test-pod.yaml`: Pod simple para testing rápido
- `test-deployment.yaml`: Deployment más realista (requiere modificar comando para variables de entorno)
- `test-deployment-env-auto.yaml`: Deployment con inyección automática de variables de entorno (sin modificar comando)
- `test-deployment-env-simple.yaml`: Deployment con wrapper simple para variables de entorno
- `setup-test.sh`: Script para crear namespace y ServiceAccount
- `create-test-secrets.sh`: Script para crear secretos de prueba en Vault
- `clean.sh`: Script para limpiar todos los recursos creados por los scripts de testing

## Documentación Adicional

- `ENV-VARIABLES.md`: Guía sobre cómo inyectar variables de entorno desde Vault
- `INJECT-ENV-WITHOUT-MODIFYING-COMMAND.md`: **IMPORTANTE** - Cómo inyectar variables de entorno sin modificar el comando de inicialización (para microservicios)

## Uso Rápido

### Paso 1: Crear Secretos en Vault

```bash
# Configurar variables
export VAULT_ADDR="https://tu-vault.example.com"
export VAULT_TOKEN="tu-token"

# Ejecutar script (usa API REST, no requiere CLI de Vault)
./create-test-secrets.sh
```

**Nota**: El script `create-test-secrets.sh` usa la API REST de Vault directamente, por lo que solo requiere `curl` (no necesita el CLI de Vault instalado).

O manualmente usando la API REST:

```bash
curl -X PUT \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data":{"username":"dbuser","password":"dbpass"}}' \
  ${VAULT_ADDR}/v1/secret/data/app/database
```

### Paso 2: Configurar Kubernetes

```bash
# Crear namespace y ServiceAccount
./setup-test.sh
```

O manualmente:

```bash
kubectl create namespace app
kubectl create serviceaccount app-sa -n app
```

### Paso 3: Desplegar Pod de Prueba

```bash
# Opción A: Pod simple
kubectl apply -f test-pod.yaml

# Opción B: Deployment
kubectl apply -f test-deployment.yaml
```

### Paso 4: Verificar

```bash
# Ver logs del vault-agent
kubectl logs vault-test -n app -c vault-agent

# Ver secretos inyectados
kubectl exec vault-test -n app -c test -- ls -la /vault/secrets/
kubectl exec vault-test -n app -c test -- cat /vault/secrets/database
```

### Paso 5: Limpiar Recursos

```bash
# Limpiar todos los recursos creados (pods, deployments, ServiceAccount, secretos de Vault)
export VAULT_ADDR="https://tu-vault.example.com"
export VAULT_TOKEN="tu-token"
./clean.sh
```

El script `clean.sh` elimina:
- Pods y Deployments de prueba
- ServiceAccount `app-sa`
- Namespace `app` (solo si está vacío)
- Secretos de Vault: `secret/app/database`, `secret/app/api-key`, `secret/app/config`

## Anotaciones Importantes

### Anotaciones Requeridas

- `vault.hashicorp.com/agent-inject: "true"` - Habilita el inyector
- `vault.hashicorp.com/role: "app-readonly"` - Role de Kubernetes Auth
- `vault.hashicorp.com/auth-path: "auth/kubernetes-cluster-b"` - Auth path

### Anotaciones para Configuración de Vault

- `vault.hashicorp.com/agent-extra-env`: Variables de entorno adicionales para el vault-agent
  - **Importante**: Si Vault está en otro cluster o es externo, especificar `VAULT_ADDR` aquí:
  ```yaml
  vault.hashicorp.com/agent-extra-env: |
    VAULT_ADDR=https://tu-vault-address.com
  ```
  - **Nota**: El vault-injector también puede configurar esto globalmente. Ver `CLUSTER-SETUP.md` en `vault-k8s-auth-consumers` para más detalles.

- `vault.hashicorp.com/tls-skip-verify: "true"` - Deshabilitar verificación TLS (solo desarrollo/testing)

### Anotaciones para Secretos

- `vault.hashicorp.com/agent-inject-secret-<nombre>`: Path del secreto en Vault
- `vault.hashicorp.com/agent-inject-template-<nombre>`: Template para formatear el secreto

## Troubleshooting

Si los secretos no se inyectan correctamente:

1. **Ejecutar script de diagnóstico:**
   ```bash
   ./diagnose-vault-injection.sh vault-test app
   ```

2. **Problema común: Vault Agent usa dirección incorrecta (`vault.vault.svc:8200`)**
   
   Si ves errores como "Vault is sealed" o el vault-agent intenta conectarse a `vault.vault.svc:8200`
   en lugar de tu dirección externa, el problema es que el **vault-injector no tiene configurado
   `externalVaultAddr` correctamente**.
   
   **Solución:**
   ```bash
   # Verificar y corregir la configuración del vault-injector
   ./fix-vault-injector-address.sh "https://tu-vault-address.com"
   
   # O en PowerShell:
   .\fix-vault-injector-address.ps1 -VaultAddress "https://tu-vault-address.com"
   ```
   
   Después de actualizar, **debes recrear los pods**:
   ```bash
   kubectl delete pod -n app -l app=vault-test
   ```

3. **Verificar requisitos básicos:**
   - Vault injector está instalado y corriendo
   - Volumen compartido está definido en el pod
   - Anotaciones son correctas
   - ServiceAccount coincide con el role en Vault
   - **El vault-injector tiene `externalVaultAddr` configurado correctamente**

4. **Ver logs del vault-agent:**
   ```bash
   kubectl logs vault-test -n app -c vault-agent-init
   ```

Ver `TROUBLESHOOTING.md` para una guía completa de troubleshooting.
