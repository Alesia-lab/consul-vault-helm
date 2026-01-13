# Configuración Principal de Vault
# Este archivo configura los Kubernetes Auth Backends para múltiples clusters consumidores
#
# Flujo de trabajo:
# 1. Primero, ejecutar terraform en el proyecto vault-k8s-auth-consumers/{cluster-name}
# 2. Este proyecto lee el estado local de esos proyectos usando terraform_remote_state
#    O alternativamente, puedes proporcionar valores manualmente desde terminal
# 3. Ejecutar terraform apply para configurar Vault

# ============================================================================
# Locals: Extraer información no sensible para for_each
# ============================================================================

locals {
  # Extraer solo los nombres de clusters que usan remote state (no sensibles)
  # Usamos nonsensitive() porque las claves del mapa no son sensibles, solo los valores
  clusters_using_remote_state = toset([
    for cluster_name, cluster_config in nonsensitive(var.clusters) : cluster_name
    if cluster_config.use_remote_state && var.consumers_project_path != ""
  ])
  
  # Extraer solo los nombres de clusters habilitados (no sensibles)
  # Un cluster está habilitado si:
  # - Usa remote state Y consumers_project_path está configurado, O
  # - No usa remote state Y tiene config manual
  enabled_cluster_names = toset([
    for cluster_name, cluster_config in nonsensitive(var.clusters) : cluster_name
    if (cluster_config.use_remote_state && var.consumers_project_path != "") || 
       (!cluster_config.use_remote_state && cluster_config.config != null)
  ])
}

# ============================================================================
# Data Sources: Leer estados de los proyectos de clusters consumidores
# ============================================================================

# Leer estados locales de todos los clusters configurados dinámicamente
# Usamos solo las claves (nombres) que no son sensibles
data "terraform_remote_state" "clusters" {
  for_each = local.clusters_using_remote_state
  
  backend = "local"

  config = {
    path = "${var.consumers_project_path}/${each.key}/terraform.tfstate"
  }
}

# ============================================================================
# Locals: Determinar configuración a usar (remote state o valores manuales)
# ============================================================================

locals {
  # Configuración de cada cluster: usar remote state si está habilitado, sino usar valores manuales
  cluster_configs = {
    for cluster_name, cluster_config in var.clusters : cluster_name => {
      token_reviewer_jwt = cluster_config.use_remote_state && var.consumers_project_path != "" ? (
        try(data.terraform_remote_state.clusters[cluster_name].outputs.token_reviewer_jwt, "")
      ) : (
        try(cluster_config.config != null ? cluster_config.config.token_reviewer_jwt : "", "")
      )
      kubernetes_host = cluster_config.use_remote_state && var.consumers_project_path != "" ? (
        try(data.terraform_remote_state.clusters[cluster_name].outputs.kubernetes_host, "")
      ) : (
        try(cluster_config.config != null ? cluster_config.config.kubernetes_host : "", "")
      )
      kubernetes_ca_cert = cluster_config.use_remote_state && var.consumers_project_path != "" ? (
        try(data.terraform_remote_state.clusters[cluster_name].outputs.kubernetes_ca_cert, "")
      ) : (
        try(cluster_config.config != null ? cluster_config.config.kubernetes_ca_cert : "", "")
      )
    }
  }

  # Flags para determinar si cada cluster está configurado
  # Si usa remote state, verificar que existe. Si no, verificar que los valores no están vacíos
  # Nota: Usamos try() para manejar casos donde el data source no existe
  cluster_enabled = {
    for cluster_name in local.enabled_cluster_names : cluster_name => (
      contains(local.clusters_using_remote_state, cluster_name) ? (
        # Verificar que el data source existe y tiene outputs válidos
        try(
          length(data.terraform_remote_state.clusters[cluster_name].outputs.token_reviewer_jwt) > 0 &&
          length(data.terraform_remote_state.clusters[cluster_name].outputs.kubernetes_host) > 0 &&
          length(data.terraform_remote_state.clusters[cluster_name].outputs.kubernetes_ca_cert) > 0,
          false
        )
      ) : (
        # Verificar que la configuración manual tiene todos los valores necesarios
        try(
          var.clusters[cluster_name].config != null &&
          length(var.clusters[cluster_name].config.token_reviewer_jwt) > 0 &&
          length(var.clusters[cluster_name].config.kubernetes_host) > 0 &&
          length(var.clusters[cluster_name].config.kubernetes_ca_cert) > 0,
          false
        )
      )
    )
  }

  # Determinar auth_path para cada cluster (por defecto: "kubernetes-{cluster_name}")
  cluster_auth_paths = {
    for cluster_name, cluster_config in var.clusters : cluster_name => (
      cluster_config.auth_path != "" ? cluster_config.auth_path : "kubernetes-${cluster_name}"
    )
  }
}

# ============================================================================
# KV v2 Secrets Engine
# ============================================================================

# Habilita el KV v2 secrets engine en Vault
# Este engine permite almacenar secretos versionados
resource "vault_mount" "kv_v2" {
  count = var.enable_kv_v2 ? 1 : 0

  path        = var.kv_v2_path
  type        = "kv"
  description = var.kv_v2_description

  # Versión 2 del KV engine (soporta versionado de secretos)
  options = {
    version = "2"
  }
}

# ============================================================================
# Vault Policies
# ============================================================================

# Crea las políticas de Vault que definen qué paths pueden acceder los roles
# Estas políticas se referencian en los roles de Kubernetes Auth
module "vault_policies" {
  source = "./modules/vault_policy"

  policies = var.vault_policies
}

# ============================================================================
# Kubernetes Auth Backends para todos los clusters configurados
# ============================================================================

module "vault_k8s_auth" {
  source = "./modules/vault_k8s_auth"
  # Usar solo las claves (nombres) que no son sensibles
  for_each = toset([
    for cluster_name in local.enabled_cluster_names : cluster_name
    if local.cluster_enabled[cluster_name]
  ])

  cluster_identifier = each.key
  auth_path          = local.cluster_auth_paths[each.key]

  kubernetes_host    = local.cluster_configs[each.key].kubernetes_host
  kubernetes_ca_cert = local.cluster_configs[each.key].kubernetes_ca_cert
  token_reviewer_jwt = local.cluster_configs[each.key].token_reviewer_jwt

  # ⚠️ SEGURIDAD: No deshabilitar validaciones en producción
  # Acceder a los valores sensibles directamente desde var.clusters
  disable_iss_validation = var.clusters[each.key].disable_iss_validation
  disable_local_ca_jwt   = var.clusters[each.key].disable_local_ca_jwt

  roles = var.clusters[each.key].roles
}
