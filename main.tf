data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }
  tags = {
    Tier = "public"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-southeast-1a", "ap-southeast-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_ecr_repository" "s3_app" {
  name                 = "${var.name}-s3-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    name    = "${var.name}-s3-app"
    Project = "Coaching_18"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecr_repository" "sqs_app" {
  name                 = "${var.name}-sqs-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags = {
    name    = "${var.name}-sns-app"
    Project = "Coaching_18"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ecs_sg" {
  name_prefix = "${var.name}-ecs-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5002
    to_port     = 5002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "ecs" {
  source       = "terraform-aws-modules/ecs/aws"
  version      = "~> 5.12.0"
  cluster_name = "${var.name}-cluster"
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    "${var.name}-s3-service" = {
      cpu    = 512
      memory = 1024

      task_role_arn = aws_iam_role.ecs_task_role.arn

      container_definitions = {
        s3-container = {
          essential = true
          image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com/${aws_ecr_repository.s3_app.name}:latest"
          name      = "${var.name}-s3-container"
          port_mappings = [
            {
              containerPort = 5001
              protocol      = "tcp"
            }
          ]
          environment = [
            {
              name  = "BUCKET_NAME"
              value = aws_s3_bucket.app_bucket.bucket
            },
            {
              name  = "AWS_REGION"
              value = data.aws_region.current.id
            }
          ]
        }
      }

      desired_count                        = 1
      service_type                         = "REPLICA"
      availability_zone_rebalance_strategy = "SPREAD"
      assign_public_ip                     = true
      deployment_minimum_healthy_percent   = 100
      subnet_ids                           = data.aws_subnets.public.ids
      security_group_ids                   = [aws_security_group.ecs_sg.id]


    }

    "${var.name}-sqs-service" = {
      cpu    = 512
      memory = 1024

      task_role_arn = aws_iam_role.ecs_task_role.arn

      container_definitions = {
        sqs-container = {
          essential = true
          image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com/${aws_ecr_repository.sqs_app.name}:latest"
          name      = "${var.name}-sqs-container"
          port_mappings = [
            {
              containerPort = 5002
              protocol      = "tcp"
            }
          ]
          environment = [
            {
              name  = "QUEUE_URL"
              value = aws_sqs_queue.app_queue.url
            },
            {
              name  = "AWS_REGION"
              value = data.aws_region.current.id
            }
          ]
        }
      }

      desired_count                        = 1
      service_type                         = "REPLICA"
      availability_zone_rebalance_strategy = "SPREAD"
      assign_public_ip                     = true
      deployment_minimum_healthy_percent   = 100
      subnet_ids                           = data.aws_subnets.public.ids
      security_group_ids                   = [aws_security_group.ecs_sg.id]
    }
  }
}

# resource "aws_iam_role" "ecs_task_execution_role" {
#   name = "${var.name}-ecs-task-execution-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "ecs-tasks.amazonaws.com"
#       }
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.name}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.name}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_bucket.arn,
          "${aws_s3_bucket.app_bucket.arn}/*"
        ]
      },

      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.app_queue.arn
      }
    ]
  })
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "${var.name}-s3-app-bucket"
}

resource "aws_sqs_queue" "app_queue" {
  name = "${var.name}-sqs-app-queue"
}

