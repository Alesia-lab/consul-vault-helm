# Política para grupo Operation
# Gestión total y absoluta para secretos de múltiples tipos, principalmente KV v2

# Gestión completa de secretos KV v2
path "secret/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/delete/*" {
  capabilities = ["update"]
}

path "secret/destroy/*" {
  capabilities = ["update"]
}

path "secret/undelete/*" {
  capabilities = ["update"]
}

# Gestión completa de secretos KV v1 (si existen)
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Gestión de versiones de secretos KV v2
path "secret/versions/*" {
  capabilities = ["read", "list"]
}

# Rotación de secretos
path "sys/rotate/*" {
  capabilities = ["update"]
}

# Gestión de leases de secretos
path "sys/leases/lookup/*" {
  capabilities = ["update"]
}

path "sys/leases/renew/*" {
  capabilities = ["update"]
}

path "sys/leases/revoke/*" {
  capabilities = ["update"]
}

# Response Wrapping
path "sys/wrapping/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Cubbyhole temporal
path "cubbyhole/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Lectura de información básica del sistema
path "sys/health" {
  capabilities = ["read"]
}
