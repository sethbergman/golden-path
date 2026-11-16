# AWS baseline for hello-service. Feeds deploy/values.yaml:
#   image.repository <- repository_url
#   serviceAccount.annotations["eks.amazonaws.com/role-arn"] <- role_arn

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 6.74"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "cluster_name" {
  type = string
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

module "hello_service" {
  source = "../../modules/service-baseline"

  name              = "hello-service"
  team              = "platform"
  namespace         = "platform"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

  github_repository        = "sethbergman/golden-path"
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  # hello-service reads nothing from AWS; a real service would pass its policy here.
  workload_policy_json = null
}

output "repository_url" {
  value = module.hello_service.repository_url
}

output "role_arn" {
  value = module.hello_service.role_arn
}

output "ci_role_arn" {
  value = module.hello_service.ci_role_arn
}
