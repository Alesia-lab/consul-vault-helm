# Values file para Vault Agent Injector
# Este archivo se genera dinámicamente basado en las variables del módulo

server:
  enabled: false

injector:
  enabled: true
  externalVaultAddr: "${vault_address}"
  
  agentDefaults:
    extraEnvironmentVars:
      # Configurar VAULT_ADDR explícitamente para evitar problemas de DNS
      # cuando Vault está en otro cluster o es externo
      VAULT_ADDR: "${vault_address}"
%{ if vault_skip_tls_verify ~}
      VAULT_SKIP_VERIFY: "true"
%{ endif ~}
%{ if has_agent_image ~}
  agentImage:
%{ if has_image_tag ~}
    repository: "${agent_image_repo}"
    tag: "${agent_image_tag}"
%{ else ~}
    repository: "${agent_image_repo}"
%{ endif ~}
%{ endif ~}
