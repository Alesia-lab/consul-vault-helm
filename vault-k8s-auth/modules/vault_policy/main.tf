# Módulo: vault_policy
# Propósito: Crea políticas de Vault que definen qué paths pueden acceder los roles
#
# Este módulo crea políticas de Vault en formato HCL que definen los permisos
# de acceso a paths específicos del KV v2 engine u otros secrets engines.

terraform {
  required_version = ">= 1.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.15.0"
    }
  }
}

# Crea políticas de Vault
# Cada política define qué paths pueden acceder y con qué capacidades
resource "vault_policy" "policies" {
  for_each = var.policies

  name   = each.key
  policy = each.value.policy_content
}
