#!/bin/bash

sudo hostnamectl set-hostname jenkins-build-server

sudo apt update -y
sudo apt install wget curl fontconfig npm maven openjdk-11-jdk openjdk-17-jdk -y

# Install Jenkins
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
sudo apt update -y
/usr/bin/java --version
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install jenkins -y
sudo systemctl start jenkins
sudo systemctl status jenkins

##Install Docker and Run SonarQube as Container
sudo apt-get update
sudo apt-get install docker.io -y
sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins  
newgrp docker
sudo chmod 777 /var/run/docker.sock
sleep 10
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
docker run -d -p 8081:8081 --name nexus sonatype/nexus3

#install trivy
sudo apt-get install wget apt-transport-https gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy -y

# Install Kubectl
sudo apt update
curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# Install  eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
cd /tmp
sudo mv /tmp/eksctl /bin
eksctl version

# Install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
sudo chmod 700 get_helm.sh
sudo ./get_helm.sh
helm version



# # Update system and install dependencies
# sudo apt update -y
# sudo apt upgrade -y
# sudo apt install openjdk-8-jre-headless -y
# # Create nexus user
# sudo adduser --disabled-login --no-create-home --gecos "" nexus
# echo 'nexus' | sudo passwd --stdin nexus

# # Download and extract Nexus
# cd /opt
# sudo wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz
# sudo tar -zxvf latest-unix.tar.gz
# sudo mv nexus-3* nexus3
# sudo chown -R nexus:nexus /opt/nexus3
# sudo chown -R nexus:nexus /opt/sonatype-work

# # Create Nexus service
# cat <<EOT | sudo tee /etc/systemd/system/nexus.service
# [Unit]
# Description=Nexus service
# After=network.target
# [Service]
# Type=forking
# LimitNOFILE=65536
# User=nexus
# Group=nexus
# ExecStart=/opt/nexus3/bin/nexus start
# ExecStop=/opt/nexus3/bin/nexus stop
# Restart=on-abort
# [Install]
# WantedBy=multi-user.target
# EOT


# cat <<EOT | sudo tee /nexus/bin/nexus.vmoptions
# -Xms1024m
# -Xmx1024m
# -XX:MaxDirectMemorySize=1024m
# -XX:LogFile=./sonatype-work/nexus3/log/jvm.log
# -XX:-OmitStackTraceInFastThrow
# -Djava.net.preferIPv4Stack=true
# -Dkaraf.home=.
# -Dkaraf.base=.
# -Dkaraf.etc=etc/karaf
# -Djava.util.logging.config.file=/etc/karaf/java.util.logging.properties
# -Dkaraf.data=./sonatype-work/nexus3
# -Dkaraf.log=./sonatype-work/nexus3/log
# -Djava.io.tmpdir=./sonatype-work/nexus3/tmp
# EOT

# # Update Nexus configuration to run as nexus user
# sudo sed -i 's/#run_as_user=""/run_as_user="nexus"/g' /opt/nexus3/bin/nexus.rc

# # Configure firewall
# sudo systemctl daemon-reload

# # Enable and start Nexus service
# sudo systemctl start nexus
# sudo systemctl enable nexus