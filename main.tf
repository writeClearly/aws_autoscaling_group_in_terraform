# Creates AutoscalingGroup from own AMI with custom VPC, acecssible from outside over HTTP/SSH via loadbalancer for two availability zones
provider "aws" {
    region  =   "eu-north-1"
}
resource "aws_vpc" "custom"{
    cidr_block              = "10.0.0.0/16"
    enable_dns_support      = "true"
    enable_dns_hostnames    = "true"
    tags                    = {Name = "Terraform VPC"}
}

resource "aws_internet_gateway" "vpc_gw"{
    vpc_id              = aws_vpc.custom.id
    tags                = {Name = "terraform-gateway"}
}

resource "aws_subnet" "stockholm_a"{
    vpc_id                  = aws_vpc.custom.id
    cidr_block              = "10.0.192.0/18"
    availability_zone       = "eu-north-1a"
    map_public_ip_on_launch = "true" #make the subnet public
}

resource "aws_subnet" "stockholm_b" {
    vpc_id                  = aws_vpc.custom.id
    cidr_block              = "10.0.128.0/18"
    availability_zone       = "eu-north-1b"
    map_public_ip_on_launch = "true"
}

resource "aws_route_table" "route_table" {
    vpc_id          =   aws_vpc.custom.id
    route {
        cidr_block  =   "0.0.0.0/0"
        gateway_id  =   aws_internet_gateway.vpc_gw.id
    }
    tags = {
        Name        =   "TerraformRouteTable"
    }
}

resource "aws_route_table_association" "a" {
    subnet_id               = aws_subnet.stockholm_a.id
    route_table_id          = aws_route_table.route_table.id
}

resource "aws_route_table_association" "b" {
    subnet_id               = aws_subnet.stockholm_b.id
    route_table_id          = aws_route_table.route_table.id
}

resource "aws_security_group" "terraform_ssh_http" {
    name            = "Terraform_ssh_http_open"
    vpc_id          = aws_vpc.custom.id
    ingress {
        description =   "SSH opened for all IPs"
        from_port   =   22
        to_port     =   22
        protocol    =   "tcp"
        cidr_blocks =   ["0.0.0.0/0"]
    }
    ingress {
        description =   "HTTP opened for all IPs"
        from_port   =   80
        to_port     =   80
        protocol    =   "tcp"
        cidr_blocks =   ["0.0.0.0/0"]
    }
    egress {
        description =   "All ports opened for all IPs to outcoming traffic"
        from_port   =   0
        to_port     =   0
        protocol    =   "-1"
        cidr_blocks =   ["0.0.0.0/0"]
    }
}
resource "aws_key_pair" "auth" {
  key_name = "my_ssh_pubkey"
  public_key = file("/home/YOURUSER/.ssh/YOUR_SSH_ALGORITHM.pub") #Example PATH to your public ssh key
}

resource "aws_launch_template" "terraformQuoteTemplate" {
    name                    =   "TerraformLaunchTemplate"
    block_device_mappings {
        device_name = "/dev/sda1"
        ebs {
            volume_type             = "gp2"
            volume_size             = 8
            delete_on_termination   = true
        }
    }
    image_id                =   "ami-XXXXXXXXXXXXX" #YOUR CUSTOM AMI number goes here
    instance_type           =   "t3.micro"
    key_name                =   aws_key_pair.auth.key_name

    network_interfaces {
        associate_public_ip_address = true
        security_groups  =   [aws_security_group.terraform_ssh_http.id]
    }
}
resource "aws_lb" "terraform_lb" {
    name                    = "terraformLoadBalancer"
    internal                = false
    load_balancer_type      = "application"
    security_groups         = [aws_security_group.terraform_ssh_http.id]
    subnets                 = [aws_subnet.stockholm_a.id, aws_subnet.stockholm_b.id]
}

resource "aws_lb_target_group" "terraform_target_group" {
    name        =   "TerraformTargetGroup"
    port        =   80
    protocol    =   "HTTP"
    vpc_id      =   aws_vpc.custom.id
}

resource "aws_lb_listener" "lb_listener" {
    load_balancer_arn       = aws_lb.terraform_lb.arn
    port                    = 80
    protocol                = "HTTP"

    default_action {
        target_group_arn    = aws_lb_target_group.terraform_target_group.arn
        type                = "forward"
    }
}

resource "aws_autoscaling_group" "terraform_asg" {
    name                    =   "TerraformAutoscalingGroup"
    max_size                =   2
    min_size                =   1
    desired_capacity        =   2
    target_group_arns       =   [aws_lb_target_group.terraform_target_group.arn]
    vpc_zone_identifier     =   [aws_subnet.stockholm_a.id, aws_subnet.stockholm_b.id]
    launch_template {
        id      =   aws_launch_template.terraformQuoteTemplate.id
        version =   "$Latest"
    }
}