locals {
  # https://www.terraform.io/language/expressions/references#filesystem-and-workspace-info
  # target the $PROJECT_DIR
  project_dir = abspath("${path.root}/..")

  key_file_pub = "${local.project_dir}/${var.project_name}.pub"
  key_file_pem = "${local.project_dir}/${var.project_name}.pem"

  argocd_docker_tmpl = abspath("${path.root}/../argocd/.tmpl/argocd-docker.tmpl.yaml")
  argocd_docker      = abspath("${path.root}/../argocd/argocd-docker.yaml")

  argocd_docker_kustomize_tmpl = abspath("${path.root}/../argocd/.tmpl/overlays/docker/kustomization.tmpl.yaml")
  argocd_docker_kustomize      = abspath("${path.root}/../argocd/overlays/docker/kustomization.yaml")

  argocd_ecr_public_tmpl = abspath("${path.root}/../argocd/.tmpl/argocd-ecr-public.tmpl.yaml")
  argocd_ecr_public      = abspath("${path.root}/../argocd/argocd-ecr-public.yaml")

  argocd_ecr_public_kustomize_tmpl = abspath("${path.root}/../argocd/.tmpl/overlays/ecr-public/kustomization.tmpl.yaml")
  argocd_ecr_public_kustomize      = abspath("${path.root}/../argocd/overlays/ecr-public/kustomization.yaml")

  argocd_ecr_private_tmpl = abspath("${path.root}/../argocd/.tmpl/argocd-ecr-private.tmpl.yaml")
  argocd_ecr_private      = abspath("${path.root}/../argocd/argocd-ecr-private.yaml")

  argocd_ecr_private_kustomize_tmpl = abspath("${path.root}/../argocd/.tmpl/overlays/ecr-private/kustomization.tmpl.yaml")
  argocd_ecr_private_kustomize      = abspath("${path.root}/../argocd/overlays/ecr-private/kustomization.yaml")

  argocd_ecr_private_secret_cm_tmpl = abspath("${path.root}/../argocd/.tmpl/overlays/ecr-private/creds-secret-cm.tmpl.yaml")
  argocd_ecr_private_secret_cm      = abspath("${path.root}/../argocd/overlays/ecr-private/creds-secret-cm.yaml")

  template_vars = {
    github_repo  = var.github_repo,
    docker_image = var.docker_image,
    # /!\ it is URI for public ECR
    ecr_repo_public = aws_ecrpublic_repository.ecr_repo_public.repository_uri
    # /!\ it is URL for private ECR
    ecr_repo_private      = aws_ecr_repository.ecr_repo_private.repository_url
    aws_access_key_id     = aws_iam_access_key.user_key.id
    aws_secret_access_key = aws_iam_access_key.user_key.secret
    aws_account_id        = data.aws_caller_identity.current.account_id
    aws_region            = var.aws_region
  }
}

resource "null_resource" "env-file" {

  triggers = {
    everytime = uuid()
  }

  provisioner "local-exec" {
    command = "scripts/env-file.sh .env AWS_ACCOUNT_ID AWS_REGION ECR_REPO_PUBLIC ECR_REPO_PRIVATE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"

    working_dir = local.project_dir

    environment = {
      AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
      AWS_REGION     = var.aws_region
      # /!\ it is URI for public ECR
      ECR_REPO_PUBLIC = aws_ecrpublic_repository.ecr_repo_public.repository_uri
      # /!\ it is URL for private ECR
      ECR_REPO_PRIVATE      = aws_ecr_repository.ecr_repo_private.repository_url
      AWS_ACCESS_KEY_ID     = aws_iam_access_key.user_key.id
      AWS_SECRET_ACCESS_KEY = aws_iam_access_key.user_key.secret
    }
  }
}
