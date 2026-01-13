variable "service_account_name" {
  description = "Nombre del ServiceAccount que Vault usará para token reviews"
  type        = string
  default     = "vault-auth-reviewer"
}

variable "namespace" {
  description = "Namespace donde se creará el ServiceAccount"
  type        = string
  default     = "kube-system"
}

variable "service_account_annotations" {
  description = "Anotaciones adicionales para el ServiceAccount (útil para IRSA en EKS)"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "Nombre del cluster Kubernetes (para referencia en outputs)"
  type        = string
}

variable "kubernetes_host" {
  description = "Host del API server de Kubernetes (ej: https://api.eks.us-east-1.amazonaws.com). Si no se proporciona, se intentará obtener del provider."
  type        = string
  default     = ""
}

variable "kubernetes_ca_cert" {
  description = "Certificado CA del cluster Kubernetes en formato PEM. Si no se proporciona, se intentará obtener del provider."
  type        = string
  default     = ""
  sensitive   = true
}
