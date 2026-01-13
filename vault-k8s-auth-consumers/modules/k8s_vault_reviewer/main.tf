# Módulo: k8s_vault_reviewer
# Propósito: Configura un ServiceAccount en un cluster Kubernetes consumidor
# con permisos mínimos para que Vault pueda realizar token reviews.
#
# Este módulo se ejecuta en el CONTEXTO del cluster consumidor y expone
# los outputs necesarios para configurar el auth backend en Vault.

terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
  }
}

# ServiceAccount dedicado para Vault token review
# Usando kubernetes_service_account_v1 para evitar deprecación
resource "kubernetes_service_account_v1" "vault_reviewer" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    labels = {
      app                        = "vault-auth-reviewer"
      "app.kubernetes.io/name"   = "vault-auth-reviewer"
      "app.kubernetes.io/part-of" = "vault-k8s-auth"
    }
    annotations = var.service_account_annotations
  }

  automount_service_account_token = true
}

# ClusterRole con permisos mínimos para token review
# Usando kubernetes_cluster_role_v1 para evitar deprecación
resource "kubernetes_cluster_role_v1" "vault_reviewer" {
  metadata {
    name = "${var.service_account_name}-reviewer"
    labels = {
      app                        = "vault-auth-reviewer"
      "app.kubernetes.io/name"   = "vault-auth-reviewer"
      "app.kubernetes.io/part-of" = "vault-k8s-auth"
    }
  }

  rule {
    api_groups     = ["authentication.k8s.io"]
    resources      = ["tokenreviews"]
    verbs          = ["create"]
  }
}

# ClusterRoleBinding que asocia el ServiceAccount con el ClusterRole
# Usando kubernetes_cluster_role_binding_v1 para evitar deprecación
resource "kubernetes_cluster_role_binding_v1" "vault_reviewer" {
  metadata {
    name = "${var.service_account_name}-reviewer"
    labels = {
      app                        = "vault-auth-reviewer"
      "app.kubernetes.io/name"   = "vault-auth-reviewer"
      "app.kubernetes.io/part-of" = "vault-k8s-auth"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.vault_reviewer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.vault_reviewer.metadata[0].name
    namespace = kubernetes_service_account_v1.vault_reviewer.metadata[0].namespace
  }
}

# Secret asociado al ServiceAccount (contiene el JWT token)
# Nota: En Kubernetes 1.24+, los secrets de ServiceAccount no se crean automáticamente
# Este recurso asegura que el secret exista y sea accesible
# Usando kubernetes_secret_v1 para evitar deprecación
resource "kubernetes_secret_v1" "vault_reviewer_token" {
  metadata {
    name      = "${var.service_account_name}-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.vault_reviewer.metadata[0].name
    }
    labels = {
      app                        = "vault-auth-reviewer"
      "app.kubernetes.io/name"   = "vault-auth-reviewer"
      "app.kubernetes.io/part-of" = "vault-k8s-auth"
    }
  }

  type = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true

  depends_on = [kubernetes_service_account_v1.vault_reviewer]
}

# Data source para obtener el JWT token del ServiceAccount
# Esperamos a que el secret esté disponible antes de leerlo
# Usando kubernetes_secret_v1 para evitar deprecación
data "kubernetes_secret_v1" "vault_reviewer_jwt" {
  metadata {
    name      = kubernetes_secret_v1.vault_reviewer_token.metadata[0].name
    namespace = var.namespace
  }

  depends_on = [
    kubernetes_secret_v1.vault_reviewer_token,
    kubernetes_service_account_v1.vault_reviewer
  ]
}

# Local para determinar el host del cluster
locals {
  kubernetes_host = coalesce(
    var.kubernetes_host,
    "https://kubernetes.default.svc"  # Host interno por defecto
  )
}
