# Política para grupo Admin - Acceso completo (100% de funciones)
# Este grupo tiene acceso total a todas las funcionalidades de Vault

# Acceso completo al sistema
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión completa de políticas
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión completa de roles de autenticación
path "auth/*/role/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión completa de métodos de autenticación
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión completa de secret engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión completa de audit devices
path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Configuración del sistema
path "sys/config" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión completa de leases
path "sys/leases/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Operaciones de sistema
path "sys/health" {
  capabilities = ["read", "sudo"]
}

path "sys/seal-status" {
  capabilities = ["read", "sudo"]
}

path "sys/seal" {
  capabilities = ["update", "sudo"]
}

path "sys/unseal" {
  capabilities = ["update", "sudo"]
}

# Gestión completa de identidades
path "identity/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión completa de secretos (todos los tipos)
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión completa de PKI
path "pki/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión completa de transit
path "transit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Response Wrapping
path "sys/wrapping/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Cubbyhole temporal
path "cubbyhole/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
