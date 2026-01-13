# Guía de Migración - Estructura Dinámica de Clusters

Esta guía explica cómo migrar de la estructura antigua (hardcodeada para cluster-b) a la nueva estructura dinámica que soporta múltiples clusters.

## Cambios Principales

### Antes (Estructura Antigua)

La configuración estaba hardcodeada para un solo cluster (`cluster-b`):

```hcl
# variables.tf tenía:
variable "use_remote_state_cluster_b" { ... }
variable "cluster_b_config" { ... }
variable "cluster_b_roles" { ... }

# main.tf tenía:
data "terraform_remote_state" "cluster_b" { ... }
module "vault_k8s_auth_cluster_b" { ... }
```

### Después (Estructura Nueva)

La configuración ahora es dinámica y soporta múltiples clusters:

```hcl
# variables.tf tiene:
variable "clusters" {
  type = map(object({
    use_remote_state = bool
    config = optional(object({ ... }), null)
    roles = map(object({ ... }))
    # ...
  }))
}

# main.tf tiene:
data "terraform_remote_state" "clusters" {
  for_each = { ... }
}
module "vault_k8s_auth" {
  for_each = { ... }
}
```

## Pasos de Migración

### Paso 1: Hacer Backup

```bash
cd /home/edgar/ATT/vault-k8s-auth
cp terraform.tfvars terraform.tfvars.backup
cp terraform.tfstate terraform.tfstate.backup
```

### Paso 2: Actualizar terraform.tfvars

**Antes:**
```hcl
use_remote_state_cluster_b = true
consumers_project_path     = "/home/edgar/ATT/vault-k8s-auth-consumers"

cluster_b_roles = {
  "app-readonly" = {
    bound_service_account_names      = ["app-sa"]
    bound_service_account_namespaces = ["default", "app"]
    token_policies                   = ["app-readonly-policy"]
    token_ttl                        = 3600
    token_max_ttl                    = 14400
  }
}
```

**Después:**
```hcl
consumers_project_path = "/home/edgar/ATT/vault-k8s-auth-consumers"

clusters = {
  "cluster-b" = {
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

### Paso 3: Verificar que el Estado del Cluster Existe

```bash
# Verificar que el estado del cluster-b existe
ls -la /home/edgar/ATT/vault-k8s-auth-consumers/cluster-b/terraform.tfstate

# Verificar que tiene los outputs necesarios
cd /home/edgar/ATT/vault-k8s-auth-consumers/cluster-b
terraform output
```

### Paso 4: Inicializar Terraform

```bash
cd /home/edgar/ATT/vault-k8s-auth
terraform init -upgrade
```

### Paso 5: Verificar el Plan

```bash
terraform plan
```

Deberías ver que:
- Se eliminan los recursos antiguos (si existen)
- Se crean los nuevos recursos con la estructura dinámica
- Los recursos de Vault (auth backends, roles) se recrean con los mismos nombres

**Nota**: Si los recursos de Vault ya existen, Terraform debería detectarlos y no intentar recrearlos, solo actualizar la referencia en el estado.

### Paso 6: Aplicar la Migración

```bash
terraform apply
```

## Migración de Configuración Manual

Si estabas usando configuración manual (sin remote state):

**Antes:**
```hcl
use_remote_state_cluster_b = false

cluster_b_config = {
  token_reviewer_jwt = "eyJ..."
  kubernetes_host    = "https://api.cluster-b.example.com"
  kubernetes_ca_cert = <<-EOT
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  EOT
}

cluster_b_roles = { ... }
```

**Después:**
```hcl
clusters = {
  "cluster-b" = {
    use_remote_state = false
    
    config = {
      token_reviewer_jwt = "eyJ..."
      kubernetes_host    = "https://api.cluster-b.example.com"
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

## Agregar Nuevos Clusters

Después de la migración, agregar nuevos clusters es muy simple:

1. **Configurar el cluster en vault-k8s-auth-consumers**:
```bash
cd /home/edgar/ATT/vault-k8s-auth-consumers
cp -r cluster-b cluster-c
cd cluster-c
# Editar variables y aplicar
terraform init
terraform apply
```

2. **Agregar entrada en terraform.tfvars**:
```hcl
clusters = {
  "cluster-b" = { ... }  # Existente
  
  "cluster-c" = {        # Nuevo
    use_remote_state = true
    roles = {
      "app-readonly" = {
        bound_service_account_names      = ["app-sa"]
        bound_service_account_namespaces = ["app", "production"]
        token_policies                   = ["app-readonly-policy"]
        token_ttl                        = 3600
        token_max_ttl                    = 14400
      }
    }
  }
}
```

3. **Aplicar**:
```bash
terraform plan
terraform apply
```

## Verificación Post-Migración

Después de la migración, verifica que todo funciona:

```bash
# Verificar que los auth backends existen
vault auth list

# Verificar configuración de cada cluster
vault read auth/kubernetes-cluster-b/config

# Verificar roles
vault list auth/kubernetes-cluster-b/role
vault read auth/kubernetes-cluster-b/role/app-readonly

# Verificar outputs de Terraform
terraform output
```

## Rollback (Si es Necesario)

Si necesitas volver a la estructura antigua:

1. **Restaurar archivos de backup**:
```bash
cd /home/edgar/ATT/vault-k8s-auth
cp terraform.tfvars.backup terraform.tfvars
cp terraform.tfstate.backup terraform.tfstate
```

2. **Usar la versión anterior del código**:
```bash
git checkout <commit-anterior>
# O restaurar desde backup si no usas git
```

**Nota**: Los recursos de Vault no se eliminan al hacer rollback, solo cambia cómo Terraform los gestiona.

## Preguntas Frecuentes

### ¿Se perderán los recursos de Vault durante la migración?

No. Los recursos de Vault (auth backends, roles, políticas) ya existen y Terraform los detectará. Solo cambiará cómo están referenciados en el estado de Terraform.

### ¿Puedo migrar gradualmente?

Sí. Puedes mantener la estructura antigua para cluster-b y usar la nueva estructura para nuevos clusters. Sin embargo, es recomendable migrar todo a la vez para mantener consistencia.

### ¿Qué pasa con los outputs?

Los outputs han cambiado de nombres específicos (`cluster_b_auth_path`) a nombres dinámicos (`cluster_auth_paths["cluster-b"]`). Actualiza cualquier script o automatización que use estos outputs.

### ¿Puedo usar ambos métodos (remote state y manual) para diferentes clusters?

Sí. Cada cluster puede usar `use_remote_state = true` o `use_remote_state = false` independientemente.

## Soporte

Si encuentras problemas durante la migración:

1. Revisa los logs de Terraform: `terraform plan -detailed-exitcode`
2. Verifica que los estados de los clusters existen y tienen los outputs correctos
3. Consulta `TROUBLESHOOTING.md` en el proyecto `vault-k8s-auth-consumers`
4. Verifica la documentación en `README.md` y `USAGE.md`
