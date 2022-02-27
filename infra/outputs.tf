output "ecr_repo_url" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "ecr_repo_path" {
  value = aws_ecr_repository.main.name
}

output "aws_region" {
  value = var.region
}

output "aws_iam_access_id" {
  value = module.ecr_ecs_ci_user.aws_iam_access_id
}

output "aws_iam_access_key" {
  value = module.ecr_ecs_ci_user.aws_iam_access_key
}
