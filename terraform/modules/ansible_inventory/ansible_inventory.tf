terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}


resource "local_file" "ansible_inventory" {
    content = templatefile("../../artifacts/inventory_hosts.tpl",
    {
        master_ip = values(module.ec2_master)[*].private_ip
        worker_ip = values(module.ec2_workers)[*].private_ip
        sonar_ip = values(module.ec2_sonar)[*].private_ip
        nexus_ip = values(module.ec2_nexus)[*].private_ip
        jenkins_ip = values(module.ec2_jenkins)[*].private_ip




    })
    filename = "../../../inventory"
}

output "master_ips" {
    value = "${formatlist("%v - %v", ec2_master.*.private_ip, ec2_master.*.name)}"
}

output "worker_ips" {
    value = "${formatlist("%v - %v", ec2_workers.*.private_ip, ec2_workers.*.name)}"
}

output "sonar_ips" {
    value = "${formatlist("%v - %v", ec2_sonar.*.private_ip, ec2_private_db.*.name)}"
}

output "nexus_ips" {
    value = "${formatlist("%v - %v", ec2_nexus.*.private_ip, ec2_private_db.*.name)}"
}

output "jenkins_ips" {
    value = "${formatlist("%v - %v", ec2_jenkins.*.private_ip, ec2_private_db.*.name)}"
}


