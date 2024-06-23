# Boardgame DevOps Pipeline Project

Implement a DevSecOps Pipeline in AWS for the Boardgame.


## Getting Started

**Pre-requisites**

- Find the soure code for the Boardgame app [here](https://github.com/odennav/boardgame-app)

- Install [Terraform](https://developer.hashicorp.com/terraform/install)

- Install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

Generate `terraform-key` required for connection to EC2 instances in AWS VPC.

Choose `RSA` key pair type and use `.pem` key file format.


We'll implement the following workflow:

- Provision Servers with Terraform

- Ansible Setup and User Configuration

- Setup Kubernetes Cluster with Kubeadm

- Setup MetalLB

- Setup Traefik Proxy

- Setup Cert-manager

- Jenkins Installation and Configuration

- Install Jenkins Plugins

- SonarQube Installation and Setup

- Sonatype Nexus Installation and Setup

- Setup Trivy

- DockerHub Setup

- Setup Mail Notifications

- Pipeline Setup with Jenkinsfile

- Setup Prometheus and Grafana for Monitoring and Observability


Please check the `inventory` list for reference to IP addresses of `EC2` instances used in this project.

This list is dynamically built when the AWS infrastructure is provisioned with Terraform. 

Special credits to [Aditya Jaiswal](https://github.com/jaiswaladi246)

-----

## Provision Servers with Terraform

Install Terraform in `build` machine

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

Install AWS CLI in `build` machine
```bash
sudo apt install curl unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
```

Confirm the AWS CLI installation
```bash
aws --version
```

Clone this repository in the `build` machine
```bash
cd /
git clone git@github.com:odennav/boardgame-devops-pipeline-project.git
```

Execute these Terraform commands sequentially in the `build` machine to create the AWS VPC(Virtual Private Cloud) and EC2 instances.

Initializes terraform working directory
```bash
cd boardgame-devops-pipeline-project/terraform
terraform init
```

Validate the syntax of the terraform configuration files
```bash
terraform validate
```

Create an execution plan that describes the changes terraform will make to the infrastructure
```bash
terraform plan
```

Apply the changes described in execution plan
```bash
terraform apply -auto-approve
```

Check AWS console for instances created and running

**SSH access**

Use `.pem` key from AWS to SSH into the public EC2 instance. IPv4 address of public EC2 instance will be shown in terraform outputs.
```bash
ssh -i private-key/terraform-key.pem ec2-user@<ipaddress>
```

We can use public EC2 instance as a jumpbox to securely SSH into private EC2 instances within the VPC.

Note, the ansible `inventory` is built dynamically by terraform with the private ip addresses of the `EC2` machines.

-----

## Ansible Setup and User Configuration

Generate SSH public/private key pair in `build` machine
```bash
ssh-keygen -t rsa -b 4096
```

Once the RSA key-pair is generated, manually copy the public key id_rsa.pub to the /root/.ssh/authorized_keys file in all kube nodes.


Install Ansible in `build` machine
```bash
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
```

The `bootstrap` and `kubeadm` folders in this repository contain the ansible scripts necessary to set up your servers with the required packages and applications.


**Bootstrapping Vagrant Nodes**

All nodes will be bootstrapped using Ansible.

Bootstrap the master node
```bash
cd boardgame-devops-pipeline-project/bootstrap/
ansible-playbook bootstrap.yml --limit k8s_master
```

Bootstrap the worker nodes
```bash
ansible-playbook bootstrap.yml --limit k8s_node
```

Once the bootstrap is complete, you can log in as `odennav-admin`.

Confirm SSH access to master node
```bash
ssh odennav-admin@10.33.100.2
```

To return to the `build` machine, type exit and press Enter or use Ctrl+D

Confirm SSH access to 1st worker node
```bash
ssh odennav-admin@10.33.100.3
```

Confirm SSH access to 2nd worker node
```bash
ssh odennav-admin@10.33.100.4
```

-----

## Setup Kubernetes Cluster with Kubeadm

**Setting up Kubernetes Cluster**

The kube nodes are now ready to have a Kubernetes cluster installed on them.

Please note amazon `EKS` is preferred for production but it's not deployed in this project to reduce the financial costs incurred in service bill.

Execute ansible role playbook for the kubernetes master node
```bash
cd boardgame-devops-pipeline-project/kubeadm/
ansible-playbook k8s.yml  --limit k8s_master
```

Execute ansible role playbook for the kubernetes worker nodes
```bash
ansible-playbook k8s.yml  --limit k8s_node
```

Check status of your nodes from the `k8smaster` node
```bash
kubectl get nodes
```

The Kubernetes cluster should be ready as shown below

**Install Kubeaudit**

Audit the Kubernetes clusters for various security concerns with `Kubeaudit` tool.

Download the binary relase
```bash
cd $HOME
wget https://github.com/Shopify/kubeaudit/releases/download/v0.22.1/kubeaudit_0.22.1_linux_amd64.tar.gz
```

Extract the tarball file
```bash
tar -xzvf kubeaudit_0.22.1_linux_amd64.tar.gz
```

Move kubeaudit to bin directory in $PATH
```bash
sudo mv kubeaudit /usr/local/bin/
```

Use `cluster` mode and audit all Kubernetes resources in the cluster
```bash
kubeaudit all
```

**Setup RBAC in Kubernetes Cluster**

Role Based Access Control  is a method of regulating access to computer or network resources based on the roles of individual users.

We'll start by creating the boardgame namespace
```bash
kubectl create namespace boardgame
```

View the manifest for the service account
```yaml
apiVersion: v1
kind: ServiceAccount
metadata: 
  name: jenkins
  namespaces: boardgame
```

Create a service account for Jenkins 
```bash
kubectl apply -f boardgame-devops-pipeline-project/kubernetes-manifests/service_account.yaml
```

Create a role to assign to the service account
```bash
kubectl apply -f boardgame-devops-pipeline-project/kubernetes-manifests/role.yaml
```

Bind the role to service account 
```bash
kubectl apply -f boardgame-devops-pipeline-project/kubernetes-manifests/role_binding.yaml
```
 
Create API token for Jenkins to athenticate to the kubernetes cluster API
```bash
kubectl apply -f boardgame-devops-pipeline-project/kubernetes-manifests/svc_account_token.yaml
```

View API token created in kubernetes secret
```bash
kubectl describe secret jenkins_secret -n boardgame
```

This token will be used to create a global credential for kubernetes tool in Jenkins.


**Create Kubernetes Secret Credential in Jenkins**

Go to Jenkins `Dashboard` and select `Manage Jenkins`.

Under the `Security` section, select `Credentials`

Click on `(global)` domain of jenkins `System` store.

Next, click on blue button `+ Add Credentials` at the top right.

Assign the following:

Kind -------------------------> Secret text

Scope ------------------------> Global

Secret -----------------------> <jenkins_secret token>

ID ------------------------- > k8s-cred

Description ------------------> k8s-cred-token

-----


## Setup MetalLB

MetalLB is a load-balancer implementation for bare metal Kubernetes clusters which will allocate IP addresses to services within the Kubernetes cluster.

Enable `strictARP` mode to use layer2 ARP protocol
```bash
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system
```

Proceed with installation by manifest
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
```

Define a pool of addresses to assign to services with `IPAddressPool` resource
```bash
cd boardgame-devops-pipeline-project/metallb/
kubectl apply -f IPAddressPool.yml
```

Configure `L2Advertisement` resource to advertise this IP pool to local network.
```bash
kubectl apply -f L2Advertisement.yml
```

-----

## Setup Traefik Proxy

Traefik proxy is a modern cloud native application proxy that will automate the discovery, routing, and load balancing of services in the kubernetes cluster.

Create namespace for traefik
```bash
kubectl create namespace traefik
```

Confirm traefik namespace created
```bash
kubectl get namespaces
```

Add traefik repository with helm package manager
```bash
helm repo add traefik https://helm.traefik.io/traefik
```

Update local cache of helm chart repositories
```bash
helm repo update
```

Install traefik chart with custom values file `values.yaml` in traefik namespace
```bash
cd boardgame-devops-pipeline-project/traefik/
helm install --namespace=traefik traefik traefik/traefik --values=values.yaml
```

Verify Traefik is installed
```bash
helm status traefik --namespace=traefik
```

Verify the status of the traefik ingress controller service
kubectl get svc --namespace traefik

Confirm the traefik deployment pods in `traefik` namespace are ready and running
```bash
kubectl get pods --namespace traefik
```

**Setup Route to Traefik Dashboard**

Apply middleware configuration for ingress route to the boardgame service
```bash
kubectl apply -f default-headers.yaml
```

Confirm middleware is created
```bash
kubectl get middleware
```

Install the apache2-utils package to use the `htpassword` tool
```bash
sudo apt-get update
sudo apt-get install -y apache2-utils
```

Generate a base64 encoded password
```bash
htpasswd -nb odennav-admin mypassword | openssl base64
```
Copy encoded password to the `traefik/traefik-dasboard/secret-dashboard.yaml` file.

Apply the secret to the kubernetes cluster
```bash
cd boardgame-devops-pipeline-project/traefik/traefik-dasboard/dasboard/
kubectl apply -f secret-dashboard.yaml
```

Verify secret created
```bash
kubectl get secrets --namespace traefik
```

Apply middleware configuration for ingress route to traefik dashboard
```bash
kubectl apply -f middleware.yaml
```

Apply ingress route to the traefik dashboard
```bash
kubectl apply -f ingress.yaml
```


## Setup Cert-manager

cert-manager is a powerful & extensible X.509 certificate controller used to automatically provision and manage TLS certificates in Kubernetes clusters.

Create namespace for cert-manager
```bash
kubectl create namespace cert-manager
```

Confirm cert-manager namespace created
```bash
kubectl get namespaces
```

Add jetstack repository with helm package manager
```bash
helm repo add jetstack https://charts.jetstack.io
```

Update local cache of helm chart repositories
```bash
helm repo update
```

Apply CRDs for cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.crds.yaml
```

Install cert-manager chart with custom values file `values.yaml` in cert-manager namespace
```bash
cd boardgame-devops-pipeline-project/traefik/traefik-dasboard/cert-manager/
helm install cert-manager jetstack/cert-manager --namespace cert-manager --values=values.yaml --version v1.15.0
```

Confirm all cert-manager deployment pods in `cert-manager` namespace are ready and running
```bash
kubectl get pods --namespace cert-manager
```

**Configure Staging Certificate**

At this moment, we'll use the staging endpoint for certificate propagation.

Production endpoint has http request weight-limiting configured which could trigger a block for days/weeks if there are too many failures.

Staging wont give us a trusted certificate but it'll assign one that is signed form staging servers.

If we get staging certificate, thats good. Then we can use the `caServer` endpoint url to get production certificate.

I've registered a domain `odennav.com` with a domain registrar.

Update nameservers set with your registrar to ensure this domain points to the authoritave nameservers received from [Cloudflare](https://www.cloudflare.com).

Cloudflare will be used for DNS verification by Let's Encrypt.


Go to your cloudflare account and create a custom token. Implement the following:

- On your profile page, select `{} API Tokens`

- Click on `Create Token` and select `Get Started` to create a custom token.

Enter the following:

Token name --------------------> Odennav-Docker-Traefik

1st Permissions ---------------> Zone & Zone & Read

2nd Permissions ---------------> Zone & DNS & Edit

Zone Resources ----------------> Include & Specific zone & odennav.com

Click on `Continue to summary` and  on the summary page, click on `Create Token`

Copy the token shown to you for access to the Cloudflare API and save it to the `cert-manager/issuer/secret-cf-token.yaml` file.


Apply the secrets for cloudflare secret token to the kubernetes cluster
```bash
cd boardgame-devops-pipeline-project/traefik/traefik-dasboard/cert-manager/issuers/
kubectl apply -f secret-cf-token.yaml
```

Apply the staging ClusterIssuer resource
```bash
kubectl apply -f letsencrypt-staging.yaml
```

Create a staging certificate for the `default` namespace
```bash
cd boardgame-devops-pipeline-project/traefik/traefik-dasboard/cert-manager/certificates/staging
kubectl apply -f local-odennav-com.yaml
```

**Configure Local DNS for Traefik Proxy**

The `hosts` file is used to map hostnames to IP addresses and is usually queried before any DNS queries are made to external servers.

**`Windows`**:

Edit the `hosts` file at `C:\Windows\System32\drivers\etc\` directory and add this custom entry.

```text
10.33.50.55 traefik-dashboard.local.odennav.com
```

**`Linux`**:

Edit the the `hosts` file at /etc/hosts and enter the custom entries above

View the traefik dashboard on a broswer and note the staging certificate issued.



**Configure Production Certificate**

Once the staging certificate from let's encrypt is confirmed, we can now go to production.

Apply production ClusterIssuer. This points to Let's Encrypt production endpoint.
```bash
cd boardgame-devops-pipeline-project/traefik/traefik-dasboard/cert-manager/issuers/
kubectl apply -f letsencrypt-production.yaml
```

Create a production certificate resource. This creates a `TXT` record at cloudflare and verifies it to create our production certificate.
```bash
cd boardgame-devops-pipeline-project/traefik/traefik-dasboard/cert-manager/certificates/production
kubectl apply -f local-odennav-com.yaml
```

Check for DNS solver challenges. If no challenges after `pending` or `valid` states are resolved, then its working well.
```bash
kubectl get challenges
```

Replace the value of the `secretName` variable defined in the `ingress.yaml` file for traefik dashboard. Use `local-odennav-com-tls` as name of certificate secret.

This secret stores the production certificate in the `IngressRoute` resource for the traefik dashboard. 

Recreate the IngressRoute.
```bash
cd cd boardgame-devops-pipeline-project/traefik/traefik-dasboard/dasboard/
kubectl apply -f ingress.yaml
```
-----

## Jenkins Installation and Configuration

**Install Jenkins in Ubuntu**

We'll use the long term support release which is installed from debian-stable apt repository.

```bash
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins
```

Enable jenkins service
```bash
sudo systemctl enable jenkins
```

Start jenkins service
```bash
sudo systemctl start jenkins
```

Confirm jenkins service is active and running
```bash
sudo systemctl status jenkins
```

**Post Installation Setup**

Next we use the post-installation setup wizard to unlock jenkins, customize plugins and create first admin user required to continue accessing jenkins.

 - Browse to `10.33.100.7:8080` to see the **`Unlock Jenkins`** page.

- Obtain the automatically-generated alphanumeric password
  ```bash
  sudo cat /var/jenkins_home/secrets/initialAdminPassword
  ```
- Paste this password into the `Administrator password` field and click `Continue` to access jenkin's main UI.

**Customize Jenkins with Plugins**

After unlocking Jenkins, the **`Customize Jenkins`** page appears.

Here you can install any number of useful plugins as part of your initial setup.

Click on `Install suggested plugins` to install the recommended set of plugins, which are based on most common use cases.

**Create First Administrator User**

Finally, after customizing Jenkins with plugins, Jenkins asks you to create your first administrator user.

When the **`Create First Admin User`** page appears, specify the details for your administrator user in the respective fields and click `Save and Continue`.

When the Jenkins is ready page appears, click `Start using Jenkins`

This page may indicate Jenkins is almost ready! instead and if so, click `Restart`.

If the page does not automatically refresh after a minute, use your web browser to refresh the page manually.

If required, log in to Jenkins with the credentials of the user you just created and you are ready to start using Jenkins.


**Install Kubectl using native package management**

The kubectl version will be the same version with the kubernetes cluster.

We'll use this ansible script below to install `kubectl` in the jenkins machine.

```bash
cd boardgame-devops-pipeline-project/jenkins/
ansible-playbook kubectl_install.yml 
```

-----

## Install Plugins

Plugins are required to integrate tools to Jenkins and execute in our pipeline script.

Go to `Plugin Manager` under `Manage Jenkins` section of Jenkins dasboard.

Our next task is to search and install the following plugins below:

- Eclipse Temurin installer

- Config File Provider

- Pipeline Maven Integration

- SonarQube Scanner 

- Maven Integration

- Docker

- Docker Pipeline

- docker-build-step

- CloudBees Docker Build and Publish

- Kubernetes

- Kubernetes CLI

- Kubernetes Credentials

- Kubernetes Client API

- Trivy

Select `Install without restart` at bottom left.


**Configure Other Global Tools**

When plugins selected are installed, next we configure them.

Go to `Global Tool Configuration` under `Manage Jenkins` section of Jenkins dasboard

Note procedures to configure jdk and docker as global tools below:


**Procedure - JDK**: 

Scroll down and search for **`JDK installations`**

Click on `Add JDK`

Enter or select the following:

 - Name -----------------------------> jdk17

- Install automatically `?` ------------> ✔️

- Add Installer --------------------> Install from adoptium.net

- Version --------------------------> jdk-17.0.19+9


**Procedure - Docker**:

Scroll down and search for **`Docker installations`**  

Click on `Add Docker`

Enter or select the following:

- Name -----------------------------> docker

- Install automatically `?` ------------> ✔️

- Add Installer --------------------> Download from docker.com

- Docker version `?` --------------------------> latest



**Procedure - SonarQube Scanner**:

Scroll down and search for **`SonarQube Scanner installations`** 

Click on `Add SonarQube Scanner`

Enter or select the following:

- Name -----------------------------> sonar-scanner

- Install automatically `?` ------------> ✔️

- Version --------------------------> latest(SonarQube Scanner 5.0.1.3006)



**Procedure - Maven**:

Scroll down and search for **`Maven installations`**

Click on `Add Maven`

Enter or select the following:

- Name -----------------------------> maven3

- Install automatically `?` ------------> ✔️

- Version --------------------------> 3.6.1 or latest 


Click on `Apply` to save configuration.

-----

## SonarQube Installation and Setup

SonarQube is a code quality assurance tool that collects and analyzes source code, providing reports for the code quality of our project.

It enables us to deploy clean code consistently and reliably.

The sonarqube machine will be bootstrapped using Ansible.

```bash
cd boardgame-devops-pipeline-project/bootstrap/
ansible-playbook bootstrap.yml --limit sonarqube
```

Once the bootstrap is complete, you can log in as `odennav-admin`.

Confirm SSH access to the `sonarqube` node
```bash
ssh odennav-admin@10.33.100.5
```

**Install Docker**

Run the ansible playbook to install docker in the nexus machine
```bash
cd boardgame-devops-pipeline-project/docker/
ansible-playbook install-docker.yml --limit sonarqube
```

**Install SonarQube Container**

We'll run the long term community version of sonarqube's image.
```bash
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
```

Confirm container is running
```bash
docker ps -a --filter "name=sonar"
```

Browse to UI of SonarQube at `10.33.100.5:9000`

Use `admin` for default username and password. Update to new password when requested.

**Generate Token**

Go to **`Administration`** tab and select `Security` tab.

From the drop down, click on `Users`.

This section is used to create and administer individual users.

Click on button at far right under `Tokens` column.

Enter `Token Name` as `sonar-token` and click on `Generate`. Note period of expiry.

Copy this access code, we'll use it to create credential for SonarQube in jenkins.


**Create SonarQube Secret for Jenkins**

Go to Jenkins `Dashboard` and select `Manage Jenkins`.

Under the `Security` section, select `Credentials`

Click on `(global)` domain of jenkins `System` store.

Next, click on blue button `+ Add Credentials` at the top right.

Assign the following:

Kind -------------------------> Secret text

Name ------------------------- > sonar-token

Scope ------------------------> Global

Secret -----------------------> `sonar-token`

Description ------------------> sonar-token generated


**Configure SonarQube Server**

Go to Jenkins `Dashboard` and select `Manage Jenkins`.

Under the `System Configuration` section, select `Configure System`.

Scroll down and search for **`SonarQube servers`** and `SonarQube installatons`

Click `Add SonarQube` and assign the following:

Name ---------------------------------> sonar

Server URL ---------------------------> `https://10.33.100.5:9000`

Server authentication token ----------> sonar-token

Click on `Apply` and `Save`.


**SonarQube QualityGate Setup**

Go to **`Administration`** tab and select `Configuration` drop-down tab.

From the drop down, click on `Webhooks`.

This section is used to create webhooks used to notify external services when a project analysis is done.

Click the `Create` button at top-right section.

To create webhook, assign the following:

Name -------------------------> jenkins

URL --------------------------> `https://10.33.100.7:8080/sonarqube-webhook/`

Secret -----------------------> ''

Save this webhook. It will be used in Jenkins pipeine script


-----

## Sonatype Nexus Installation and Setup


**Bootstrap Nexus Node**

The nexus machine will be bootstrapped using Ansible.

```bash
cd boardgame-devops-pipeline-project/bootstrap/
ansible-playbook bootstrap.yml --limit nexus
```

Once the bootstrap is complete, you can log in as `odennav-admin`.

Confirm SSH access to the `nexus` node
```bash
ssh odennav-admin@10.33.100.6
```

**Install Docker**

Run the ansible playbook to install docker in the nexus machine
```bash
cd boardgame-devops-pipeline-project/docker/
ansible-playbook install-docker.yml --limit nexus
```

Run Nexus Container with the latest version of nexus3 docker image.
```bash
docker run -d --name Nexus -p 8081:8081 sonatype/nexus3
```

Confirm container is running
```bash
docker ps -a --filter "name=Nexus"
```

Browse to UI of Nexus at `10.33.100.6:8081`


Note, the username to sign into the Sonatype Nexus Repository is `admin` . 

The password is located in `/nexus-data/admin.password` file in the container.

```bash
docker -exec -it Nexus /bin/bash 
cat sonatyp-work/nexus-data/admin.password
```

Copy the password and use it to sign in. Then choose a new password for the `admin` user.



**Sonatype Nexus Artifact Repository Setup**

To publish artifacts to Nexus, we'll add the nexus repository urls to the `pom.xml` file in the source code project.

 
Add the urls of the following nexus repositories to the `pom.xml` file:

- Nexus releases

- Nexus snapshots

```text
        <distributionManagement>
        <repository>
            <id>maven-releases</id>
            <url>http://10.33.100.6:8081/repository/maven-releases/</url>
        </repository>
        <snapshotRepository>
            <id>maven-snapshots</id>
            <url>http://10.33.100.6:8081/repository/maven-snapshots/</url>
        </snapshotRepository>
        </distributionManagement>
```

**Configure Nexus Global Settings Credential**

Ensure the `Config File Provider` plugin is already installed.

When plugins selected are installed, go to **`Global Tool Configuration`** under `Manage Jenkins` section of Jenkins dasboard

Select **`Managed files`** and click on `+ Add a new Config` at left tab.

Assign the following:

Type -----------------------------> `Global Maven settings.xml` 

ID of the config file ------------> global-settings

Click `Next`.

Next, add the following to the end of the configuration file, `settings.xml` in the `Content` section

The `<servers>` section in the `settings.xml` file specifies the authentication information to use when connecting to the Nexus server.

```text
<server>
  <id>maven-releases</id>
  <username>admin</username>
  <password>password</password>
</server>

<server>
  <id>maven-snapshots</id>
  <username>admin</username>
  <password>password</password>
</server>
```

Click on `Submit`

Note the name of this global settings configuration file is `MyGlobalSettings`.

-----

## GitHub Integration

Personal access token from Github is needed for Jenkins to access source code files.

To create token, implement the following:

-  Click on your profile at the top right, scroll down and click on `:gear: Settings`

- Scroll down at left bar and select `<> Developer Settings`

- Select the drop down `:key: Personal access tokens` and click on `Tokens (classic)`

- Select drop down 'Generate new token` at top right and click on `Generate new token (classic)`

Assign the following:

token name ----------------------------> git-token

Expiration ----------------------------> 30 days

Select scopes -------------------------> `Select all scopes except delete permissions`

- Click on `Generate token`

- Copy and save token generated. we'll add it as secret credential in Jenkins.



**Create Github Secret for Jenkins**

Go to Jenkins `Dashboard` and select `:gear: Manage Jenkins`.

Under the `Security` section, select `Credentials`

Click on `(global)` domain of jenkins `System` store.

Next, click on blue button `+ Add Credentials` at the top right.

Assign the following:

Kind -------------------------> Username with password

Scope ------------------------> Global

Username ---------------------> odennav

ID -----------------------> `git-cred`

Description ------------------> boardgame-git-repo

Click on `Create`.


-----

## Trivy Setup

Trivy is an open source security scanner used to find security vulnerabilities of dependencies used in source code project and Iac misconfigurations.

It can also scan the following:

- Container images, filesystem, virtual machine image, git repository, kubernetes cluster and cloud infrastructure.

**Install using apt package manager**

Add repository to `/etc/apt/sources.list.d` in `Jenkins` machine.
```bash
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy
```

If you intend to use trivy as container image, mount `docker.sock` as from the host into the Trivy container.

Confirm trivy installed
```bash
trivy --version
```

Trivy will be used to scan the filesystem and generate the scan report with `html.tpl` file in the `/boardgame-devops-pipeline-project/trivy/` directory.

Copy the template to Jenkins machine.
```bash
sudo mkdir ~/trivy
sudo cd trivy
sudo vi html.tpl
```

Ensure Jenkins has permission to use the template
```bash
sudo chown -R jenkins:jenkins ~/trivy
```

-----

## DockerHub Setup

**Create DockerHub Secret for Jenkins**

Go to Jenkins `Dashboard` and select `Manage Jenkins`.

Under the `Security` section, select `Credentials`

Click on `(global)` domain of jenkins `System` store.

Next, click on blue button `+ Add Credentials` at the top right.

Assign the following:

Domain ------------------------> Global credentials

Kind --------------------------> Username with password

Username ----------------------> odennav

Password ----------------------> **********

ID ----------------------------> `docker-cred`

Description -------------------> dockerhub-cred 

-----

## Setup Mail Notifications 

Automate email notifications of the jenkins pipeline build results by configuring Jenkins to send emails through an SMTP server. We'll use SMTP server from Gmail.

To give Jenkins permission to access our Google account, we'll need an app password. This is a 16-digit passcode.

Generate your app password with this [guide](https://support.google.com/mail/answer/185833?hl=en) and name the app `Jenkins`.


**Create Gmail Secret Credential for Jenkins**

Go to Jenkins `Dashboard` and select `:gear: Manage Jenkins`.

Under the `Security` section, select `Credentials`

Click on `(global)` domain of jenkins `System` store.

Next, click on blue button `+ Add Credentials` at the top right.

Assign the following:

Kind -------------------------> Username with password

Scope ------------------------> Global

Username ---------------------> `odennav@gmail.com`

Password ---------------------> `<gmail app-password>`

ID -----------------------> `mail-cred`

Description ------------------> gmail-cred

Click on `Create`.



**Configure Email Notification in Jenkins**

Go to Jenkins `Dashboard` and select `Manage Jenkins`.

Under the `System Configuration` section, select `Configure System`.

1. Scroll down and search for **`Extended E-mail Notification`**

Click `Add SonarQube` and assign the following:

SMTP server ---------------------> smtp.gmail.com

SMTP Port -----------------------> 465

Click on drop-down `Advanced`

Credentials ---------------------> `mail-cred`

Use SSL -------------------------> :check_mark:



2. Scroll down and search for **`E-mail Notification`**

Click `Add SonarQube` and assign the following:

SMTP server ---------------------------------> smtp.gmail.com

SMTP Port ---------------------------> 465

Click on drop-down `Advanced`

User Name ----------------------> `odennav@gmail.com`

Password -----------------------> `<gmail app-password>`

Use SSL -------------------------> :check_mark:

SMTP Port -----------------------> 465


Click on `Apply` and `Save`.

-----

## Jenkins Pipeline Setup 

Jenkins Pipeline is a suite of plugins which supports continuous integration and continuous delivery operations in Jenkins.

It's an automated expression of our process for building, testing and deploying source code from Github right through to our staging environment.

**Setup Pipeline**

Implement procedure below:

 - Go to Jenkins main dashboard and click on `New Item`

-  Name pipeline as `BoardGame` and select `Pipeline` as type of project, then click `OK`

- Click on the created job  and select `Discard old builds`

  **`Max # of builds to keep`** --------------- > 2

- Scroll down to the `Pipeline` section in the configuration screen.

- Choose `Pipeline script from SCM` and select type of SCM.

- Enter the URL of the Github repository containing the Jenkinsfile.

- Add credentials of the Github repository which contains the personal access token.

- Choose the branch to build from, typically `/main` 

- Specify the path of Jenkinsfile in SCM as `/boardgame-devops-pipeline-project/Jenkinsfile`

- Click on `Save` to save this configuration.


To restart Jenkins and apply configuration changes or updates effectively:

- Navigate to the Jenkins **`Dashboard`** and click on `Manage Jenkins` in the sidebar.

- Select `Reload Configuration from Disk` or `Restart Safely`.

The pipeline block below defines all the actions required for the secure deployment of the BoardGame site.

```text
pipeline {
    agent any

    tools{
        jdk 'jdk17'
        maven 'maven3'
    }

    environment{
        SCANNER_HOME= tool 'sonar-scanner'
        TEMPLATE_PATH="@/home/odennav/trivy/html.tpl"
        DATE=$(date +"%Y-%m-%d_%H-%M")
    }

    stages {
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/odennav/boardgame-devops-pipeline-project.git'
            }
        }
       
        stage('Clear Workspace') {
            steps {
                sh "cleanWs()"
            }
        }

        stage('Maven Clean Phase') {
            steps {
                sh "mvn clean"
            }
        }

        stage('Maven Compile Phase') {
            steps {
                sh "mvn compile"
            }
        }
 
        stage('Maven Test Phase') {
            steps {
                sh "mvn test"
            }
        }

        stage('Trivy Filesystem  Scan') {
            steps {
                sh """trivy fs --security-checks vuln,secret,misconfig --format template --template ${TEMPLATE_PATH} --output trivy_fs_report_$DATE.html . """
            }
        }

        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('sonar'){
                    sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=BoardGame \ 
                    -Dsonar.java.binaries=. \
                    -Dsonar.projectKey=BoardGame '''
                }    
            }
        }
  
        stage('SonarQube Quality Gate') {
            steps {
                script {
                  waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'   
                }     
            }
        }


        stage('Maven Build Phase') {
            steps {
                sh "mvn package"
            }
        }

        stage('Publish Artifacts to Nexus') {
            steps {
              withMaven(globalMavenSettingsConfig: 'global-settings', jdk: 'jdk17', maven: 'maven3', mavenSettingsConfig:",traceability: true) {
                  sh "mvn deploy"
              }  
            }
        }

        stage('Build & Docker Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker') {
                        sh "docker build -t odennav/boardgame:v1 ./boardgame"
                    }
                }
                
            }
        }

        stage('Scan Docker Image') {
            steps {
                sh """trivy image --security-checks vuln,secret,misconfig --format template --template ${TEMPLATE_PATH} --output trivy_image_scan_report_$DATE.html . """

            }
        }


        stage('Push Docker Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker') {
                        sh "docker push  odennav/boardgame:v1 "
                    }
                }
                
            }
        }


        stage('Deploy to Kubernetes Cluster') {
            steps {
                withKubeConfig(caCertificate:",clusterName: 'kubernetes',contextName:",credentialsId:'k8s-cred',namespace:'boardgame',restrictKubeConfigAccess:false,serverUrl:'https://172.31.8.1.146:6443'){
                    sh "kubectl apply -f kubernetes-manifests/boardgame-manifests" 
                {
                
            }
        }

        stage('Verify Kubernetes Deployments') {
            steps {
                withKubeConfig(caCertificate:",clusterName: 'kubernetes',contextName:",credentialsId:'k8s-cred',namespace:'boardgame',restrictKubeConfigAccess:false,serverUrl:'https://172.31.8.1.146:6443'){
                    sh "kubectl get pods" 
                    sh "kubectl get svc" 
                {
                
            }
        }

    }
    post {
        always {
            archiveArtifacts artifacts: "trivy_report_*.html", fingerprint: true    
            publishHTML (target: [
                allowMissing: false,
                alwaysLinkToLastBuild: false,
                keepAll: true,
                reportDir: '.',
                reportFiles: 'trivy_report_*.html',
                reportName: 'Trivy Scan',
                ])

        script {
            def jobName = env.JOB_NAME
            def buildNumber = env.BUILD_NUMBER
            def pipelineStatus = currentBuild.result ?: 'UNKNOWN'
            def bannerColor = pipelineStatus.toUpperCase() == 'SUCCESS' ? 'green' : 'red'

            def body = """
                <html>
                <body>
                <div style="border: 4px solid ${bannerColor}; padding: 10px;">
                <h2>${jobName} - Build ${buildNumber}</h2>
                <div style="background-color: ${bannerColor}; padding: 10px;">
                <h3 style="color: white;">Pipeline Status: ${pipelineStatus.toUpperCase()}</h3>
                </div>
                <p>Check the <a href="${BUILD_URL}">console output</a>.</p>
                </div>
                </body>
                </html>
            """

            emailext (
                subject: "${jobName} - Build ${buildNumber} - ${pipelineStatus.toUpperCase()}",
                body: body,
                to: 'odennav@gmail.com',
                from: 'jenkins@example.com',
                replyTo: 'jenkins@example.com',
                mimeType: 'text/html',
                attachmentsPattern: 'trivy_image_scan_report_$DATE.html'
            )
        }                    

        }
    }
}
```

-----

**Build Pipeline**

Select drop-down of **`BoardGame`** pipeline created above and trigger a build of pipeline job.

- Click on `Build Now`

- Jenkins will fetch the Jenkinsfile from the Github repository and run the jobs defined.

- View the progress of the pipeline job on the Jenkins dashboard.

- Click on the job to view detailed logs and status updates as each stage of the pipeline is executed.

Check the console output and logs for more info on any failures.


**SAST Reports**

To view reports generated by SonarQube:

- Browse to `10.33.100.5:9000` and click on **`Projects`** tab.

- Select project we created in pipeline script, `BoardGame`.

- View bugs, vulnerabilities, code smells, duplications and hotspots reviews.

To view scan reports from Trivy:

- Select pipeline job created

- Scroll down and click on `Trivy Scan` in Jenkins.

- View vulnerabilities found with different severity levels.


-----


## Setup Prometheus and Grafana for Monitoring and Observability

**Install Prometheus**

Download [Prometheus](https://prometheus.io/download/)
```bash
cd ~
wget https://github.com/prometheus/prometheus/releases/download/v2.53.0/prometheus-2.53.0.linux-amd64.tar.gz
```

Verify the SHA256 checksum
```bash
sha256sum prometheus-2.53.0.linux-amd64.tar.gz
```
Extract prometheus from the tarball file
```bash
tar -xzvf prometheus-2.53.0.linux-amd64.tar.gz
```

Move prometheus binary to bin directory
```bash
sudo mv ./prometheus-2.53.0.linux-amd64 /usr/local/bin/
```

Browse to prometheus UI on port `9090`.

**Manage Prometheus with Systemd**

We'll create a system service for Prometheus. This enables us to manage it efficiently.

Create a service file for `prometheus` service
```bash
sudo touch /etc/system/service/prometheus.service
```
Add this config to the `prometheus.service` file
```bash
[Unit]
Description=Prometheus Monitoring System
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus-2.53.0.linux-amd64/prometheus
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Create Prometheus user and group
```bash
sudo adduser --no-create-home --shell /bin/false prometheus
```

Enable new ownership for prometheus 
```bash
sudo chown -R prometheus:prometheus /usr/local/bin/prometheus-2.53.0.linux-amd64
```

Reload system to recognize new service created
```bash
sudo systemctl daemon-reload
```

Start the prometheus service
```bash
sudo systemctl start prometheus
```

Enable the service to start on boot
```
sudo systemctl enable prometheus
```

Confirm the status of prometheus service
```bash
sudo systemctl status prometheus
```

-----

**Install Grafana**

Download and install the [grafana](https://grafana.com/grafana/download)
```bash
cd ~
sudo apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/enterprise/release/grafana-enterprise_11.0.0_amd64.deb
sudo dpkg -i grafana-enterprise_11.0.0_amd64.deb
```

Start the grafana-server
```bash
sudo /bin/systemctl start grafana-server
```

Browse to grafana UI on port `3000`.

Log in with the username as `admin` and the password as `admin`.

-----

**Install Blackbox Exporter**

Download the blackbox exporter
```bash
cd ~
wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.25.0/blackbox_exporter-0.25.0.linux-amd64.tar.gz
```

Verify the SHA256 checksum
```bash
sha256sum blackbox_exporter-0.25.0.linux-amd64.tar.gz
```

Extract blackbox exporter from the tarball file
```bash
tar -xzvf blackbox_exporter-0.25.0.linux-amd64.tar.gz
```

Move the blackbox exporter to the bin diectory
```bash
sudo mv ./blackbox_exporter-0.25.0.linux-amd64 /usr/local/bin
```


**Manage Blackbox Exporter with Systemd**

We'll create a system service for Blackbox exporter. This enables us to manage it efficiently.

Create a service file for `blackbox_exporter` service
```bash
sudo touch /etc/system/service/blackbox_exporter.service
```
Add this config to the `blackbox_exporter.service` file
```bash
[Unit]
Description=Blackbox Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=blackbox
Group=blackbox
Type=simple
ExecStart=/usr/local/bin/blackbox_exporter-0.25.0.linux-amd64/blackbox_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Create blackbox user and group
```bash
sudo adduser --no-create-home --shell /bin/false blackbox
```

Enable new ownership of blackbox binary
```bash
sudo chown -R prometheus:prometheus /usr/local/bin/blackbox_exporter-0.25.0.linux-amd64
```

Reload system to recognize new service created
```bash
sudo systemctl daemon-reload
```

Start the prometheus service
```bash
sudo systemctl start blackbox_exporter
```

Enable the service to start on boot
```
sudo systemctl enable blackbox_exporter
```

Confirm the status of prometheus service
```bash
sudo systemctl status blackbox_exporter
```


Browse to grafana UI on port `9115`.


**Setup Blackbox Exporter**

Pass Boardgame site as a target for the blackbox exporter. Obtain the external IPv4 address assigned by Metallb

```bash
kubectl get svc --all-namespaces -o wide
```

Add the config below to `prometheus-2.53.0.linux-amd64/prometheus.yml` file.

```yaml
scrape_configs:
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]  # Look for a HTTP 200 response.
    static_configs:
      - targets:
        - http://prometheus.io    # Target to probe with http.
        - http://<load balanced external-ip>:<port>   # Target to probe with http
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 10.33.100.8:9115  # The blackbox exporter's real hostname and port.
```

Restart prometheus
```bash
sudo systemctl restart prometheus
```

**Create Grafana Data Source**

Open a web browser and connect to `10.33.100.8:3000`.

Recall the username is `admin` and the password is `admin`

Implement the following:

Click on the :gear: icon in the menu bar on the left. It will take you to the Configuration page for Grafana.

Click on the `Add data sources` button

Click on `Prometheus` as your choice of open-source time series database.

Assign the following as below:

Name ----------------> prometheus

Default--------------> Click to turn the selector on.

URL -----------------> `http://10.33.100.8:9090/`


Click the `Save & Test` button.

Now Grafana can access the metrics from Prometheus.


**Import System Dashboard**

Hover over the `+` sign in the menu on the left of your screen. It will expand into a menu when you hover over it.

From there, click on Import.

Implement the following:

In the `Grafana dashboard URL or id` field, enter `7587` and click the `Load` button next to it.

On the next screen in the `Select a Prometheus data source` box, select `prometheus`. 

Then click on the `Import` button.

Now you should see a dashboard displaying scraped Prometheus metrics for the Boardgame website.

Ensure to save the imported dashboard.

-----

Enjoy!

