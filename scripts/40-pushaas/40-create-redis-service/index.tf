########################################
# variables
########################################
# common - general
variable "aws_region" {}
variable "aws_az" {} # unused
variable "aws_profile" {}
variable "aws_credentials_file" {}

# common - pushaas
variable "pushaas_redis_count" {}
variable "pushaas_redis_image" {}
variable "pushaas_redis_port" {}
variable "pushaas_redis_fargate_cpu" {}
variable "pushaas_redis_fargate_memory" {}

# specific
variable "vpc_id" {}
variable "cluster_id" {}
variable "namespace_id" {}
variable "subnet_id" {}

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
# network
########################################
data "aws_vpc" "tsuru-vpc" {
  id = "${var.vpc_id}"
}

########################################
# roles
########################################
data "aws_iam_role" "task_execution_role" {
  name = "ecsTaskExecutionRole"
}

########################################
# ecs
########################################
resource "aws_ecs_task_definition" "pushaas-redis" {
  family                   = "pushaas-redis"
  execution_role_arn       = "${data.aws_iam_role.task_execution_role.arn}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.pushaas_redis_fargate_cpu}"
  memory                   = "${var.pushaas_redis_fargate_memory}"

  container_definitions = <<DEFINITION
[
  {
    "cpu": ${var.pushaas_redis_fargate_cpu},
    "image": "${var.pushaas_redis_image}",
    "memoryReservation": ${var.pushaas_redis_fargate_memory},
    "name": "pushaas-redis",
    "networkMode": "awsvpc",
    "entryPoint": [],
    "command": [],
    "links": [],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/pushaas",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "ecs"
        }
    },
    "portMappings": [
      {
        "containerPort": ${var.pushaas_redis_port},
        "hostPort": ${var.pushaas_redis_port}
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_service" "pushaas-redis" {
  name            = "pushaas-redis-service"
  cluster         = "${var.cluster_id}"
  task_definition = "${aws_ecs_task_definition.pushaas-redis.arn}"
  desired_count   = "${var.pushaas_redis_count}"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = ["${aws_security_group.pushaas-redis-sg.id}"]
    subnets          = ["${var.subnet_id}"]
    # TODO remove public ip
    assign_public_ip = true
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.pushaas-redis-service.arn}"
  }
}

########################################
# security
########################################
resource "aws_security_group" "pushaas-redis-sg" {
  name        = "pushaas-redis-security-group"
  description = "controls access to the pushaas redis"
  vpc_id      = "${data.aws_vpc.tsuru-vpc.id}"

  ingress {
    from_port = 0
    protocol  = "tcp"
    self      = true
    to_port   = 65535
  }

  // thanks https://blog.jwr.io/terraform/icmp/ping/security/groups/2018/02/02/terraform-icmp-rules.html
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = -1
    protocol = "icmp"
    to_port = -1
  }

  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port   = 0
    protocol    = "tcp"
    to_port     = 65535
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  tags = {
    Name = "pushaas"
  }
}

########################################
# dns
########################################
resource "aws_service_discovery_service" "pushaas-redis-service" {
  name = "pushaas-redis"

  dns_config {
    namespace_id = "${var.namespace_id}"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
