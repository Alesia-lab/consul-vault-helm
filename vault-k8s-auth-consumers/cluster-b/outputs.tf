# Outputs del Cluster B
# Estos valores se usarán como inputs en la configuración de Vault
# ⚠️ ADVERTENCIA: Contienen material sensible (JWT tokens, certificados)
#
# El proyecto de Vault leerá estos outputs usando terraform_remote_state
# con backend "local" apuntando a este directorio

output "cluster_name" {
  description = "Nombre del cluster"
  value       = var.cluster_name
}

output "token_reviewer_jwt" {
  description = "JWT token del ServiceAccount para usar en Vault auth backend. ⚠️ SENSIBLE"
  value       = module.k8s_reviewer.token_reviewer_jwt
  sensitive   = true
}

output "kubernetes_host" {
  description = "Host del API server de Kubernetes"
  value       = module.k8s_reviewer.kubernetes_host
}

output "kubernetes_ca_cert" {
  description = "Certificado CA del cluster Kubernetes en formato PEM. ⚠️ SENSIBLE"
  value       = module.k8s_reviewer.kubernetes_ca_cert
  sensitive   = true
}

output "service_account_name" {
  description = "Nombre del ServiceAccount creado"
  value       = module.k8s_reviewer.service_account_name
}

output "service_account_namespace" {
  description = "Namespace del ServiceAccount"
  value       = module.k8s_reviewer.service_account_namespace
}

# ============================================================================
# Outputs del Vault Injector
# ============================================================================

output "vault_injector_release_name" {
  description = "Nombre del release de Helm del vault-injector"
  value       = var.install_vault_injector ? module.vault_injector[0].release_name : null
}

output "vault_injector_namespace" {
  description = "Namespace donde se instaló el vault-injector"
  value       = var.install_vault_injector ? module.vault_injector[0].namespace : null
}

output "vault_injector_status" {
  description = "Estado del release de Helm del vault-injector"
  value       = var.install_vault_injector ? module.vault_injector[0].status : null
}

output "vault_injector_chart_version" {
  description = "Versión del chart de Helm instalado"
  value       = var.install_vault_injector ? module.vault_injector[0].chart_version : null
}
