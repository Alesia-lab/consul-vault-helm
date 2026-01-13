# Configuración de Políticas y Roles - Guía de Paths de Acceso

Esta guía explica **dónde y cómo** se configuran los paths a los que cada ServiceAccount, Namespace y role tiene acceso en Vault.

## Flujo de Configuración

```
┌─────────────────────────────────────────────────────────────┐
│  1. Políticas (vault_policies)                              │
│     Define QUÉ paths pueden acceder y con QUÉ capacidades   │
│                                                             │
│  Ejemplo:                                                   │
│  "app-readonly-policy" → path "secret/data/app/*"           │
│                          capabilities = ["read", "list"]    │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Referenciada por
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Roles (cluster_b_roles)                                 │
│     Mapea ServiceAccounts/Namespaces → Policies             │
│                                                             │
│  Ejemplo:                                                   │
│  "app-readonly" →                                           │
│    - ServiceAccounts: ["app-sa", "readonly-sa"]             │
│    - Namespaces: ["default", "app"]                         │
│    - Policies: ["app-readonly-policy"]                      │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Resultado
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Pod con ServiceAccount "app-sa" en namespace "app"         │
│  → Puede acceder a "secret/data/app/*" con read/list        │
└─────────────────────────────────────────────────────────────┘
```

## Dónde se Configura

### 1. Políticas de Vault (Paths y Capacidades)

**Ubicación**: `terraform.tfvars` → variable `vault_policies`

**Qué define**: Los paths específicos y las capacidades (read, write, delete, etc.)

**Ejemplo**:
```hcl
vault_policies = {
  "app-readonly-policy" = {
    policy_content = <<-POLICY
      # Acceso de solo lectura a secretos de la aplicación
      path "secret/data/app/*" {
        capabilities = ["read", "list"]
      }
      
      # Acceso a metadatos para versionado
      path "secret/metadata/app/*" {
        capabilities = ["read", "list"]
      }
    POLICY
  }
}
```

### 2. Roles de Kubernetes Auth (ServiceAccounts y Namespaces)

**Ubicación**: `terraform.tfvars` → variable `cluster_b_roles`

**Qué define**: 
- Qué ServiceAccounts pueden usar el rol
- En qué Namespaces
- Qué políticas se aplican (referencia a `vault_policies`)

**Ejemplo**:
```hcl
cluster_b_roles = {
  "app-readonly" = {
    bound_service_account_names      = ["app-sa", "readonly-sa"]
    bound_service_account_namespaces = ["default", "app"]
    token_policies                   = ["app-readonly-policy"]  # ← Referencia a la política
    token_ttl                        = 3600
    token_max_ttl                    = 14400
  }
}
```

## Estructura Completa

### Paso 1: Definir Políticas (Paths de Acceso)

En `terraform.tfvars`:

```hcl
vault_policies = {
  "app-readonly-policy" = {
    policy_content = <<-POLICY
      # Solo lectura en secretos de app
      path "secret/data/app/*" {
        capabilities = ["read", "list"]
      }
      path "secret/metadata/app/*" {
        capabilities = ["read", "list"]
      }
    POLICY
  }
  
  "app-readwrite-policy" = {
    policy_content = <<-POLICY
      # Acceso completo en secretos de app
      path "secret/data/app/*" {
        capabilities = ["create", "read", "update", "delete", "list"]
      }
      path "secret/metadata/app/*" {
        capabilities = ["read", "list", "delete"]
      }
    POLICY
  }
}
```

### Paso 2: Crear Roles que Referencian las Políticas

En `terraform.tfvars`:

```hcl
cluster_b_roles = {
  "app-readonly" = {
    # ServiceAccounts que pueden usar este rol
    bound_service_account_names = ["app-sa", "readonly-sa"]
    
    # Namespaces donde estos ServiceAccounts pueden usar el rol
    bound_service_account_namespaces = ["default", "app"]
    
    # Políticas que se aplican (deben existir en vault_policies)
    token_policies = ["app-readonly-policy"]
    
    token_ttl      = 3600
    token_max_ttl = 14400
  }
  
  "app-readwrite" = {
    bound_service_account_names      = ["app-sa"]
    bound_service_account_namespaces  = ["app"]
    token_policies                    = ["app-readwrite-policy"]
    token_ttl                         = 1800
    token_max_ttl                     = 7200
  }
}
```

## Paths para KV v2

Para KV v2, los paths tienen un formato específico:

- **Datos**: `secret/data/path/to/secret`
- **Metadatos**: `secret/metadata/path/to/secret`

### Ejemplos de Paths

```hcl
# Acceso a todos los secretos bajo "app"
path "secret/data/app/*" {
  capabilities = ["read", "list"]
}

# Acceso a un secreto específico
path "secret/data/app/database" {
  capabilities = ["read"]
}

# Acceso a todos los secretos (cuidado con esto)
path "secret/data/*" {
  capabilities = ["read", "list"]
}

# Acceso a metadatos (para versionado)
path "secret/metadata/app/*" {
  capabilities = ["read", "list"]
}
```

## Capacidades Disponibles

- `read`: Leer el valor de un secreto
- `list`: Listar paths (ver qué secretos existen)
- `create`: Crear nuevos secretos
- `update`: Actualizar secretos existentes
- `delete`: Eliminar secretos
- `patch`: Modificar parcialmente (solo algunos campos)

## Resumen: Dónde Configurar

| Configuración | Ubicación | Qué Define |
|--------------|-----------|------------|
| **Paths de acceso** | `terraform.tfvars` → `vault_policies` | Qué paths y capacidades |
| **ServiceAccounts** | `terraform.tfvars` → `cluster_b_roles[].bound_service_account_names` | Qué ServiceAccounts pueden usar el rol |
| **Namespaces** | `terraform.tfvars` → `cluster_b_roles[].bound_service_account_namespaces` | En qué namespaces |
| **Mapeo SA/NS → Policies** | `terraform.tfvars` → `cluster_b_roles[].token_policies` | Qué políticas se aplican |

## Ejemplo Completo

```hcl
# 1. Definir políticas (paths de acceso)
vault_policies = {
  "app-readonly-policy" = {
    policy_content = <<-POLICY
      path "secret/data/app/*" {
        capabilities = ["read", "list"]
      }
    POLICY
  }
}

# 2. Crear rol que mapea ServiceAccount/Namespace → Policy
cluster_b_roles = {
  "app-readonly" = {
    bound_service_account_names      = ["app-sa"]           # ← ServiceAccount
    bound_service_account_namespaces = ["app"]             # ← Namespace
    token_policies                   = ["app-readonly-policy"]  # ← Policy (paths)
    token_ttl                        = 3600
    token_max_ttl                    = 14400
  }
}
```

**Resultado**: Un pod con ServiceAccount `app-sa` en namespace `app` puede acceder a `secret/data/app/*` con capacidades `read` y `list`.
