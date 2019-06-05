########################################
# variables
########################################
# common - general
variable "aws_region" {}
variable "aws_az" {} # unused
variable "aws_profile" {}
variable "aws_credentials_file" {}

# common - pushaas
variable "pushaas_mongo_count" {}
variable "pushaas_mongo_image" {} # unused
variable "pushaas_mongo_port" {} # unused
variable "pushaas_mongo_fargate_cpu" {} # unused
variable "pushaas_mongo_fargate_memory" {} # unused

# specific
variable "subnet_id" {}
variable "cluster_id" {}
variable "sg_pushaas_id" {}
variable "task_pushaas_mongo_arn" {}
variable "service_pushaas_mongo_arn" {}

########################################
# provider
########################################
provider "aws" {
  version = "~> 2.7"
  profile                 = "${var.aws_profile}"
  region                  = "${var.aws_region}"
  shared_credentials_file = "${var.aws_credentials_file}"
}

########################################
# ecs
########################################
resource "aws_ecs_service" "pushaas-mongo" {
  name            = "pushaas-mongo-service"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.task_pushaas_mongo_arn}"
  desired_count   = "${var.pushaas_mongo_count}"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = ["${var.sg_pushaas_id}"]
    subnets          = ["${var.subnet_id}"]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = "${var.service_pushaas_mongo_arn}"
  }
}