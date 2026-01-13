variable "cluster_identifier" {
  description = "Identificador único del cluster consumidor (ej: 'cluster-a', 'prod-eu-west-1')"
  type        = string
}

variable "auth_path" {
  description = "Path del auth mount en Vault (ej: 'kubernetes-cluster-a'). Por defecto: 'kubernetes-{cluster_identifier}'"
  type        = string
  default     = ""
}

variable "kubernetes_host" {
  description = "Host del API server de Kubernetes (ej: 'https://kubernetes.default.svc' o 'https://api.eks.us-east-1.amazonaws.com')"
  type        = string
}

variable "kubernetes_ca_cert" {
  description = "Certificado CA del cluster Kubernetes en formato PEM. ⚠️ SENSIBLE"
  type        = string
  sensitive   = true
}

variable "token_reviewer_jwt" {
  description = "JWT token del ServiceAccount usado para token reviews. ⚠️ SENSIBLE"
  type        = string
  sensitive   = true
}

variable "kubernetes_issuer" {
  description = "Issuer del cluster Kubernetes (opcional, se detecta automáticamente si no se proporciona)"
  type        = string
  default     = ""
}

variable "disable_iss_validation" {
  description = "Deshabilita la validación del issuer. ⚠️ Solo para desarrollo/testing"
  type        = bool
  default     = false
}

variable "disable_local_ca_jwt" {
  description = "Deshabilita la validación del CA local en JWT. ⚠️ Solo para desarrollo/testing"
  type        = bool
  default     = false
}

variable "roles" {
  description = "Mapa de roles a crear en el auth backend. Key = nombre del rol, Value = configuración del rol. ⚠️ token_ttl y token_max_ttl deben ser números en segundos (ej: 3600 para 1 hora, 1800 para 30 minutos)"
  type = map(object({
    bound_service_account_names      = list(string)
    bound_service_account_namespaces = list(string)
    token_ttl                        = number  # En segundos (ej: 3600 = 1 hora, 1800 = 30 minutos)
    token_max_ttl                   = number   # En segundos (ej: 86400 = 24 horas, 7200 = 2 horas)
    token_policies                   = list(string)
    token_bound_cidrs               = optional(list(string), [])
    audience                        = optional(string, "")
    alias_name_source               = optional(string, "serviceaccount_name")
  }))
  default = {}
}
