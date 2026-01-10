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

resource "aws_ecs_task_definition" "my_python_task" {
  family                   = "my-python-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = <<DEFINITION
[
  {
    "name": "my-python-container",
    "image": "${aws_ecr_repository.my-python-repo.repository_url}:latest",
    "essential": true,
    "memory": 512,
    "cpu": 256
  }
]
DEFINITION
}

resource "aws_ecs_service" "my_python_service" {
  name            = "my-python-service"
  cluster         = aws_ecs_cluster.my-python-cluster.id
  task_definition = aws_ecs_task_definition.my_python_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = true
  }
}

# Helper resource to push the image initially
resource "null_resource" "docker_build_push" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = <<EOF
      aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.my-python-repo.repository_url}
      docker build -t ${aws_ecr_repository.my-python-repo.repository_url}:latest ../
      docker push ${aws_ecr_repository.my-python-repo.repository_url}:latest
    EOF
  }
}