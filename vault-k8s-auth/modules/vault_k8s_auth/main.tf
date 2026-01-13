# Módulo: vault_k8s_auth
# Propósito: Configura un Kubernetes Auth Backend en Vault para un cluster consumidor
#
# Este módulo se ejecuta en el CONTEXTO de Vault y configura:
# - Auth mount Kubernetes
# - Configuración del auth mount (host, CA cert, JWT)
# - Roles que mapean ServiceAccounts/Namespaces a Policies

terraform {
  required_version = ">= 1.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.15.0"
    }
  }
}

# Habilita el Kubernetes Auth Method en Vault
# Path: auth/kubernetes-{cluster_identifier}
resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  path        = var.auth_path
  description = "Kubernetes auth backend for cluster ${var.cluster_identifier}"

  # No deshabilitar el mount si se elimina el recurso
  # Esto permite gestión manual del ciclo de vida si es necesario
  disable_remount = false
}

# Configura el auth backend con las credenciales del cluster consumidor
resource "vault_kubernetes_auth_backend_config" "cluster" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_ca_cert
  token_reviewer_jwt = var.token_reviewer_jwt

  # ⚠️ SEGURIDAD: No usar skip_tls_verify en producción
  # Solo habilitar para desarrollo/testing con certificados autofirmados
  disable_iss_validation = var.disable_iss_validation
  disable_local_ca_jwt   = var.disable_local_ca_jwt

  # Issuer del cluster (opcional, se valida automáticamente si no se proporciona)
  issuer = var.kubernetes_issuer

  depends_on = [vault_auth_backend.kubernetes]
}

# Crea roles en el auth backend
# Cada rol mapea ServiceAccounts/Namespaces a Policies de Vault
# ⚠️ NOTA: token_ttl y token_max_ttl deben ser números en segundos
# Usamos nonsensitive() para extraer las claves (nombres de roles) que no son sensibles
resource "vault_kubernetes_auth_backend_role" "roles" {
  for_each = toset(keys(nonsensitive(var.roles)))

  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = each.key
  bound_service_account_names      = var.roles[each.key].bound_service_account_names
  bound_service_account_namespaces = var.roles[each.key].bound_service_account_namespaces
  token_ttl                        = var.roles[each.key].token_ttl
  token_max_ttl                    = var.roles[each.key].token_max_ttl
  token_policies                   = var.roles[each.key].token_policies
  token_bound_cidrs                = var.roles[each.key].token_bound_cidrs
  audience                         = var.roles[each.key].audience

  # Opciones adicionales de seguridad
  alias_name_source = var.roles[each.key].alias_name_source

  depends_on = [vault_kubernetes_auth_backend_config.cluster]
}
