#!/bin/bash
# https://github.com/redhat-manufacturing/device-edge-workshops/blob/gitops-demo/exercises/rhde_gitops/demo/README.md
# curl -OL https://gist.githubusercontent.com/tosin2013/ae925297c1a257a1b9ac8157bcc81f31/raw/71a798d427a016bbddcc374f40e9a4e6fd2d3f25/configure-rhel8.x.sh
# chmod +x configure-rhel8.x.sh
# ./configure-rhel8.x.sh

if [ -f .env ]; then
    source .env
else
    echo "Please create a .env"
    exit 1
fi


# The Ansible playbooks will create Certificates to be used by the HTTPS services, so you need to issue valid SSL certs. An easy way to do it is by using ZeroSSL.
# This is totally free to set up and allows wildcard certificates to be issued. Once registered, create an API key on the developer page https://app.zerossl.com/developer.
# You need an "EAB Credential for ACME Clients", so generate one from that developer page. It will be something like this:


# Get your Red Hat Customer Portal Offline Token
# This token is used to authenticate to the customer portal and download software. It can be generated here. https://access.redhat.com/management/api

# Commented out for clarity
# URL location: https://access.redhat.com/downloads/content/480/ver=2.4/rhel---9/2.4/x86_64/product-software
# Link Example Format: https://access.cdn.redhat.com/content/origin/files/sha256/0d/XXXxXXXXXXXxxxxXX/ansible-automation-platform-setup-2.4-4.tar.gz?user=xxxxxxXXXXxxxxXXXX&_auth_=XXXXXxxxxxXXXXXXX
# Save your file as aap.tar.gz.

# Download the file using curl
if [ ! -f $HOME/aap.tar.gz ];then 
  cd $HOME
  curl -o aap.tar.gz "${AAP_LINK}" 
fi

# if  aap.tar.gz file size is 0 delete it and exit the script
if [ ! -s $HOME/aap.tar.gz ];then 
  rm $HOME/aap.tar.gz
  echo "Please download your aap.tar.gz file from https://access.redhat.com/downloads/content/480/ver=2.4/rhel---9/2.4/x86_64/product-software"
  echo "Update your .env file with the correct link and try again"
  exit 1
fi



# In order to use Automation controller you need to have a valid subscription via a manifest.zip file. To retrieve your manifest.zip file you need to download it from access.redhat.com.
# You have the steps in the Ansible Platform Documentation
# Go to Subscription Allocation and click "New Subscription Allocation"
# Enter a name for the allocation and select Satellite 6.8 as "Type".
# Add the subscription entitlements needed (click the tab and click "Add Subscriptions") where Ansible Automation Platform is available.
# Go back to "Details" tab and click "Export Manifest"
# Save apart your manifest.zip file.

if [ ! -f $HOME/manifest.zip ];then 
  echo "Please place your manifest.zip file in your home directory"
  exit 1
else 
    base64 $HOME/manifest.zip > base64_platform_manifest.txt || exit $?
fi

# Install System Packages
if [ ! -f /usr/bin/podman ]; then
    echo "Podman not found. Exiting..."
    exit 1
fi

result=$(whereis ansible-navigator)

# If the result only contains the name "ansible-navigator:" without a path, it means it's not installed
if [[ $result == "ansible-navigator" ]]; then
    echo "ansible-navigator not found. Exiting"
    exit 1
fi



read -p "Would you like to pull images from quay.io? (y/n): " pull_images

if [[ $pull_images == "y" ]]; then
  echo "podman login -u $QUAY_ROBOT_USER quay.io"
  echo "Please enter your quay.io password"
  podman login -u $QUAY_ROBOT_USER quay.io || exit $?

  skopeo copy docker://quay.io/luisarizmendi/2048:v1 docker://quay.io/$QUAY_USER/2048:v1
  skopeo copy docker://quay.io/luisarizmendi/2048:v2 docker://quay.io/$QUAY_USER/2048:v2
  skopeo copy docker://quay.io/luisarizmendi/2048:v3 docker://quay.io/$QUAY_USER/2048:v3
  skopeo copy docker://quay.io/luisarizmendi/2048:prod docker://quay.io/$QUAY_USER/2048:prod
  skopeo copy docker://quay.io/luisarizmendi/simple-http:v1 docker://quay.io/$QUAY_USER/simple-http:v1
  skopeo copy docker://quay.io/luisarizmendi/simple-http:v2 docker://quay.io/$QUAY_USER/simple-http:v2
  skopeo copy docker://quay.io/luisarizmendi/simple-http:prod docker://quay.io/$QUAY_USER/simple-http:prod
