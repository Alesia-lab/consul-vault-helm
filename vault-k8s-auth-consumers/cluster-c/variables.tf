variable "cluster_name" {
  description = "Nombre del cluster EKS (cluster-c)"
  type        = string
  default     = "cluster-c"
}

variable "aws_region" {
  description = "AWS region donde está el cluster EKS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil de AWS a usar (opcional, se puede usar AWS_PROFILE env var)"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Namespace donde se creará el ServiceAccount para Vault"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Nombre del ServiceAccount que Vault usará para token reviews"
  type        = string
  default     = "vault-auth-reviewer"
}

variable "service_account_annotations" {
  description = "Anotaciones adicionales para el ServiceAccount (útil para IRSA en EKS)"
  type        = map(string)
  default     = {}
}

# ============================================================================
# Variables para Vault Injector
# ============================================================================

variable "install_vault_injector" {
  description = "Instalar el Vault Agent Injector en el cluster"
  type        = bool
  default     = true
}

variable "vault_address" {
  description = "Dirección del servidor de Vault (ej: https://vault.example.com)"
  type        = string
  default     = ""
}

variable "vault_skip_tls_verify" {
  description = "Deshabilitar verificación TLS para Vault (solo desarrollo/testing con certificados autofirmados)"
  type        = bool
  default     = true
}

variable "vault_injector_namespace" {
  description = "Namespace donde se instalará el vault-injector"
  type        = string
  default     = "vault"
}

variable "vault_injector_create_namespace" {
  description = "Crear el namespace del vault-injector si no existe"
  type        = bool
  default     = true
}

variable "vault_injector_release_name" {
  description = "Nombre del release de Helm para el vault-injector"
  type        = string
  default     = "vault-injector"
}

variable "vault_injector_chart_version" {
  description = "Versión del chart de Helm de Vault a usar (dejar vacío para usar la última)"
  type        = string
  default     = ""
}

variable "vault_agent_image" {
  description = "Imagen del vault-agent a usar (ej: hashicorp/vault:1.20.4). Dejar vacío para usar la del chart"
  type        = string
  default     = ""
}

variable "helm_timeout" {
  description = "Timeout para la instalación de Helm (en segundos)"
  type        = number
  default     = 300
}
