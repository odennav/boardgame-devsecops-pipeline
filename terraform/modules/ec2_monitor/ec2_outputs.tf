# AWS EC2 Instance Terraform Outputs

## ec2_monitor_instance_ids
output "ec2_monitor_instance_id" {
  description = "Monitoring Server EC2 instance ID"
  value       = module.ec2_monitor.id
}

## ec2_monitor_public_ip
output "ec2_monitor_public_ip" {
  description = "Public IP address of Monitoring Server EC2 instance"
  value       = module.ec2_monitor.public_ip 
}
