#!/bin/bash

# This script install Docker engine in Ubuntu machine using the apt repository.


aptUpdate() {

# Update list of available packages	
sudo apt-get update

}

addGPGKey() {

# Add Docker's official GPG key	
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

}

addAptRepo() {

# Add the repository to apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
}



instllDockerPkgs() {

# Install the Docker packages
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo chmod 666 /var/run/docker.sock
}

## Main Script

aptUpdate
addGPGKey
addAptRepo
aptUpdate
instllDockerPkgs

