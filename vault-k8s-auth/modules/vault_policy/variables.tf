variable "policies" {
  description = <<-EOT
    Mapa de políticas de Vault a crear.
    Key = nombre de la política
    Value = objeto con el contenido de la política en formato HCL
    
    Ejemplo:
    policies = {
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
