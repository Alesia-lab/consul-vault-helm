output "auth_backend_path" {
  description = "Path del auth backend Kubernetes configurado"
  value       = vault_auth_backend.kubernetes.path
}

output "cluster_identifier" {
  description = "Identificador del cluster consumidor"
  value       = var.cluster_identifier
}

output "role_names" {
  description = "Nombres de los roles creados en el auth backend"
  value       = keys(vault_kubernetes_auth_backend_role.roles)
}

output "roles" {
  description = "Mapa de roles creados con sus configuraciones"
  value = {
    for role_name, role in vault_kubernetes_auth_backend_role.roles : role_name => {
      bound_service_account_names      = role.bound_service_account_names
      bound_service_account_namespaces = role.bound_service_account_namespaces
      token_policies                   = role.token_policies
      token_ttl                        = role.token_ttl
    }
  }
}
