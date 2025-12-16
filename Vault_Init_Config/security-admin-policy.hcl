# Política para grupo Security Admin
# Responsable de administrar mecanismos de autenticación, tiempo de vida de tokens y tareas relacionadas

# Gestión de métodos de autenticación
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión de roles de autenticación
path "auth/*/role/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Configuración de TTL y Max TTL para métodos de autenticación
path "auth/*/config" {
  capabilities = ["read", "update", "sudo"]
}

# Gestión de tokens
path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión de políticas de autenticación
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Gestión de leases y renovación
path "sys/leases/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Lectura de configuración del sistema
path "sys/config" {
  capabilities = ["read", "update", "sudo"]
}

# Gestión de audit devices
path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Lectura de logs de auditoría
path "sys/audit-hash/*" {
  capabilities = ["read", "sudo"]
}

# Gestión de identidades y grupos
path "identity/group/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "identity/entity/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "identity/entity-alias/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Lectura de información del sistema
path "sys/health" {
  capabilities = ["read"]
}

path "sys/seal-status" {
  capabilities = ["read"]
}

# Response Wrapping
path "sys/wrapping/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Cubbyhole temporal
path "cubbyhole/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Lectura de secretos de seguridad (solo lectura)
path "secret/security/*" {
  capabilities = ["read", "list"]
}
