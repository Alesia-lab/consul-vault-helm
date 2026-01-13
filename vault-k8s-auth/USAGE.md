# Guía de Uso - Proyecto Vault

Esta guía muestra cómo usar el proyecto de Vault con diferentes métodos de entrada de datos.

## Método 1: Remote State (Recomendado)

Este método lee automáticamente la configuración desde el estado local del proyecto de clusters consumidores.

### Paso 1: Configurar Clusters Consumidores

```bash
# Para cada cluster (cluster-b, cluster-c, etc.)
# En el proyecto de clusters consumidores
cd /home/edgar/ATT/vault-k8s-auth-consumers/cluster-b

# Configurar credenciales AWS para la cuenta del cluster
export AWS_PROFILE=cluster-b-profile

# Configurar kubeconfig
kubectl config use-context cluster-b-context

# Aplicar configuración
terraform init
terraform apply
```

### Paso 2: Configurar Vault

```bash
# En el proyecto de Vault
cd /home/edgar/ATT/vault-k8s-auth

# Configurar terraform.tfvars
cp terraform.tfvars.example terraform.tfvars

# Editar terraform.tfvars:
cat > terraform.tfvars <<EOF
vault_address = "https://vault.example.com:8200"
vault_token   = "hvs.xxxxx"  # O usar método más seguro

consumers_project_path = "/home/edgar/ATT/vault-k8s-auth-consumers"

vault_policies = {
  "app-readonly-policy" = {
    policy_content = <<-POLICY
      path "secret/data/app/*" {
        capabilities = ["read", "list"]
      }
    POLICY
  }
}

clusters = {
  "cluster-b" = {
    use_remote_state = true
    roles = {
      "app-readonly" = {
        bound_service_account_names      = ["app-sa"]
        bound_service_account_namespaces = ["default", "app"]
        token_policies                   = ["app-readonly-policy"]
        token_ttl                        = 3600    # En segundos
        token_max_ttl                    = 14400
      }
    }
  }
}
EOF

# Aplicar configuración
terraform init
terraform plan
terraform apply
```

## Método 2: Valores Manuales desde terraform.tfvars

Si prefieres proporcionar valores manualmente para un cluster específico:

```bash
cd /home/edgar/ATT/vault-k8s-auth

cat > terraform.tfvars <<EOF
vault_address = "https://vault.example.com:8200"
vault_token   = "hvs.xxxxx"

vault_policies = {
  "app-readonly-policy" = {
    policy_content = <<-POLICY
      path "secret/data/app/*" {
        capabilities = ["read", "list"]
      }
    POLICY
  }
}

clusters = {
  "cluster-b" = {
    use_remote_state = false
    
    config = {
      token_reviewer_jwt = "eyJhbGciOiJSUzI1NiIsImtpZCI6Ii4uLiJ9..."
      kubernetes_host    = "https://api.cluster-b.example.com"
      kubernetes_ca_cert = <<-EOT
        -----BEGIN CERTIFICATE-----
        MIIDXTCCAkWgAwIBAgIJAK...
        -----END CERTIFICATE-----
      EOT
    }
    
    roles = {
      "app-readonly" = {
        bound_service_account_names      = ["app-sa"]
        bound_service_account_namespaces = ["default", "app"]
        token_policies                   = ["app-readonly-policy"]
        token_ttl                        = 3600    # En segundos
        token_max_ttl                    = 14400
      }
    }
  }
}
EOF

terraform init
terraform apply
```

## Método 3: Variables de Entorno

```bash
export TF_VAR_vault_address="https://vault.example.com:8200"
export TF_VAR_vault_token="hvs.xxxxx"
export TF_VAR_consumers_project_path="/home/edgar/ATT/vault-k8s-auth-consumers"

# Para clusters, usar JSON (estructura compleja, mejor usar terraform.tfvars)
# Ejemplo simplificado:
export TF_VAR_clusters='{"cluster-b":{"use_remote_state":true,"roles":{"app-readonly":{"bound_service_account_names":["app-sa"],"bound_service_account_namespaces":["default","app"],"token_policies":["app-readonly-policy"],"token_ttl":3600,"token_max_ttl":14400}}}}'

terraform apply
```

**Nota**: Para configuraciones complejas con múltiples clusters, es más fácil usar `terraform.tfvars` en lugar de variables de entorno.

## Método 4: Desde Terminal al Vuelo

```bash
terraform apply \
  -var="vault_address=https://vault.example.com:8200" \
  -var="vault_token=hvs.xxxxx" \
  -var="consumers_project_path=/home/edgar/ATT/vault-k8s-auth-consumers" \
  -var='clusters={"cluster-b":{"use_remote_state":true,"roles":{"app-readonly":{"bound_service_account_names":["app-sa"],"bound_service_account_namespaces":["default","app"],"token_policies":["app-readonly-policy"],"token_ttl":3600,"token_max_ttl":14400}}}}'
```

**Nota**: Para configuraciones complejas, es más fácil usar `terraform.tfvars`.

## Obtener Valores del Cluster Consumidor

Si necesitas obtener los valores manualmente del proyecto de clusters:

```bash
# En el proyecto de clusters consumidores
cd /home/edgar/ATT/vault-k8s-auth-consumers/cluster-b

# Obtener outputs
terraform output token_reviewer_jwt
terraform output kubernetes_host
terraform output kubernetes_ca_cert

# O en formato JSON
terraform output -json
```

Luego puedes usar estos valores en el proyecto de Vault usando cualquiera de los métodos 2, 3 o 4.

## Verificar Configuración

```bash
# Verificar auth backend configurado para un cluster específico
vault read auth/kubernetes-cluster-b/config

# Listar roles creados en un cluster
vault list auth/kubernetes-cluster-b/role

# Ver detalles de un role
vault read auth/kubernetes-cluster-b/role/app-readonly

# Listar todos los auth backends configurados
vault auth list

# Verificar configuración de múltiples clusters
for cluster in cluster-b cluster-c; do
  echo "=== Cluster: $cluster ==="
  vault read auth/kubernetes-$cluster/config
  vault list auth/kubernetes-$cluster/role
done
```

## Agregar Nuevo Cluster

Para agregar un nuevo cluster (ej: cluster-e):

1. **Configurar el cluster en vault-k8s-auth-consumers** (ver paso 1 del Método 1)

2. **Agregar entrada en terraform.tfvars**:
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

3. **Aplicar configuración**:
```bash
terraform plan
terraform apply
```

¡Eso es todo! No necesitas modificar ningún archivo `.tf`.
