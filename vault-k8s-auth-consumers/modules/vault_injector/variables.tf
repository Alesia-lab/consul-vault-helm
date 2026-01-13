variable "vault_address" {
  description = "Dirección del servidor de Vault (ej: https://vault.example.com)"
  type        = string
}

variable "vault_skip_tls_verify" {
  description = "Deshabilitar verificación TLS (solo para desarrollo/testing con certificados autofirmados)"
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Namespace donde se instalará el vault-injector"
  type        = string
  default     = "vault"
}

variable "create_namespace" {
  description = "Crear el namespace si no existe"
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Nombre del release de Helm para el vault-injector"
  type        = string
  default     = "vault-injector"
}

variable "chart_version" {
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
