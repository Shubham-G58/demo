provider "aws" {
  region = "us-east-1"
}

##########################
# 1. Networking
##########################
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}
 resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
   cidr_block              = "10.0.4.0/24"
   availability_zone       = "us-east-1b"        # different AZ than public_a
   map_public_ip_on_launch = true
 }

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

##########################
# 2. Security Groups
##########################
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["27.107.32.226/32"]  # Change this
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
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

##########################
# 3. Bastion Host (Public)
##########################
resource "aws_instance" "bastion" {
  ami                    = "ami-0c101f26f147fa7fd" # Amazon Linux 2 (us-east-1)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = "bastion" # Replace with your key

  tags = {
    Name = "BastionHost"
  }
}

##########################
# 4. Private App Server
##########################
resource "aws_instance" "app" {
  ami                         = "ami-0c101f26f147fa7fd"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_1.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = false
  key_name                    = "your-key-name"

  user_data = <<-EOF
              #!/bin/bash
              sudo yum install -y httpd
              echo "Hello from private app instance!" > /var/www/html/index.html
              sudo systemctl enable httpd
              sudo systemctl start httpd
              EOF

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "AppServer"
  }
}

##########################
# 5. Application Load Balancer
##########################
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id,aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "app_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app.id
  port             = 80
}




# ######################################################################################fargate###########################
# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# provider "aws" {
#   region = "us-east-1"
# }


# #resource "aws_instance" "demo" {
#  # ami           = "ami-0c94855ba95c71c99"
#   #instance_type = "t2.micro"

#   #tags = {
#    # Name = "demo-instance"
#   #}
# #}


# resource "aws_vpc" "main" {
#   cidr_block = "10.0.0.0/16"
#   enable_dns_hostnames = true
# }
# #######network_componenets#####
# resource "aws_subnet" "public_a" {
#   vpc_id     = aws_vpc.main.id
#   cidr_block = "10.0.1.0/24"
#   availability_zone = "us-east-1a"
#   map_public_ip_on_launch = true
# }
# resource "aws_subnet" "public_b" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.2.0/24"
#   availability_zone       = "us-east-1b"        # different AZ than public_a
#   map_public_ip_on_launch = true
# }

# resource "aws_internet_gateway" "gw" {
#   vpc_id = aws_vpc.main.id
# }

# resource "aws_route_table" "rt" {
#   vpc_id = aws_vpc.main.id
# }

# resource "aws_route" "internet_access" {
#   route_table_id         = aws_route_table.rt.id
#   destination_cidr_block = "0.0.0.0/0"
#   gateway_id             = aws_internet_gateway.gw.id
# }

# resource "aws_route_table_association" "a" {
#   subnet_id      = aws_subnet.public_a.id
#   route_table_id = aws_route_table.rt.id
# }

# ############cluster#######
# resource "aws_ecs_cluster" "app_cluster" {
#   name = "my-fargate-cluster"
# }
# ######alb #######
# resource "aws_lb" "app_lb" {
#   name               = "app-alb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.lb_sg.id]
#   subnets            = [aws_subnet.public_a.id,aws_subnet.public_b.id]
# }

# resource "aws_lb_target_group" "app_tg" {
#   name     = "app-tg"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.main.id
#   target_type = "ip"
# }

# resource "aws_lb_listener" "app_listener" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# }
# ########iam role #########
# resource "aws_iam_role" "ecs_task_exec_role" {
#   name = "ecsTaskExecutionRole"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action = "sts:AssumeRole",
#       Principal = {
#         Service = "ecs-tasks.amazonaws.com"
#       },
#       Effect = "Allow",
#       Sid    = ""
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
#   role       = aws_iam_role.ecs_task_exec_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }
# #######task definiton##########
# resource "aws_ecs_task_definition" "app_task" {
#   family                   = "my-app-task"
#   requires_compatibilities = ["FARGATE"]
#   network_mode             = "awsvpc"
#   cpu                      = "256"
#   memory                   = "512"
#   execution_role_arn       = aws_iam_role.ecs_task_exec_role.arn

#   container_definitions = jsonencode([{
#     name      = "my-app"
#     image     = "nginx"  # Or your ECR image
#     portMappings = [{
#       containerPort = 80
#       hostPort      = 80
#     }]
#   }])
# }
# ############ecs service#####
# resource "aws_ecs_service" "app_service" {
#   name            = "my-app-service"
#   cluster         = aws_ecs_cluster.app_cluster.id
#   task_definition = aws_ecs_task_definition.app_task.arn
#   launch_type     = "FARGATE"
#   desired_count   = 1

#   network_configuration {
#     subnets         = [aws_subnet.public_a.id]
#     assign_public_ip = true
#     security_groups = [aws_security_group.ecs_service_sg.id]
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.app_tg.arn
#     container_name   = "my-app"
#     container_port   = 80
#   }

#   depends_on = [aws_lb_listener.app_listener]
# }
# ##############sg#############
# resource "aws_security_group" "lb_sg" {
#   vpc_id = aws_vpc.main.id
#   name   = "alb-sg"

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

# resource "aws_security_group" "ecs_service_sg" {
#   vpc_id = aws_vpc.main.id
#   name   = "ecs-service-sg"

#   ingress {
#     from_port       = 80
#     to_port         = 80
#     protocol        = "tcp"
#     security_groups = [aws_security_group.lb_sg.id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
