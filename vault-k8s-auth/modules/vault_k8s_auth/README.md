# Módulo: vault_k8s_auth

Este módulo configura un Kubernetes Auth Backend en Vault para un cluster consumidor específico.

## Recursos Creados

- `vault_auth_backend`: Habilita el auth mount Kubernetes
- `vault_kubernetes_auth_backend_config`: Configura el auth backend con credenciales del cluster
- `vault_kubernetes_auth_backend_role`: Crea roles que mapean ServiceAccounts/Namespaces a Policies

## Uso

```hcl
module "vault_k8s_auth_cluster_a" {
  source = "./modules/vault_k8s_auth"

  cluster_identifier = "cluster-a"
  auth_path          = "kubernetes-cluster-a"

  kubernetes_host    = module.k8s_reviewer_cluster_a.kubernetes_host
  kubernetes_ca_cert = module.k8s_reviewer_cluster_a.kubernetes_ca_cert
  token_reviewer_jwt = module.k8s_reviewer_cluster_a.token_reviewer_jwt

  roles = {
    "app-readonly" = {
      bound_service_account_names      = ["app-sa"]
      bound_service_account_namespaces = ["default", "app"]
      token_policies                   = ["app-readonly-policy"]
      token_ttl                        = "1h"
    }
  }
}
```

## Variables Importantes

- `token_reviewer_jwt`: JWT del ServiceAccount (sensible)
- `kubernetes_ca_cert`: Certificado CA del cluster (sensible)
- `roles`: Mapa de roles con sus configuraciones
