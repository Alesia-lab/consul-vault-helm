# Quick Start - Clusters Consumidores

Guía rápida para configurar un cluster consumidor (empezando con cluster-b).

## Prerrequisitos

1. **Terraform** >= 1.0
2. **kubectl** configurado
3. **AWS CLI** configurado con credenciales para la cuenta del cluster
4. **Acceso al cluster EKS**

## Configuración Rápida de Cluster-B

### Paso 1: Configurar Credenciales AWS

```bash
# Opción 1: Usar perfil de AWS
export AWS_PROFILE=cluster-b-profile

# Opción 2: Configurar credenciales directamente
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

### Paso 2: Configurar Kubeconfig

```bash
# Asegurar que kubeconfig apunta al cluster-b
kubectl config use-context cluster-b-context

# Verificar acceso
kubectl get nodes
```

### Paso 3: Configurar Variables

```bash
cd cluster-b

# Copiar archivo de ejemplo
cp terraform.tfvars.example terraform.tfvars

# Editar terraform.tfvars
cat > terraform.tfvars <<EOF
cluster_name = "cluster-b"
aws_region   = "us-east-1"
namespace    = "kube-system"
service_account_name = "vault-auth-reviewer"
EOF
```

### Paso 4: Aplicar Configuración

```bash
# Inicializar Terraform
terraform init

# Revisar plan
terraform plan

# Aplicar configuración
terraform apply
```

### Paso 5: Verificar Outputs

```bash
# Ver todos los outputs
terraform output

# Ver outputs específicos (sensible)
terraform output token_reviewer_jwt
terraform output kubernetes_host
terraform output kubernetes_ca_cert
```

## Verificar en Kubernetes

```bash
# Verificar ServiceAccount creado
kubectl get serviceaccount vault-auth-reviewer -n kube-system

# Verificar ClusterRole
kubectl get clusterrole vault-auth-reviewer-reviewer

# Verificar ClusterRoleBinding
kubectl get clusterrolebinding vault-auth-reviewer-reviewer

# Verificar Secret con JWT
kubectl get secret vault-auth-reviewer-token -n kube-system
```

## Siguiente Paso

Una vez configurado el cluster-b, el proyecto de Vault puede leer estos outputs usando `terraform_remote_state` o puedes proporcionarlos manualmente.

Ver: `/home/edgar/ATT/vault-k8s-auth/envs/vault/USAGE.md`
