output "repository_url" {
  description = "ECR repository URL: the chart's image.repository."
  value       = aws_ecr_repository.this.repository_url
}

output "role_arn" {
  description = "Workload role ARN: the chart's serviceAccount.annotations[\"eks.amazonaws.com/role-arn\"]."
  value       = aws_iam_role.workload.arn
}

output "ci_role_arn" {
  description = "Role for GitHub Actions to push images (null when github_repository is unset)."
  value       = try(aws_iam_role.ci[0].arn, null)
}
