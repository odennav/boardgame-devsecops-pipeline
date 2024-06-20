terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}

# AWS EC2 Instance Terraform Module
# SonarQube Host - EC2 Instance that will be created in VPC Private Subnet
module "ec2_sonar" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.6.0"
  
  name                   = "${var.sonar_node}"
  ami                    = data.aws_ami.ubuntu_22_04.id
  instance_type          = var.instance_type
  key_name               = var.instance_keypair
  subnet_id              = module.vpc.private_subnets[0]
  
  vpc_security_group_ids = [module.private_sg.security_group_id]
  tags = local.common_tags
  
}

