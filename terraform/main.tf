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


resource "aws_ecs_task_definition" "my_python_task" { # Changed name for clarity
  family = "my-python-task" # Naming it clearly

  # --- FARGATE REQUIRED SETTINGS ---
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  # --- CONTAINER DEFINITION ---
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

# 3. Update the Service to look at the RESOURCE, not the data
resource "aws_ecs_service" "my_python_service" {
  name            = "my-python-service"
  cluster         = aws_ecs_cluster.my-python-cluster.id # Ensure this matches your cluster resource name
  task_definition = aws_ecs_task_definition.my_python_task.arn # Direct reference to the resource above
  desired_count   = 1
  launch_type     = "FARGATE"

  # We need network configuration for Fargate!
  network_configuration {
    subnets          = data.aws_subnets.default.ids # We will fix this next!
    assign_public_ip = true
  }
}

resource "null_resource" "docker_build_push" {
  # This trigger forces the resource to run every time you apply, 
  # ensuring your code changes are always built and pushed.
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOF
      # 1. Log in to ECR
      aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.my-python-repo.repository_url}
      
      # 2. Build the image
      docker build -t ${aws_ecr_repository.my-python-repo.repository_url}:latest ../
      
      # 3. Push the image
      docker push ${aws_ecr_repository.my-python-repo.repository_url}:latest
    EOF
  }
}

# 1. Find the Default VPC
data "aws_vpc" "default" {
  default = true
}

# 2. Find the Subnets inside that VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id] # Hint: Reference the ID of the VPC we just found above!
  }
}

# 1. Create the Role (The "ID Badge")
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "my-python-app-execution-role"
 
  # The "Trust Policy" - Who can wear this badge? (ECS Tasks)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Attach the Policy (The "Key Ring")
# This gives the role permission to pull images from ECR and write logs
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_codestarconnections_connection" "github-connection" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # Hint: It follows the pattern servicename.amazonaws.com
          Service = "codebuild.amazonaws.com" 
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # 1. CloudWatch Logs (So we can see the build logs)
        Effect = "Allow"
        Resource = "*"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      },
      {
        # 2. S3 (To get the code artifacts from the Pipeline)
        Effect = "Allow"
        Resource = "*"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ]
      },
      {
        # 3. ECR (To Push the Docker Image)
        Effect = "Allow"
        Resource = "*"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
      }
    ]
  })
}

resource "aws_codebuild_project" "project-using-github-app" {
  name         = "project-using-github-app"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode = true
  }

  source {
    type     = "CODEPIPELINE"

  }
}




resource "aws_s3_bucket" "s3-Pipeline" {
  bucket = "s3-pipeline-ahmad-908"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # 1. S3 Permission (Artifacts)
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.s3-Pipeline.arn,
          "${aws_s3_bucket.s3-Pipeline.arn}/*"
        ]
      },
      {
        # 2. CodeBuild Permission (Build Project)
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*" 
      },
      {
        # 3. Connection Permission (GitHub)
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = aws_codestarconnections_connection.github-connection.arn
      },
      {
        # 4. ECS Permission (Deploy Stage) --- THIS IS NEW! ---
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        # 5. IAM PassRole (Required to assign the execution role to the new task)
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_codepipeline" "codepipeline" {
  name     = "github-pipeline"
  
  # CHANGE 1: referencing the specific Pipeline Role we created earlier
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.s3-Pipeline.bucket
    type     = "S3"

    # CHANGE 2: Removed the "encryption_key" block. 
    # This allows it to use the default S3 encryption, which is easier 
    # than setting up a custom KMS key right now.
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        # CHANGE 3: Referenced your specific GitHub connection resource
        ConnectionArn    = aws_codestarconnections_connection.github-connection.arn
        
        # NOTE: Make sure these match your actual GitHub details!
        FullRepositoryId = "ahmadamjadd/aws-devops-practice-project" 
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        # CHANGE 4: Referenced your actual CodeBuild project name dynamically
        ProjectName = aws_codebuild_project.project-using-github-app.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      
      # CHANGE 5: Switched Provider from "CloudFormation" to "ECS"
      provider        = "ECS"
      
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        # CHANGE 6: Pointed to your specific ECS Cluster and Service
        ClusterName = aws_ecs_cluster.my-python-cluster.name
        ServiceName = aws_ecs_service.my_python_service.name
        
        # CHANGE 7: This tells ECS where to find the image details.
        # Your buildspec.yml needs to create this file!
        FileName    = "imagedefinitions.json"
      }
    }
  }
}   