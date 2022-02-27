data "template_file" "task_def_generated" {
  template = file("./task-definitions/service.json.tpl")
  vars = {
    env                = var.env
    port               = local.target_port
    name               = local.ecs_container_name
    cpu                = local.ecs_cpu
    memory             = local.ecs_memory
    aws_region         = var.region
    ecs_execution_role = module.ecs_roles.ecs_execution_role_arn
    launch_type        = local.ecs_launch_type
    network_mode       = local.ecs_network_mode
    log_group          = local.ecs_log_group
  }
}