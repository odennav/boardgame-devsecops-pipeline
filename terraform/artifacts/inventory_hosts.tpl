[k8s_master]
%{ for ip in master_ip ~}
${ip} 
%{ endfor ~}

[k8s_node]
%{ for ip in worker_ip ~}
${ip} 
%{ endfor ~}

[sonarqube]
%{ for ip in sonar_ip ~}
${ip} 
%{ endfor ~}

[nexus]
%{ for ip in nexus_ip ~}
${ip} 
%{ endfor ~}

[jenkins]
%{ for ip in jenkins_ip ~}
${ip} 
%{ endfor ~}

