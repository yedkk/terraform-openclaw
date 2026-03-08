locals {
  instance_type = (
    var.agent_count <= 1  ? "t3.small" :   # 2 GB
    var.agent_count <= 3  ? "t3.medium" :  # 4 GB
    var.agent_count <= 6  ? "t3.large" :   # 8 GB
    var.agent_count <= 10 ? "t3.xlarge" :  # 16 GB
    "t3.2xlarge"                           # 32 GB
  )
}

# --- SSH Key (auto-generated) ---

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "openclaw" {
  key_name_prefix = "openclaw-"
  public_key      = tls_private_key.ssh.public_key_openssh
}

# --- Auth Token ---

resource "random_id" "auth_token" {
  count       = var.agent_count
  byte_length = 32
}

# --- VPC ---

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "openclaw" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "openclaw" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "openclaw-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "openclaw-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Security Group ---

resource "aws_security_group" "openclaw" {
  name_prefix = "openclaw-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS - Agent 1 dashboard"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.agent_count > 1 ? [1] : []
    content {
      description = "HTTPS - Agent 2-${var.agent_count} dashboards"
      from_port   = 8002
      to_port     = 8000 + var.agent_count
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "openclaw" }
}

# --- EC2 Instance ---

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "openclaw" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.instance_type
  key_name               = aws_key_pair.openclaw.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.openclaw.id]

  user_data = templatefile("${path.module}/templates/cloud-init.sh.tpl", {
    agent_count = var.agent_count
    auth_tokens = random_id.auth_token[*].hex
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "openclaw" }
}

# --- Elastic IP ---

resource "aws_eip" "openclaw" {
  instance = aws_instance.openclaw.id
  domain   = "vpc"
  tags     = { Name = "openclaw" }
}
