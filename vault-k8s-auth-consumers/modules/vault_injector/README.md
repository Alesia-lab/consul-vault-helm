# Módulo: vault_injector

Este módulo instala el Vault Agent Injector en un cluster de Kubernetes usando Helm.

## Descripción

El Vault Agent Injector es un componente que inyecta automáticamente el sidecar `vault-agent` en los pods que tienen las anotaciones apropiadas, permitiendo que las aplicaciones accedan a secretos de Vault sin necesidad de modificar el código.

## Uso

```hcl
module "vault_injector" {
  source = "../modules/vault_injector"

  vault_address         = "https://vault.example.com"
  vault_skip_tls_verify = true
  namespace             = "vault"
  release_name          = "vault-injector"
}
```

## Variables

| Variable | Descripción | Tipo | Default | Requerido |
|----------|-------------|------|---------|-----------|
| `vault_address` | Dirección del servidor de Vault | `string` | - | ✅ |
| `vault_skip_tls_verify` | Deshabilitar verificación TLS | `bool` | `false` | ❌ |
| `namespace` | Namespace donde se instalará | `string` | `"vault"` | ❌ |
| `create_namespace` | Crear namespace si no existe | `bool` | `true` | ❌ |
| `release_name` | Nombre del release de Helm | `string` | `"vault-injector"` | ❌ |
| `chart_version` | Versión del chart (vacío = última) | `string` | `""` | ❌ |
| `vault_agent_image` | Imagen del vault-agent | `string` | `""` | ❌ |
| `helm_timeout` | Timeout para Helm (segundos) | `number` | `300` | ❌ |

## Outputs

| Output | Descripción |
|--------|-------------|
| `release_name` | Nombre del release de Helm |
| `namespace` | Namespace donde se instaló |
| `chart_version` | Versión del chart instalado |
| `status` | Estado del release |

## Archivos

- `main.tf`: Configuración principal del módulo
- `values.yaml.tpl`: Template que genera el archivo values.yaml dinámicamente
- `values.yaml`: Archivo de referencia que muestra la configuración completa generada
- `variables.tf`: Variables del módulo
- `outputs.tf`: Outputs del módulo

## Requisitos

- Provider `helm` configurado
- Provider `kubernetes` configurado
- Acceso al cluster de Kubernetes
- Helm instalado en el sistema donde se ejecuta Terraform (opcional, pero recomendado)

## Notas

- Este módulo instala **solo el injector**, no el servidor de Vault
- El injector debe poder alcanzar el servidor de Vault desde el cluster
- Para certificados autofirmados, usar `vault_skip_tls_verify = true` (solo desarrollo/testing)