fi

if [ ! -d $HOME/device-edge-workshops ]; then
    cd $HOME
    git clone https://github.com/redhat-manufacturing/device-edge-workshops.git
    cd $HOME/device-edge-workshops
else
    cd $HOME/device-edge-workshops
    git pull
fi

if [ ! -f $HOME/rhde_gitops.yml ];
then 
  cp $HOME/device-edge-workshops/provisioner/example-extra-vars/rhde_gitops.yml $HOME/rhde_gitops.yml
fi 


# Would you like to update the vars file?
read -p "Would you like to update the vars file? (y/n): " update_vars

if [[ $update_vars == "y" ]]; then
  echo "Variable Inputs"
  echo "----------------"
  echo EAB_KID: $EAB_KID
  echo EAB_HMAC_KEY: $EAB_HMAC_KEY
  echo SLACK_TOKEN: $SLACK_TOKEN
  echo RH_OFFLINE_TOKEN: $RH_OFFLINE_TOKEN
  python3 $HOME/device-edge-deployer/device-edge-workshops/update_config.py  $HOME/rhde_gitops.yml
fi

# if ec2-user does not exist on your local server, create it
if [ ! -d /home/ec2-user ]; then
  curl -OL https://gist.githubusercontent.com/tosin2013/385054f345ff7129df6167631156fa2a/raw/b67866c8d0ec220c393ea83d2c7056f33c472e65/configure-sudo-user.sh
  chmod +x configure-sudo-user.sh
  ./configure-sudo-user.sh ec2-user 
fi

cp $HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops-local.yml $HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops.yml


#cp $HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops-external.yml $HOME/device-edge-workshops/provisioner/workshop_vars/rhde-gitops.yml

if [ ! -f $HOME/device-edge-workshops/provisioner/aap.tar.gz ]; then
  cp $HOME/aap.tar.gz $HOME/device-edge-workshops/provisioner/aap.tar.gz
fi

# Get primary interface name
# https://stackoverflow.com/questions/13322485/how-to-get-the-primary-ip-address-of-the-local-machine-on-linux-and-os-x

# Dynamically get the IP address of the local server
LOCAL_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
# ask for user password to be used for ansible_become_password and ansible_become_password
read -sp "Please enter your password: " password

cat > $HOME/device-edge-workshops/local-inventory.yml<<EOF
---
all:
  children:
    local:
      children:
        edge_local_management:
          hosts:
            edge-manager-local:
              ansible_host: ${LOCAL_IP} # Replace with the IP address of your local server
              ansible_user: ${USER} # Replace with the appropriate username
              ansible_password: ${password}  # Replace with the ansible user's password
              ansible_become_password: ${password}   # Replace with the become (sudo) password

              external_connection: eth0  # Connection name for the external connection
              internal_connection: eth0  # Interface name for the internal lab network

EOF


# Specify the directories
CERTS_DIR="/home/lab-user/workshop-certs/training.sandbox1190.opentlc.com"
EDA_DIR="/home/lab-user/workshop-build/eda"

# Create the directories if they don't exist
if [ ! -d "$CERTS_DIR" ]; then
    sudo mkdir -p "$CERTS_DIR"
fi

if [ ! -d "$EDA_DIR" ]; then
    sudo mkdir -p "$EDA_DIR"
fi

# Change ownership of the directories to root
sudo chown -R root:root "$CERTS_DIR"
sudo chown -R lab-user:lab-user "$EDA_DIR"

# Set permissions of the directory to 0644
sudo chmod 755 -R  "$EDA_DIR"

cd $HOME/device-edge-workshops/
echo "ansible-navigator run provisioner/provision_lab.yml --inventory local-inventory.yml --extra-vars @rhde_gitops.yml -m stdout -vvvv --become"
#ansible-navigator run provisioner/provision_lab.yml --inventory local-inventory.yml --extra-vars @rhde_gitops.yml -m stdout -vvvv --become

#ansible-navigator run provisioner/teardown_lab.yml --inventory local-inventory.yml --extra-vars @rhde_gitops.yml -m stdout -vvvv --become