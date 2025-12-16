# Política para grupo Developer
# Solo puede ver y listar secretos de KV v2 sin la posibilidad de leer los mismos

# Solo listar secretos KV v2 (sin leer)
path "secret/data/*" {
  capabilities = ["list"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}

# Listar paths de secretos
path "secret/*" {
  capabilities = ["list"]
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
