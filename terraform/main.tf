# # ECR Repository
# resource "aws_ecr_repository" "nestjs_app" {
#   name                 = var.ecr_repository_name
#   image_tag_mutability = "MUTABLE"

#   image_scanning_configuration {
#     scan_on_push = true
#   }
# }

# # ECS Cluster
# resource "aws_ecs_cluster" "nestjs_cluster" {
#   name = "${var.cluster_name}-${var.environment}"

#   setting {
#     name  = "containerInsights"
#     value = "enabled"
#   }
# }

# # Get latest ECS-optimized AMI
# data "aws_ami" "ecs_optimized" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

# # ECS Task Definition
# resource "aws_ecs_task_definition" "nestjs_task" {
#   family                   = "${var.task_family}-${var.environment}"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["EC2"]
#   cpu                      = var.task_cpu
#   memory                   = var.task_memory
#   execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
#   task_role_arn            = aws_iam_role.ecs_task_role.arn

#   container_definitions = jsonencode([{
#     name      = var.container_name
#     image     = "${aws_ecr_repository.nestjs_app.repository_url}:latest"
#     cpu       = var.task_cpu
#     memory    = var.task_memory
#     essential = true

#     portMappings = [
#       {
#         containerPort = var.container_port
#         hostPort      = var.container_port
#         protocol      = "tcp"
#       }
#     ]

#     environment = [
#       {
#         name  = "NODE_ENV"
#         value = var.environment
#       }
#     ]

#     logConfiguration = {
#       logDriver = "awslogs"
#       options = {
#         awslogs-group         = aws_cloudwatch_log_group.nestjs_app.name
#         awslogs-region        = var.aws_region
#         awslogs-stream-prefix = "ecs"
#       }
#     }
#   }])
# }

# # ECS Service
# resource "aws_ecs_service" "nestjs_service" {
#   name            = "${var.service_name}-${var.environment}"
#   cluster         = aws_ecs_cluster.nestjs_cluster.id
#   task_definition = aws_ecs_task_definition.nestjs_task.arn
#   desired_count   = var.desired_count
#   launch_type     = "EC2"
  
#   # CRITICAL: Give containers time to start
#   health_check_grace_period_seconds = 300

#   network_configuration {
#     subnets          = aws_subnet.private[*].id
#     security_groups  = [aws_security_group.ecs_tasks.id]
#     assign_public_ip = false
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.nestjs_tg.arn
#     container_name   = var.container_name
#     container_port   = var.container_port
#   }

#   depends_on = [aws_lb_listener.nestjs_listener]
# }

# # IAM Roles
# resource "aws_iam_role" "ecs_task_execution_role" {
#   name = "${var.environment}-ecs-task-execution-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# resource "aws_iam_role" "ecs_task_role" {
#   name = "${var.environment}-ecs-task-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# # CloudWatch Log Group
# resource "aws_cloudwatch_log_group" "nestjs_app" {
#   name              = "/ecs/${var.task_family}-${var.environment}"
#   retention_in_days = 14
# }

# # ECS AutoScaling Group
# resource "aws_autoscaling_group" "ecs_cluster" {
#   name                      = "${var.cluster_name}-asg-${var.environment}"
#   vpc_zone_identifier       = aws_subnet.private[*].id
#   min_size                  = var.min_size
#   max_size                  = var.max_size
#   desired_capacity          = var.desired_capacity
#   health_check_type         = "EC2"
#   health_check_grace_period = 300
#   protect_from_scale_in     = false

#   launch_template {
#     id      = aws_launch_template.ecs_ec2.id
#     version = "$Latest"
#   }

#   tag {
#     key                 = "Name"
#     value               = "${var.cluster_name}-instance"
#     propagate_at_launch = true
#   }
# }

# # Launch Template
# resource "aws_launch_template" "ecs_ec2" {
#   name_prefix   = "${var.cluster_name}-${var.environment}-"
#   image_id      = data.aws_ami.ecs_optimized.id
#   instance_type = var.instance_type
#   key_name      = var.key_name

#   iam_instance_profile {
#     name = aws_iam_instance_profile.ecs_ec2_instance_profile.name
#   }

#   network_interfaces {
#     associate_public_ip_address = false
#     security_groups             = [aws_security_group.ec2_instance.id]
#   }

#   user_data = base64encode(templatefile("${path.module}/user-data.sh", {
#     cluster_name = aws_ecs_cluster.nestjs_cluster.name
#   }))

