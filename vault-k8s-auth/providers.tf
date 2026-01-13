# Provider Configuration para Vault
# Este archivo configura el provider de Vault para gestionar la configuración
#
# ⚠️ NOTA: Terraform corre FUERA del cluster donde está Vault
# Asegúrate de tener:
# - Conectividad de red a Vault (VPN, PrivateLink, o endpoint seguro)
# - Token de Vault o método de autenticación configurado
# - Certificados TLS válidos (no usar skip_tls_verify en producción)

terraform {
  required_version = ">= 1.10.4"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.15.0"
    }
  }

  # ⚠️ SEGURIDAD: Usar backend remoto con encriptación para el state
  # El state contiene JWT tokens y certificados sensibles
  # Ejemplo:
  # backend "s3" {
  #   bucket         = "terraform-state-bucket"
  #   key            = "vault-k8s-auth/vault/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# Provider de Vault
# ⚠️ SEGURIDAD: Configurar autenticación segura
# Opciones:
# 1. Token de Vault (no recomendado para producción, usar métodos más seguros)
# 2. AWS Auth Method (si Vault está en AWS)
# 3. AppRole (recomendado para CI/CD)
# 4. OIDC/JWT
provider "vault" {
  # Endpoint de Vault
  # Soporta http:// o https://
  # Si usa http://, skip_tls_verify se ignora automáticamente
  address = var.vault_address

  # ⚠️ ADVERTENCIA: skip_tls_verify solo aplica para https://
  # Para http://, la verificación TLS no aplica
  # ⚠️ CRÍTICO: No usar skip_tls_verify=true en producción con https://
  # Solo para desarrollo/testing con certificados autofirmados
  skip_tls_verify = var.vault_skip_tls_verify

  # CA cert para validar el certificado de Vault (solo para https://)
  # Si se proporciona, se usa para validar el certificado incluso si skip_tls_verify=true
  ca_cert_file = var.vault_ca_cert_file != "" ? var.vault_ca_cert_file : null

  # Autenticación: Token (para desarrollo/testing)
  # Para producción, usar vault_aws_auth_backend_role_login o vault_approle_auth_backend_login
  token = var.vault_token

  # Headers adicionales si es necesario (ej: para Vault namespaces)
  # headers = {
  #   "X-Vault-Namespace" = var.vault_namespace
  # }
}
