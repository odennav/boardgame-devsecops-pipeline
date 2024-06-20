# AWS EC2 Instance Terraform Outputs

## ec2_jenkins_instance_ids
output "ec2_jenkins_instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = module.ec2_jenkins.id
}

## ec2_jenkins_public_ip
output "ec2_jenkins_public_ip" {
  description = "Public IP address of Jenkins EC2 instance"
  value       = module.ec2_jenkins.public_ip 
}

