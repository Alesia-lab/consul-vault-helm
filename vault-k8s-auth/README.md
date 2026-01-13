# Configuración de Vault

Este proyecto contiene la configuración principal de Vault para:
- Habilitar Kubernetes Auth para múltiples clusters consumidores
- Habilitar KV v2 Secrets Engine para almacenar secretos versionados

## Arquitectura

Este proyecto lee la configuración de los clusters consumidores desde el proyecto `vault-k8s-auth-consumers` usando `terraform_remote_state` con backend local, o alternativamente puede recibir valores manualmente desde terminal/variables de entorno.

### Componentes Configurados

1. **KV v2 Secrets Engine**: Habilita el engine de secretos versionados (por defecto en path `secret`)
2. **Kubernetes Auth Backends**: Habilita y configura auth mounts para cada cluster consumidor
3. **Roles de Autenticación**: Crea roles que mapean ServiceAccounts/Namespaces a Policies

## Flujo de Trabajo

### Opción 1: Usar Remote State (Recomendado)

1. **Configurar clusters consumidores** (en proyecto separado):
   ```bash
   # Para cada cluster (cluster-b, cluster-c, etc.)
   cd ../../vault-k8s-auth-consumers/cluster-b
   
   # Configurar credenciales AWS para la cuenta del cluster
   export AWS_PROFILE=cluster-b-profile
   
   # Configurar kubeconfig
   kubectl config use-context cluster-b-context
   
   # Aplicar configuración
   terraform init
   terraform apply
   ```

2. **Configurar Vault** (este proyecto):
   ```bash
   cd vault-k8s-auth
   
   # Configurar terraform.tfvars
   cp terraform.tfvars.example terraform.tfvars
   # Editar y establecer:
   # - consumers_project_path = "/ruta/absoluta/a/vault-k8s-auth-consumers"
   # - clusters = { "cluster-b" = { ... }, "cluster-c" = { ... } }
   
   # Aplicar configuración
   terraform init
   terraform plan
   terraform apply
   ```

### Opción 2: Proporcionar Valores Manualmente

Si no puedes usar remote state para un cluster específico, puedes proporcionar valores manualmente en la configuración del cluster:

```hcl
# En terraform.tfvars
clusters = {
  "cluster-d" = {
    use_remote_state = false
    
    config = {
      token_reviewer_jwt = "eyJhbGciOiJSUzI1NiIsImtpZCI6Ii4uLiJ9..."
      kubernetes_host    = "https://api.cluster-d.example.com"
      kubernetes_ca_cert = <<-EOT
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
      EOT
    }
    
    roles = { ... }
  }
}
```

## Variables Importantes

### Configuración de Vault
- `vault_address`: Endpoint de Vault
- `vault_token`: Token de autenticación (o usar métodos más seguros)
- `vault_skip_tls_verify`: Deshabilitar verificación TLS (solo desarrollo/testing)

### KV v2 Secrets Engine
- `enable_kv_v2`: Habilitar KV v2 engine (default: `true`)
- `kv_v2_path`: Path donde se habilita (default: `"secret"`)
- `kv_v2_description`: Descripción del engine

### Vault Policies (Paths de Acceso)
- `vault_policies`: Mapa de políticas que definen qué paths pueden acceder los roles
  - Cada política define paths (ej: `secret/data/app/*`) y capacidades (read, write, etc.)
  - Ver `POLICIES-AND-ROLES.md` para más detalles

### Clusters Consumidores (Configuración Dinámica)
- `consumers_project_path`: Ruta absoluta al proyecto de clusters consumidores
- `clusters`: Mapa de clusters a configurar. Cada entrada define:
  - `use_remote_state`: Si usar remote state (true) o configuración manual (false)
  - `config`: Configuración manual (solo si `use_remote_state = false`):
    - `token_reviewer_jwt`: JWT token del ServiceAccount
    - `kubernetes_host`: Host del API server de Kubernetes
    - `kubernetes_ca_cert`: Certificado CA del cluster
  - `roles`: Roles específicos para este cluster que mapean ServiceAccounts/Namespaces → Policies
    - `bound_service_account_names`: ServiceAccounts que pueden usar el rol
    - `bound_service_account_namespaces`: Namespaces permitidos
    - `token_policies`: Políticas aplicadas (deben existir en `vault_policies`)
    - `token_ttl`: TTL del token en segundos (ej: 3600 = 1 hora)
    - `token_max_ttl`: TTL máximo del token en segundos (ej: 14400 = 4 horas)
  - `auth_path`: Path del auth mount (opcional, por defecto: `kubernetes-{cluster_name}`)
  - `disable_iss_validation`: Deshabilitar validación del issuer (opcional, default: false)
  - `disable_local_ca_jwt`: Deshabilitar validación del CA local (opcional, default: false)

