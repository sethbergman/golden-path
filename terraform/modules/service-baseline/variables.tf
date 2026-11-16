variable "name" {
  description = "Service name; used for the ECR repository and IAM roles."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "name must be 3-32 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "team" {
  description = "Owning team, applied as a tag for cost attribution."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace the service runs in."
  type        = string
}

variable "service_account" {
  description = "Kubernetes service account name. Defaults to the service name, as the golden-path chart does."
  type        = string
  default     = null
}

variable "oidc_provider_arn" {
  description = "EKS cluster IAM OIDC provider ARN, for the workload role (IRSA)."
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS cluster OIDC issuer URL, with or without https://."
  type        = string
}

variable "workload_policy_json" {
  description = "Optional inline IAM policy for the running service. Leave null for a service that needs no AWS access."
  type        = string
  default     = null
}

variable "github_repository" {
  description = "Optional owner/repo allowed to push images via GitHub Actions OIDC. Null to skip the CI role."
  type        = string
  default     = null
}

variable "github_oidc_provider_arn" {
  description = "ARN of the account's token.actions.githubusercontent.com OIDC provider. Required when github_repository is set."
  type        = string
  default     = null
}

variable "keep_images" {
  description = "Number of tagged images to keep. Untagged images expire after 7 days."
  type        = number
  default     = 50
}

variable "kms_key_arn" {
  description = "Optional KMS key for image encryption. Defaults to AES256."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags for every resource."
  type        = map(string)
  default     = {}
}
