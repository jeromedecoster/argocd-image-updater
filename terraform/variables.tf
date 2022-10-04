variable "project_name" {
  default = ""
}

variable "aws_region" {
  default = ""
}

variable "github_owner" {
  default = ""
}

variable "github_token" {
  default   = ""
  sensitive = true
}

variable "github_repo" {
  default = ""
}

variable "docker_image" {
  default = ""
}

variable "ecr_repo" {
  default = ""
}