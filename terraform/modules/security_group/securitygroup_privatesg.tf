terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}

# AWS EC2 Security Group Terraform Module
# Security Group for Private EC2 Instances
module "private_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name = "private-sg"
  description = "Security Group with HTTP & SSH port open for entire VPC Block (IPv4 CIDR), egress ports are all world open"
  vpc_id = module.vpc.vpc_id

  # Ingress Rules & CIDR Blocks
  ingress_rules = ["ssh-tcp", "http-80-tcp"]
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  ingress_with_cidr_blocks = [
    {
      rule  = "custom-tcp-rule"
      from_port = 25
      to_port   = 25
      cidr_blocks = [module.vpc.vpc_cidr_block]
    },
    {
      rule  = "custom-tcp-range"
      from_port = 3000
      to_port   = 10000
      cidr_blocks = [module.vpc.vpc_cidr_block]
    },
    {
      rule  = "custom-tcp-rule"
      from_port = 6443
      to_port   = 6443
      cidr_blocks = [module.vpc.vpc_cidr_block]
    },
    {
      rule  = "custom-tcp-rule"
      from_port = 465
      to_port   = 465
      cidr_blocks = [module.vpc.vpc_cidr_block]
    },
    {
      rule  = "custom-tcp-range"
      from_port = 30000
      to_port   = 32767
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  ]

  # Egress Rule - all-all open
  egress_rules = ["all-all"]
  tags = local.common_tags
}