## Autenticación con Vault

Para producción, usar métodos de autenticación más seguros que un token estático:

### AppRole (Recomendado para CI/CD)

```hcl
provider "vault" {
  address = var.vault_address
  
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_approle_role_id
      secret_id = var.vault_approle_secret_id
    }
  }
}
```

### AWS Auth Method

```hcl
provider "vault" {
  address = var.vault_address
  
  auth_login_aws {
    role = "terraform-role"
  }
}
```

## Agregar Nuevo Cluster

Para agregar un nuevo cluster (ej: cluster-e), solo necesitas:

1. **En el proyecto de clusters consumidores**:
   ```bash
   cd ../../vault-k8s-auth-consumers
   cp -r cluster-b cluster-e
   cd cluster-e
   # Ajustar variables y aplicar
   terraform init
   terraform apply
   ```

2. **En este proyecto (Vault) - Solo editar terraform.tfvars**:
   ```hcl
   clusters = {
     # ... clusters existentes ...
     
     "cluster-e" = {
       use_remote_state = true
       roles = {
         "app-readonly" = {
           bound_service_account_names      = ["app-sa"]
           bound_service_account_namespaces = ["default", "app"]
           token_policies                   = ["app-readonly-policy"]
           token_ttl                        = 3600
           token_max_ttl                    = 14400
         }
       }
     }
   }
   ```

3. **Aplicar la configuración**:
   ```bash
   terraform plan
   terraform apply
   ```

¡Eso es todo! No necesitas modificar ningún archivo `.tf`. El sistema lee automáticamente el estado de `cluster-e` desde `vault-k8s-auth-consumers/cluster-e/terraform.tfstate` y crea la configuración necesaria en Vault.

## Troubleshooting

**Error: "Failed to read state"**
- Verificar que `consumers_project_path` apunta al directorio correcto
- Verificar que el estado existe en `{consumers_project_path}/{cluster-name}/terraform.tfstate`
- Verificar permisos de lectura del archivo de estado
- Verificar que el nombre del cluster en `clusters` coincide con el directorio en `vault-k8s-auth-consumers`

**Error: "cluster config is empty"**
- Si `use_remote_state = true`, verificar que el estado del cluster existe y tiene los outputs necesarios
- Si `use_remote_state = false`, proporcionar valores en `config` dentro de la entrada del cluster

**Error: "Policy not found"**
- Verificar que todas las políticas referenciadas en `token_policies` de los roles existen en `vault_policies`
- Verificar que los nombres de las políticas coinciden exactamente (case-sensitive)

## Testing y Ejemplos

Para probar la configuración en tu cluster-b, consulta:

- **`TESTING.md`**: Guía completa de testing con vault-injector
- **`examples/`**: Ejemplos listos para usar:
  - `test-pod.yaml`: Pod simple para testing rápido
  - `test-deployment.yaml`: Deployment más realista
  - `setup-test.sh`: Script para crear recursos en Kubernetes
  - `create-test-secrets.sh`: Script para crear secretos en Vault

### Uso Rápido

```bash
# 1. Crear secretos en Vault
cd examples
./create-test-secrets.sh

# 2. Configurar Kubernetes (namespace y ServiceAccount)
./setup-test.sh

# 3. Desplegar pod de prueba
kubectl apply -f test-pod.yaml

# 4. Verificar
kubectl logs vault-test -n app -c vault-agent
kubectl exec vault-test -n app -c test -- cat /vault/secrets/database
```

## Documentación Adicional

- `USAGE.md`: Guía detallada de uso
- `SECURITY-NOTES.md`: Notas de seguridad sobre TLS y certificados
- `POLICIES-AND-ROLES.md`: Guía de configuración de políticas y roles