#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name        = "${var.cluster_name}-instance"
#       Environment = var.environment
#     }
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # IAM for EC2
# resource "aws_iam_instance_profile" "ecs_ec2_instance_profile" {
#   name = "${var.environment}-ecs-instance-profile"
#   role = aws_iam_role.ecs_ec2_role.name
# }

# resource "aws_iam_role" "ecs_ec2_role" {
#   name = "${var.environment}-ecs-ec2-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecs_ec2_role_policy" {
#   role       = aws_iam_role.ecs_ec2_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }

# # VPC
# resource "aws_vpc" "main" {
#   cidr_block           = var.vpc_cidr
#   enable_dns_hostnames = true
#   enable_dns_support   = true
# }

# # Subnets
# resource "aws_subnet" "private" {
#   count             = length(var.private_subnets)
#   vpc_id            = aws_vpc.main.id
#   cidr_block        = var.private_subnets[count.index]
#   availability_zone = element(var.availability_zones, count.index)
# }

# resource "aws_subnet" "public" {
#   count                   = length(var.public_subnets)
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = var.public_subnets[count.index]
#   availability_zone       = element(var.availability_zones, count.index)
#   map_public_ip_on_launch = true
# }

# # Internet Gateway
# resource "aws_internet_gateway" "main" {
#   vpc_id = aws_vpc.main.id
# }

# # NAT Gateway
# resource "aws_eip" "nat" {
#   count  = length(var.public_subnets)
#   domain = "vpc"
# }

# resource "aws_nat_gateway" "main" {
#   count         = length(var.public_subnets)
#   allocation_id = aws_eip.nat[count.index].id
#   subnet_id     = aws_subnet.public[count.index].id

#   depends_on = [aws_internet_gateway.main]
# }

# # Route Tables
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.main.id
#   }
# }

# resource "aws_route_table" "private" {
#   count  = length(var.private_subnets)
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.main[count.index].id
#   }
# }

# # Route Table Associations
# resource "aws_route_table_association" "public" {
#   count          = length(var.public_subnets)
#   subnet_id      = aws_subnet.public[count.index].id
#   route_table_id = aws_route_table.public.id
# }

# resource "aws_route_table_association" "private" {
#   count          = length(var.private_subnets)
#   subnet_id      = aws_subnet.private[count.index].id
#   route_table_id = aws_route_table.private[count.index].id
# }

# # Load Balancer
# resource "aws_lb" "nestjs_alb" {
#   name               = "${var.environment}-nestjs-alb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb.id]
#   subnets            = aws_subnet.public[*].id
# }

# resource "aws_lb_target_group" "nestjs_tg" {
#   name        = "${var.environment}-nestjs-tg"
#   port        = 80
#   protocol    = "HTTP"
#   vpc_id      = aws_vpc.main.id
#   target_type = "ip"

#   health_check {
#     healthy_threshold   = 2
#     unhealthy_threshold = 5
#     timeout             = 10
#     path                = "/"
#     interval            = 60
#     matcher             = "200"
#   }
# }

# # ALB Listener
# resource "aws_lb_listener" "nestjs_listener" {
#   load_balancer_arn = aws_lb.nestjs_alb.arn
#   port              = "80"
#   protocol          = "HTTP"
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.nestjs_tg.arn
#   }
# }

# # Security Groups
# resource "aws_security_group" "alb" {
#   name        = "${var.environment}-alb-sg"
#   description = "Security group ALB"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# resource "aws_security_group" "ecs_tasks" {
#   name        = "${var.environment}-ecs-tasks-sg"
#   description = "Security group for ECS tasks"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port       = var.container_port
#     to_port         = var.container_port
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb.id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# resource "aws_security_group" "ec2_instance" {
#   name        = "${var.environment}-ec2-instance-sg"
#   description = "Security group for EC2 instances"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port   = var.container_port
#     to_port     = var.container_port
#     protocol    = "tcp"
#     cidr_blocks = [var.vpc_cidr]
#   }

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# output "ecr_repository_url" {
#   description = "ECR repository URL"
#   value       = aws_ecr_repository.nestjs_app.repository_url
# }

# output "load_balancer_dns" {
#   description = "Load Balancer DNS name"
#   value       = aws_lb.nestjs_alb.dns_name
# }

# output "cluster_name" {
#   description = "ECS cluster name"
#   value       = aws_ecs_cluster.nestjs_cluster.name
# }

# output "service_name" {
#   description = "ECS service name"
#   value       = aws_ecs_service.nestjs_service.name
# }