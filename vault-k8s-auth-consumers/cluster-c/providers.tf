# Provider Configuration para Cluster-C
# Este proyecto se ejecuta en el contexto del cluster-c
# que puede estar en una cuenta AWS diferente

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }

  # ⚠️ NOTA: Este proyecto usa backend local
  # El state se guarda en terraform.tfstate en este directorio
  # El proyecto de Vault leerá este state usando terraform_remote_state
  # con backend "local"
}

# Provider de AWS
# ⚠️ IMPORTANTE: Configurar credenciales para la cuenta AWS del cluster-c
# Opción 1: Usar perfil de AWS
# export AWS_PROFILE=cluster-c-profile
# Opción 2: Configurar ~/.aws/credentials con el perfil correspondiente
provider "aws" {
  region = var.aws_region

  # Si necesitas especificar perfil explícitamente:
  # profile = var.aws_profile
}

# Data source para obtener información del cluster EKS
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Data source para obtener token de autenticación del cluster EKS
data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# Provider de Kubernetes configurado con datos de EKS
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Provider de Helm configurado con datos de EKS
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
