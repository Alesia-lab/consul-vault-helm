# Configuración del Cluster Consumidor B
# Este módulo crea el ServiceAccount y permisos necesarios en el cluster consumidor
# para que Vault pueda realizar token reviews

module "k8s_reviewer" {
  source = "../modules/k8s_vault_reviewer"

  cluster_name         = var.cluster_name
  namespace            = var.namespace
  service_account_name = var.service_account_name
  service_account_annotations = var.service_account_annotations

  # Pasar valores explícitos obtenidos de EKS
  kubernetes_host = data.aws_eks_cluster.cluster.endpoint
  kubernetes_ca_cert = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
}

# ============================================================================
# Vault Agent Injector
# ============================================================================

# Instalar el Vault Agent Injector en el cluster
# El injector permite inyectar automáticamente el sidecar vault-agent en los pods
module "vault_injector" {
  count = var.install_vault_injector ? 1 : 0

  source = "../modules/vault_injector"

  vault_address         = var.vault_address
  vault_skip_tls_verify = var.vault_skip_tls_verify
  namespace             = var.vault_injector_namespace
  create_namespace      = var.vault_injector_create_namespace
  release_name          = var.vault_injector_release_name
  chart_version         = var.vault_injector_chart_version
  vault_agent_image     = var.vault_agent_image
  helm_timeout          = var.helm_timeout
}
