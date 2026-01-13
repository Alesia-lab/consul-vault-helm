# Módulo: vault_injector
# Propósito: Instala el Vault Agent Injector en el cluster usando Helm
# Este módulo instala solo el injector (no el servidor de Vault)

terraform {
  required_version = ">= 1.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

# Nota: En versiones recientes del provider de Helm, se puede usar el repositorio directamente
# sin necesidad de agregarlo como resource o data source

# Crear namespace para Vault Injector si no existe
resource "kubernetes_namespace_v1" "vault" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

# Instalar Vault Injector usando Helm con archivo values.yaml
resource "helm_release" "vault_injector" {
  name       = var.release_name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.chart_version != "" ? var.chart_version : null
  namespace  = var.namespace

  # Usar archivo values.yaml generado dinámicamente
  # Preprocesar variables para facilitar el parsing en el template
  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      vault_address         = var.vault_address
      vault_skip_tls_verify = var.vault_skip_tls_verify
      vault_agent_image     = var.vault_agent_image
      agent_image_repo      = var.vault_agent_image != "" && length(split(":", var.vault_agent_image)) > 1 ? split(":", var.vault_agent_image)[0] : (var.vault_agent_image != "" ? var.vault_agent_image : "")
      agent_image_tag       = var.vault_agent_image != "" && length(split(":", var.vault_agent_image)) > 1 ? split(":", var.vault_agent_image)[1] : ""
      has_agent_image       = var.vault_agent_image != ""
      has_image_tag         = var.vault_agent_image != "" && length(split(":", var.vault_agent_image)) > 1
    })
  ]

  # Esperar a que el release esté listo
  wait    = true
  timeout = var.helm_timeout

  depends_on = [
    kubernetes_namespace_v1.vault
  ]
}
