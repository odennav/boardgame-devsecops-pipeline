# AWS EC2 Instance Terraform Outputs

## ec2_sonarqube_instance_ids
output "ec2_sonar_instance_id" {
  description = "Sonar EC2 instance ID"
  value       = module.ec2_sonar.id
}

## ec2_sonar_public_ip
output "ec2_sonar_public_ip" {
  description = "Public IP address of Sonar EC2 instance"
  value       = module.ec2_sonar.public_ip 
}
