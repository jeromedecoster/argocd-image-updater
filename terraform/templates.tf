resource "local_file" "argocd_docker" {
  filename = local.argocd_docker
  # file_permission = "644"
  # https://www.terraform.io/language/functions/templatefile
  content = templatefile(local.argocd_docker_tmpl, local.template_vars)
}

resource "local_file" "argocd_docker_kustomize" {
  filename = local.argocd_docker_kustomize
  content  = templatefile(local.argocd_docker_kustomize_tmpl, local.template_vars)
}

resource "local_file" "argocd_ecr_public" {
  filename = local.argocd_ecr_public
  content  = templatefile(local.argocd_ecr_public_tmpl, local.template_vars)
}

resource "local_file" "argocd_ecr_public_kustomize" {
  filename = local.argocd_ecr_public_kustomize
  content  = templatefile(local.argocd_ecr_public_kustomize_tmpl, local.template_vars)
}

resource "local_file" "argocd_ecr_private" {
  filename = local.argocd_ecr_private
  content  = templatefile(local.argocd_ecr_private_tmpl, local.template_vars)
}

resource "local_file" "argocd_ecr_private_kustomize" {
  filename = local.argocd_ecr_private_kustomize
  content  = templatefile(local.argocd_ecr_private_kustomize_tmpl, local.template_vars)
}

resource "local_file" "argocd_ecr_private_secret_cm" {
  filename = local.argocd_ecr_private_secret_cm
  content  = templatefile(local.argocd_ecr_private_secret_cm_tmpl, local.template_vars)
}