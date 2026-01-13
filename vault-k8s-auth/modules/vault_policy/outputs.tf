output "policy_names" {
  description = "Nombres de las políticas creadas"
  value       = keys(vault_policy.policies)
}

output "policies" {
  description = "Mapa de políticas creadas con sus nombres"
  value = {
    for name, policy in vault_policy.policies : name => {
      name = policy.name
    }
  }
}
