# Módulo: vault_policy

Este módulo crea políticas de Vault que definen qué paths pueden acceder los roles de Kubernetes Auth.

## Recursos Creados

- `vault_policy`: Políticas de Vault en formato HCL

## Uso

```hcl
module "vault_policies" {
  source = "./modules/vault_policy"

  policies = {
    "app-readonly-policy" = {
      policy_content = <<-POLICY
        # Acceso de solo lectura a secretos de la aplicación
        path "secret/data/app/*" {
          capabilities = ["read", "list"]
        }
        
        # Acceso a metadatos (para versionado)
        path "secret/metadata/app/*" {
          capabilities = ["read", "list"]
        }
      POLICY
    }
    
    "app-readwrite-policy" = {
      policy_content = <<-POLICY
        # Acceso completo a secretos de la aplicación
        path "secret/data/app/*" {
          capabilities = ["create", "read", "update", "delete", "list"]
        }
        
        path "secret/metadata/app/*" {
          capabilities = ["read", "list", "delete"]
        }
      POLICY
    }
  }
}
```

## Formato de Políticas

Las políticas usan formato HCL de Vault. Para KV v2, los paths son:
- `secret/data/*` - Para leer/escribir datos
- `secret/metadata/*` - Para leer/escribir metadatos (versionado)

Capacidades disponibles:
- `read` - Leer datos
- `list` - Listar paths
- `create` - Crear nuevos secretos
- `update` - Actualizar secretos existentes
- `delete` - Eliminar secretos
