terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Project = "character_register"
    }
  }
}

########################
# VPC
########################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = false
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.main]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = "10.0.11.0/24"
  map_public_ip_on_launch = false
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = aws_vpc.main.cidr_block
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = aws_vpc.main.cidr_block
    gateway_id = "local"
  }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
}

resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private.id
}

########################
# Security Groups
########################

resource "aws_security_group" "allow_outbound" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "allow_outbound"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_ipv4" {
  security_group_id = aws_security_group.allow_outbound.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "k8s_master" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "k8s_master"
  }
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api_workers" {
  security_group_id            = aws_security_group.k8s_master.id
  referenced_security_group_id = aws_security_group.k8s_worker.id
  from_port                    = 6443
  ip_protocol                  = "tcp"
  to_port                      = 6443
  description                  = "K8s API server on master node from worker nodes"
}

# Typha is like a central proxy between the API server and Felix
# Felix is Calicos replacement for kube-proxy
resource "aws_vpc_security_group_ingress_rule" "k8s_master_calico_typha" {
  security_group_id            = aws_security_group.k8s_master.id
  referenced_security_group_id = aws_security_group.k8s_worker.id
  from_port                    = 5473
  ip_protocol                  = "tcp"
  to_port                      = 5473
  description                  = "Calico networking using Typha"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_master_dns_udp" {
  security_group_id            = aws_security_group.k8s_master.id
  referenced_security_group_id = aws_security_group.k8s_worker.id
  from_port                    = 53
  ip_protocol                  = "udp"
  to_port                      = 53
  description                  = "CoreDNS"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_master_dns_tcp" {
  security_group_id            = aws_security_group.k8s_master.id
  referenced_security_group_id = aws_security_group.k8s_worker.id
  from_port                    = 53
  ip_protocol                  = "tcp"
  to_port                      = 53
  description                  = "CoreDNS"
}

resource "aws_security_group" "k8s_worker" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "k8s_worker"
  }
}

resource "aws_vpc_security_group_ingress_rule" "k8s_kubelet" {
  security_group_id            = aws_security_group.k8s_worker.id
  referenced_security_group_id = aws_security_group.k8s_master.id
  from_port                    = 10250
  ip_protocol                  = "tcp"
  to_port                      = 10250
  description                  = "K8s Kubelet on worker node"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_worker_mysql" {
  security_group_id            = aws_security_group.k8s_worker.id
  referenced_security_group_id = aws_security_group.k8s_worker.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
  description                  = "mysql"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_worker_flask" {
  security_group_id            = aws_security_group.k8s_worker.id
  referenced_security_group_id = aws_security_group.nlb_flask.id
  from_port                    = var.flask_nodeport
  ip_protocol                  = "tcp"
  to_port                      = var.flask_nodeport
  description                  = "flask"
}

# Sounds crazy from security perspective but this is best practice per AWS and
# is alot easier than sorting it all out with SGs
# Seems NetworkPolicies are used to further restrict traffic - consider doing
# that to improve security at the k8s level
resource "aws_vpc_security_group_ingress_rule" "k8s_worker_internode" {
  security_group_id            = aws_security_group.k8s_worker.id
  referenced_security_group_id = aws_security_group.k8s_worker.id
  ip_protocol                  = "-1"
  description                  = "All traffic between worker nodes"
}

resource "aws_iam_role" "ec2_ssm" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

########################
# EC2 Instances
########################

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2_ssm.name
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  role = aws_iam_role.ec2_ssm.name
}

data "aws_ami" "debian" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-11-amd64-*"]
  }

  owners = ["679593333241"] # Debian
}

resource "aws_instance" "k8s_worker" {
  count = var.worker_count

  ami                  = data.aws_ami.debian.id
  instance_type        = var.ec2_type
  subnet_id            = aws_subnet.private.id
  key_name             = var.ec2_key_pair == "" ? null : var.ec2_key_pair
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm.name
  depends_on           = [aws_nat_gateway.ngw]
  # For Calico networking - NAT
  source_dest_check = false
  vpc_security_group_ids = [
    aws_security_group.allow_outbound.id,
    aws_security_group.k8s_worker.id
  ]

  tags = {
    Name = "k8s-worker${count.index}"
  }

  metadata_options {
    # make the instance tags available to metadata
    instance_metadata_tags = "enabled"
  }

  user_data = filebase64("userdata_base.tpl")
}

resource "aws_instance" "k8s_master" {
  ami                  = data.aws_ami.debian.id
  instance_type        = var.ec2_type
  subnet_id            = aws_subnet.private.id
  key_name             = var.ec2_key_pair == "" ? null : var.ec2_key_pair
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm.name
  # For Calico networking - NAT
  source_dest_check = false
  vpc_security_group_ids = [
    aws_security_group.allow_outbound.id,
    aws_security_group.k8s_master.id
  ]

  tags = {
    Name = "k8s-master"
  }

  metadata_options {
    instance_metadata_tags = "enabled"
  }

  # combines the base script for all nodes with the script just for the master
  # The "%s%s" converts both files into strings and concatenates em
  user_data = base64encode(format("%s%s", file("userdata_base.tpl"), templatefile("userdata_master.tpl", { pod_network_cidr = var.pod_network_cidr })))
}

########################
# Load Balancer
########################

# TODO: Look into creating the LBs with a k8s addon like aws-load-balancer-controller
# so LBs can be managed w/ k8s

resource "aws_security_group" "nlb_flask" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "default"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_flask_ingress" {
  security_group_id = aws_security_group.nlb_flask.id
  cidr_ipv4         = var.allowed_cidr
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  description       = "Inbound flask API"
}

resource "aws_lb_target_group" "flask" {
  port     = var.flask_nodeport
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    interval          = 30
    healthy_threshold = 2
    path              = "/healthcheck"
    port              = "traffic-port"
    protocol          = "HTTP"
  }
}

resource "aws_lb_target_group_attachment" "flask" {
  count            = var.worker_count
  target_group_arn = aws_lb_target_group.flask.arn
  target_id        = aws_instance.k8s_worker[count.index].id
}

resource "aws_lb" "flask" {
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public.id]
  security_groups    = [aws_security_group.allow_outbound.id, aws_security_group.nlb_flask.id]

  tags = {
    Name = "flask_nlb"
  }
}

resource "aws_lb_listener" "flask" {
  load_balancer_arn = aws_lb.flask.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask.arn
  }
}
