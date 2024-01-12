#!/bin/bash
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

  curl -o aap.tar.gz "${AAP_LINK}" 
fi

# if  aap.tar.gz file size is 0 delete it and exit the script
if [ ! -s $HOME/aap.tar.gz ];then 
  rm $HOME/aap.tar.gz
  echo "Please download your aap.tar.gz file from https://access.redhat.com/downloads/content/480/ver=2.4/rhel---9/2.4/x86_64/product-software"
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
    base64 manifest.zip > base64_platform_manifest.txt
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

echo "podman login -u $QUAY_ROBOT_USER quay.io"
echo "Please enter your quay.io password"
podman login -u $QUAY_ROBOT_USER quay.io || exit $?

quay.io/takinosh/simple-http

skopeo copy docker://quay.io/luisarizmendi/2048:v1 docker://quay.io/$QUAY_USER/2048:v1
skopeo copy docker://quay.io/luisarizmendi/2048:v2 docker://quay.io/$QUAY_USER/2048:v2
skopeo copy docker://quay.io/luisarizmendi/2048:v3 docker://quay.io/$QUAY_USER/2048:v3
skopeo copy docker://quay.io/luisarizmendi/2048:prod docker://quay.io/$QUAY_USER/2048:prod
skopeo copy docker://quay.io/luisarizmendi/simple-http:v1 docker://quay.io/$QUAY_USER/simple-http:v1
skopeo copy docker://quay.io/luisarizmendi/simple-http:v2 docker://quay.io/$QUAY_USER/simple-http:v2
skopeo copy docker://quay.io/luisarizmendi/simple-http:prod docker://quay.io/$QUAY_USER/simple-http:prod


if [ ! -f $HOME/device-edge-workshops ];then 
  git clone https://github.com/redhat-manufacturing/device-edge-workshops
fi 

if [ ! -f $HOME/rhde_gitops.yml ];
then 
    cp $HOME/device-edge-workshops/provisioner/example-extra-vars/rhde_gitops.yml $HOME/rhde_gitops.yml
fi 


python3 update_config.py  $HOME/rhde_gitops.yml

cp $HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops-local.yml $HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops.yml





cp $HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops-external.yml $HOME/device-edge-workshops/provisioner/workshop_vars/rhde-gitops.yml


mv  $HOME/aap.tar.gz $HOME/device-edge-workshops/provisioner/aap.tar.gz


cat > $HOME/device-edge-workshops/local-inventory.yml<<EOF
---
all:
  children:
    local:
      children:
        edge_local_management:
          hosts:
            edge-manager-local:
              ansible_host: 192.168.122.65  # Replace with the IP address of your local server
              ansible_user: cloud-user  # Replace with the appropriate username
              ansible_password: r3dh@t123  # Replace with the ansible user's password
              ansible_become_password: r3dh@t123   # Replace with the become (sudo) password

              external_connection: eth0  # Connection name for the external connection
              internal_connection: eth0  # Interface name for the internal lab network

EOF

cd $HOME/device-edge-workshops/
sudo -E ansible-navigator run provisioner/provision_lab.yml --inventory local-inventory.yml --extra-vars @rhde_gitops.yml -m stdout -vvvv