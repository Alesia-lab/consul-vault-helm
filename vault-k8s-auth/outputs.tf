# Outputs de la configuración de Vault

# Outputs dinámicos por cluster
output "cluster_auth_paths" {
  description = "Mapa de paths de auth backend Kubernetes por cluster"
  value = {
    for cluster_name, module_instance in module.vault_k8s_auth : cluster_name => module_instance.auth_backend_path
  }
  sensitive = true
}

output "cluster_roles" {
  description = "Mapa de roles creados por cluster"
  value = {
    for cluster_name, module_instance in module.vault_k8s_auth : cluster_name => module_instance.role_names
  }
  sensitive = true
}

output "cluster_enabled" {
  description = "Mapa que indica qué clusters están configurados"
  value       = local.cluster_enabled
  sensitive   = true
}

output "all_auth_backends" {
  description = "Mapa completo de todos los auth backends configurados con sus detalles"
  value = {
    for cluster_name, module_instance in module.vault_k8s_auth : cluster_name => {
      path  = module_instance.auth_backend_path
      roles = module_instance.role_names
      cluster_identifier = module_instance.cluster_identifier
    }
  }
  sensitive = true
}

# ============================================================================
# Outputs para KV v2 Secrets Engine
# ============================================================================

output "kv_v2_path" {
  description = "Path del KV v2 secrets engine (si está habilitado)"
  value       = var.enable_kv_v2 ? vault_mount.kv_v2[0].path : null
}

output "kv_v2_enabled" {
  description = "Indica si el KV v2 secrets engine está habilitado"
  value       = var.enable_kv_v2
}

# ============================================================================
# Outputs para Vault Policies
# ============================================================================

output "vault_policy_names" {
  description = "Nombres de las políticas de Vault creadas"
  value       = module.vault_policies.policy_names
}
