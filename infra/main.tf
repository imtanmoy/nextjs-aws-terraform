locals {
  target_port = 3000

  ecs_launch_type    = "FARGATE"
  ecs_desired_count  = 2
  ecs_network_mode   = "awsvpc"
  ecs_cpu            = 512
  ecs_memory         = 1024
  ecs_container_name = "nextjs-image"
  ecs_log_group      = "/aws/ecs/${var.name}-${var.env}"
  # Retention in days
  ecs_log_retention = 1
}


module "networking" {
  source = "./modules/networking"
  env    = var.env
  name   = var.name
  subnet_public_cidrblock = [
    "10.0.1.0/24", "10.0.2.0/24"
  ]
  subnet_private_cidrblock = [
    "10.0.11.0/24", "10.0.22.0/24"
  ]
  azs = ["ap-southeast-1a", "ap-southeast-1b"]
}

resource "aws_security_group" "alb_ecs_sg" {
  vpc_id = module.networking.vpc_id

  ## Allow inbound on port 80 from internet (all traffic)
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ## Allow outbound to ecs instances in private subnet
  egress {
    protocol    = "tcp"
    from_port   = local.target_port
    to_port     = local.target_port
    cidr_blocks = module.networking.private_subnets[*].cidr_block
  }
}

resource "aws_security_group" "ecs_sg" {
  vpc_id = module.networking.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = local.target_port
    to_port         = local.target_port
    security_groups = [aws_security_group.alb_ecs_sg.id]
  }

  ## Allow ECS service to reach out to internet (download packages, pull images etc)
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "ecs_tg" {
  source              = "./modules/alb"
  create_target_group = true
  port                = local.target_port
  protocol            = "HTTP"
  ## This is important! *
  target_type = "ip"
  vpc_id      = module.networking.vpc_id
}

module "alb" {
  source             = "./modules/alb"
  create_alb         = true
  enable_https       = false
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_ecs_sg.id]
  subnets            = module.networking.public_subnets[*].id
  target_group       = module.ecs_tg.tg.arn
}

resource "aws_ecr_repository" "main" {
  name                 = "web/${var.name}/nextjs"
  image_tag_mutability = "MUTABLE"
}

module "ecr_ecs_ci_user" {
  source         = "./modules/iam/ecr"
  env            = var.env
  name           = var.name
  create_ci_user = true
  # This is the ECR ARN - Feel free to add other repository as required (if you want to re-use role for CI/CD in other projects)
  ecr_resource_arns = [
    "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/web/${var.name}",
    "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/web/${var.name}/*"
  ]
}


resource "aws_ecs_cluster" "web_cluster" {
  name = "web-cluster-${var.name}-${var.env}"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

module "ecs_roles" {
  source                    = "./modules/iam/ecs"
  create_ecs_execution_role = true
  create_ecs_task_role      = true

  # Extend baseline policy statements (ignore for now)
#  ecs_execution_policies_extension = {}
}

resource "aws_cloudwatch_log_group" "ecs" {
  name = local.ecs_log_group
  # This can be changed
  retention_in_days = local.ecs_log_retention
}

# Create a static version of task definition for CI/CD
resource "local_file" "output_task_def" {
  content         = data.template_file.task_def_generated.rendered
  file_permission = "644"
  filename        = "./task-definitions/service.latest.json"
}

resource "aws_ecs_task_definition" "nextjs" {
  family             = "task-definition-node"
  execution_role_arn = module.ecs_roles.ecs_execution_role_arn
  task_role_arn      = module.ecs_roles.ecs_task_role_arn

  requires_compatibilities = [local.ecs_launch_type]
  network_mode             = local.ecs_network_mode
  cpu                      = local.ecs_cpu
  memory                   = local.ecs_memory
  container_definitions = jsonencode(
    jsondecode(data.template_file.task_def_generated.rendered).containerDefinitions
  )
}


resource "aws_ecs_service" "web_ecs_service" {
  name            = "web-service-${var.name}-${var.env}"
  cluster         = aws_ecs_cluster.web_cluster.id
  task_definition = aws_ecs_task_definition.nextjs.arn
  desired_count   = local.ecs_desired_count
  launch_type     = local.ecs_launch_type

  load_balancer {
    target_group_arn = module.ecs_tg.tg.arn
    container_name   = local.ecs_container_name
    container_port   = local.target_port
  }

  network_configuration {
    subnets         = module.networking.private_subnets[*].id
    security_groups = [aws_security_group.ecs_sg.id]
  }

  tags = {
    Name = "${var.name}-${var.env}-ecs-service"
  }

  depends_on = [
    module.alb.lb,
    module.ecs_tg.tg
  ]
}
