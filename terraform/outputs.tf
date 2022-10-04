output "project_name" {
  value = var.project_name
}

output "aws_region" {
  value = var.aws_region
}

output "github_owner" {
  value = var.github_owner
}

output "github_repo" {
  value = var.github_repo
}

output "docker_image" {
  value = var.docker_image
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity#account_id
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "ecr_repo_public" {
  value = aws_ecrpublic_repository.ecr_repo_public.repository_uri
}

output "ecr_repo_private" {
  value = aws_ecr_repository.ecr_repo_private.repository_url
}
