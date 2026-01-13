# Vault Kubernetes Auth - Clusters Consumidores

Este proyecto Terraform configura los clusters Kubernetes consumidores para permitir que Vault realice token reviews. Cada cluster puede estar en una cuenta AWS diferente, por lo que este proyecto se ejecuta de forma independiente para cada cluster.

## Características

Este proyecto configura:
1. **ServiceAccount y RBAC**: Crea el ServiceAccount necesario para que Vault pueda realizar token reviews
2. **Vault Agent Injector**: Instala automáticamente el vault-injector en el cluster (opcional, habilitado por defecto)

## Estructura

```
vault-k8s-auth-consumers/
├── cluster-b/              # Configuración para cluster-b
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── terraform.tfvars.example
├── cluster-c/              # Futuro: cluster-c
├── cluster-d/              # Futuro: cluster-d
└── modules/
    ├── k8s_vault_reviewer/ # Módulo para crear ServiceAccount y RBAC
    └── vault_injector/      # Módulo para instalar Vault Agent Injector
```

## Uso

### Configurar Cluster-B

```bash
cd cluster-b

# 1. Configurar credenciales AWS para la cuenta del cluster-b
export AWS_PROFILE=cluster-b-profile
# O configurar ~/.aws/credentials con el perfil correspondiente

# 2. Configurar kubeconfig para cluster-b
kubectl config use-context cluster-b-context

# 3. Configurar variables
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars según tu entorno

# 4. Inicializar y aplicar
terraform init
terraform plan
terraform apply

# 5. Los outputs se guardan en terraform.tfstate local
# Este state será leído por el proyecto de Vault
```

## Outputs

Este proyecto genera los siguientes outputs (almacenados en `terraform.tfstate`):

### ServiceAccount y RBAC
- `token_reviewer_jwt`: JWT token del ServiceAccount (sensible)
- `kubernetes_host`: Host del API server de Kubernetes
- `kubernetes_ca_cert`: Certificado CA del cluster (sensible)

### Vault Injector
- `vault_injector_release_name`: Nombre del release de Helm
- `vault_injector_namespace`: Namespace donde se instaló
- `vault_injector_status`: Estado del release
- `vault_injector_chart_version`: Versión del chart instalado

Estos outputs son leídos por el proyecto de Vault usando `terraform_remote_state` con backend local.

## Agregar Nuevo Cluster

Para agregar un nuevo cluster (ej: cluster-c):

```bash
# 1. Copiar estructura de cluster-b
cp -r cluster-b cluster-c

# 2. Ajustar variables según el nuevo cluster
cd cluster-c
# Editar variables.tf y terraform.tfvars

# 3. Configurar credenciales AWS para la nueva cuenta
export AWS_PROFILE=cluster-c-profile

# 4. Aplicar configuración
terraform init
terraform apply
```

## Notas Importantes

- **Cuentas AWS diferentes**: Cada cluster puede estar en una cuenta AWS diferente. Cambiar `AWS_PROFILE` o credenciales antes de ejecutar Terraform.
- **State local**: El state se guarda localmente en cada directorio de cluster. El proyecto de Vault leerá estos states.
- **Seguridad**: Los outputs contienen material sensible. No commitear `terraform.tfstate` ni `terraform.tfvars`.
- **Configuración de Vault Address**: Si Vault está en otro cluster o es externo, asegúrate de configurar correctamente `vault_address` en `terraform.tfvars`. Ver `CLUSTER-SETUP.md` para más detalles sobre configuración y troubleshooting.

## Documentación Adicional

- **`CLUSTER-SETUP.md`**: Guía completa para configurar el proyecto en cualquier cluster, incluyendo solución a problemas comunes de conectividad DNS.
- **`TROUBLESHOOTING.md`**: Guía de troubleshooting con soluciones a problemas comunes, incluyendo el error "no such host" y otros problemas de autenticación.