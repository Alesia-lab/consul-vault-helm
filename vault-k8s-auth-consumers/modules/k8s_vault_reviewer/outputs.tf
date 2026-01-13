# Outputs sensibles que se usarán para configurar el auth backend en Vault
# ⚠️ ADVERTENCIA: Estos valores son sensibles y no deben exponerse públicamente

output "service_account_name" {
  description = "Nombre del ServiceAccount creado"
  value       = kubernetes_service_account_v1.vault_reviewer.metadata[0].name
}

output "service_account_namespace" {
  description = "Namespace del ServiceAccount"
  value       = kubernetes_service_account_v1.vault_reviewer.metadata[0].namespace
}

output "token_reviewer_jwt" {
  description = "JWT token del ServiceAccount para usar en Vault auth backend. ⚠️ SENSIBLE"
  value       = try(data.kubernetes_secret_v1.vault_reviewer_jwt.data["token"], "")
  sensitive   = true
}

output "kubernetes_host" {
  description = "Host del API server de Kubernetes (ej: https://kubernetes.default.svc o https://api.eks.us-east-1.amazonaws.com)"
  value       = local.kubernetes_host
}

output "kubernetes_ca_cert" {
  description = "Certificado CA del cluster Kubernetes en formato PEM. ⚠️ SENSIBLE"
  value       = coalesce(
    var.kubernetes_ca_cert,
    try(base64decode(data.kubernetes_secret_v1.vault_reviewer_jwt.data["ca.crt"]), "")
  )
  sensitive = true
}

output "cluster_role_name" {
  description = "Nombre del ClusterRole creado"
  value       = kubernetes_cluster_role_v1.vault_reviewer.metadata[0].name
}

output "cluster_role_binding_name" {
  description = "Nombre del ClusterRoleBinding creado"
  value       = kubernetes_cluster_role_binding_v1.vault_reviewer.metadata[0].name
}
