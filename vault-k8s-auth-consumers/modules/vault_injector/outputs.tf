output "release_name" {
  description = "Nombre del release de Helm"
  value       = helm_release.vault_injector.name
}

output "namespace" {
  description = "Namespace donde se instaló el injector"
  value       = helm_release.vault_injector.namespace
}

output "chart_version" {
  description = "Versión del chart instalado"
  value       = helm_release.vault_injector.version
}

output "status" {
  description = "Estado del release de Helm"
  value       = helm_release.vault_injector.status
}
