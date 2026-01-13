# Variables para la configuración de Vault

variable "vault_address" {
  description = "Dirección del servidor de Vault (ej: https://vault.example.com:8200)"
  type        = string
}

variable "vault_token" {
  description = "Token de Vault para autenticación. ⚠️ SENSIBLE. Para producción, usar métodos más seguros (AppRole, AWS Auth, etc.)"
  type        = string
  sensitive   = true
}

variable "vault_skip_tls_verify" {
  description = <<-EOT
    Deshabilitar verificación TLS para certificados autofirmados.
    ⚠️ ADVERTENCIA: Solo para desarrollo/testing con certificados autofirmados.
    ⚠️ NUNCA usar en producción con https://
    Nota: Si vault_address usa http://, esta opción se ignora automáticamente.
  EOT
  type        = bool
  default     = false
}

variable "vault_ca_cert_file" {
  description = "Ruta al archivo de certificado CA para validar el certificado de Vault"
  type        = string
  default     = ""
}

variable "vault_namespace" {
  description = "Namespace de Vault (si se usa Vault Enterprise con namespaces)"
  type        = string
  default     = ""
}

# ============================================================================
# Variables para KV v2 Secrets Engine
# ============================================================================

variable "enable_kv_v2" {
  description = "Habilitar el KV v2 secrets engine en Vault"
  type        = bool
  default     = true
}

variable "kv_v2_path" {
  description = "Path donde se habilitará el KV v2 engine (ej: 'secret')"
  type        = string
  default     = "secret"
}

variable "kv_v2_description" {
  description = "Descripción del KV v2 secrets engine"
  type        = string
  default     = "KV v2 secrets engine for versioned secrets"
}

# Variables para datos de clusters consumidores
# Estos valores se pueden obtener de dos formas:
# 1. Usando terraform_remote_state (recomendado) - lee del estado local del proyecto de clusters
# 2. Proporcionando valores manualmente desde terminal/variables de entorno

# Path al directorio del proyecto de clusters consumidores
variable "consumers_project_path" {
  description = "Ruta absoluta al directorio raíz del proyecto vault-k8s-auth-consumers"
  type        = string
  default     = ""
}

# Configuración dinámica de múltiples clusters
variable "clusters" {
  description = <<-EOT
    Mapa de clusters a configurar. Cada entrada define un cluster consumidor.
    
    Key = nombre del cluster (debe coincidir con el directorio en vault-k8s-auth-consumers, ej: "cluster-b", "cluster-c")
    Value = objeto con la configuración del cluster:
      - use_remote_state: Si es true, lee del estado local. Si es false, usa config manual.
      - config: Configuración manual (solo si use_remote_state = false). Formato: { token_reviewer_jwt = "...", kubernetes_host = "...", kubernetes_ca_cert = "..." }
      - roles: Roles específicos para este cluster (mapean ServiceAccounts/Namespaces → Policies)
      - auth_path: Path del auth mount en Vault (opcional, por defecto: "kubernetes-{cluster_name}")
      - disable_iss_validation: Deshabilitar validación del issuer (opcional, default: false)
      - disable_local_ca_jwt: Deshabilitar validación del CA local en JWT (opcional, default: false)
    
    Ejemplo:
    clusters = {
      "cluster-b" = {
        use_remote_state = true
        roles = {
          "app-readonly" = {
            bound_service_account_names      = ["app-sa"]
            bound_service_account_namespaces = ["default", "app"]
            token_policies                   = ["app-readonly-policy"]
            token_ttl                        = 3600
            token_max_ttl                    = 14400
          }
        }
      }
      "cluster-c" = {
        use_remote_state = true
        roles = {
          "app-readwrite" = {
            bound_service_account_names      = ["app-sa"]
            bound_service_account_namespaces = ["app"]
            token_policies                   = ["app-readwrite-policy"]
            token_ttl                        = 1800
            token_max_ttl                    = 7200
          }
        }
      }
    }
  EOT
  type = map(object({
    use_remote_state = bool
    config = optional(object({
      token_reviewer_jwt = string
      kubernetes_host    = string
      kubernetes_ca_cert = string
    }), null)
    roles = map(object({
      bound_service_account_names      = list(string)
      bound_service_account_namespaces = list(string)
      token_ttl                        = number
      token_max_ttl                    = number
      token_policies                   = list(string)
      token_bound_cidrs               = optional(list(string), [])
      audience                        = optional(string, "")
      alias_name_source               = optional(string, "serviceaccount_name")
    }))
    auth_path            = optional(string, "")
    disable_iss_validation = optional(bool, false)
    disable_local_ca_jwt   = optional(bool, false)
  }))
  default = {}
  sensitive = true
}

# ============================================================================
# Variables para Vault Policies
# ============================================================================

variable "vault_policies" {
  description = <<-EOT
    Mapa de políticas de Vault a crear.
    Key = nombre de la política
    Value = objeto con el contenido de la política en formato HCL
    
    Estas políticas definen qué paths pueden acceder los roles de Kubernetes Auth.
    Se referencian en cluster_b_roles mediante token_policies.
    
    Ejemplo:
    vault_policies = {
      "app-readonly-policy" = {
        policy_content = <<-POLICY
          path "secret/data/app/*" {
            capabilities = ["read", "list"]
          }
        POLICY
      }
    }
  EOT
  type = map(object({
    policy_content = string
  }))
  default = {}
}

# ============================================================================
# Variables para Roles de Kubernetes Auth
# ============================================================================
# NOTA: Los roles ahora se definen dentro de la variable "clusters" para cada cluster.
# Esta sección se mantiene por compatibilidad hacia atrás, pero está deprecada.
# Usar la variable "clusters" en su lugar.
