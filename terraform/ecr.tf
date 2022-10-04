# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecrpublic_repository
resource "aws_ecrpublic_repository" "ecr_repo_public" {
  provider        = aws.us_east_1
  repository_name = var.ecr_repo

  # /!\ this argument is not listed in the documentation
  # but can be found here : https://github.com/hashicorp/terraform-provider-aws/blob/3b94d69aa99b427965d01cacc7b8b01fdbcda8c9/internal/service/ecrpublic/repository_test.go#L451-L454
  force_destroy = true
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
resource "aws_ecr_repository" "ecr_repo_private" {
  name = var.ecr_repo

  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository#force_delete
  force_delete = true
}