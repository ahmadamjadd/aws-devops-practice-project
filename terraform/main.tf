terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}


resource "aws_ecr_repository" "my-python-repo" {
  name                 = "my-python-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "my-python-cluster" {
  name = "my-python-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Simply specify the family to find the latest ACTIVE revision in that family.
data "aws_ecs_task_definition" "python" {
  task_definition = aws_ecs_task_definition.python.family
}


resource "aws_ecs_task_definition" "python" {
  family = "python-devops"

  container_definitions = <<DEFINITION
[
  {
    "cpu": 256,
    "environment": [{
      "name": "SECRET",
      "value": "KEY"
    }],
    "essential": true,
    "image": "${aws_ecr_repository.my-python-repo.repository_url}:latest",
    "memory": 512,
    "memoryReservation": 64,
    "name": "mongodb"
  }
]
DEFINITION
}

resource "aws_ecs_service" "python-service" {
  name          = "python-service"
  cluster       = aws_ecs_cluster.python.id
  desired_count = 2

  # Track the latest ACTIVE revision
  task_definition = data.aws_ecs_task_definition.python.arn
}