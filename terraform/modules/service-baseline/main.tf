# Everything a golden-path service needs in AWS, and nothing more:
# an image repository, a workload role for the pods, and (optionally) a role
# CI can assume to push images, with no long-lived keys anywhere.

locals {
  service_account = coalesce(var.service_account, var.name)
  oidc_issuer     = trimprefix(var.oidc_provider_url, "https://")
  tags            = merge(var.tags, { Service = var.name, Team = var.team })
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE" # a tag always means the same image

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = var.kms_key_arn == null ? "AES256" : "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the newest ${var.keep_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_images
        }
        action = { type = "expire" }
      },
    ]
  })
}

# Workload role: assumable only by this service's service account.
data "aws_iam_policy_document" "workload_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "workload" {
  name                 = "svc-${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.workload_trust.json
  max_session_duration = 3600
  tags                 = local.tags
}

resource "aws_iam_role_policy" "workload" {
  count  = var.workload_policy_json == null ? 0 : 1
  name   = "workload"
  role   = aws_iam_role.workload.id
  policy = var.workload_policy_json
}

# CI role: GitHub Actions in one repository may push to this repository's
# images, and only from the default branch or a version tag.
data "aws_iam_policy_document" "ci_trust" {
  count = var.github_repository == null ? 0 : 1

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:refs/heads/main",
        "repo:${var.github_repository}:ref:refs/tags/v*",
      ]
    }
  }
}

data "aws_iam_policy_document" "ci_push" {
  statement {
    sid       = "Login"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this action does not support resource-level permissions
  }
  statement {
    sid = "PushThisRepository"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.this.arn]
  }
}

resource "aws_iam_role" "ci" {
  count = var.github_repository == null ? 0 : 1

  name                 = "ci-${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.ci_trust[0].json
  max_session_duration = 3600
  tags                 = local.tags

  lifecycle {
    precondition {
      condition     = var.github_oidc_provider_arn != null
      error_message = "github_oidc_provider_arn is required when github_repository is set."
    }
  }
}

resource "aws_iam_role_policy" "ci_push" {
  count  = var.github_repository == null ? 0 : 1
  name   = "ecr-push"
  role   = aws_iam_role.ci[0].id
  policy = data.aws_iam_policy_document.ci_push.json
}
