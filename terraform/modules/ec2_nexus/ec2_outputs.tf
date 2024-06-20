# AWS EC2 Instance Terraform Outputs

## ec2_nexus_instance_ids
output "ec2_nexus_instance_id" {
  description = "Nexus EC2 instance ID"
  value       = module.ec2_nexus.id
}

## ec2_nexus_public_ip
output "ec2_nexus_public_ip" {
  description = "Public IP address of Nexus EC2 instance"
  value       = module.ec2_nexus.public_ip 
}

