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

if [ ! -f $HOME/extra-vars.yml ]; then
    echo "Please create a $HOME/extra-vars.yml"
    echo "https://github.com/redhat-manufacturing/device-edge-workshops/blob/gitops-demo/provisioner/example-extra-vars/rhde_gitops.yml"
    exit 1
fi

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

if [ ! -f $HOME/manifest.zip ];then 
  echo "Please place your manifest.zip file in your home directory"
  echo "cp /tmp/manifest_tower-XXXXX.zip $HOME/manifest.zip"
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

if [ ! -f $HOME/extra-vars.yml ]; then
    echo "$HOME/extra-vars.yml not found. Exiting..."
    echo "See The link below for more information"
    echo "https://raw.githubusercontent.com/redhat-manufacturing/device-edge-workshops/gitops-demo/provisioner/example-extra-vars/rhde_gitops.yml"
fi

# if ec2-user does not exist on your local server, create it
if [ ! -d /home/ec2-user ]; then
  curl -OL https://gist.githubusercontent.com/tosin2013/385054f345ff7129df6167631156fa2a/raw/b67866c8d0ec220c393ea83d2c7056f33c472e65/configure-sudo-user.sh
  chmod +x configure-sudo-user.sh
  sudo ./configure-sudo-user.sh ec2-user 
fi

# Ask user would you like to perform a internal or external workshop
read -p "Would you like to perform a internal or external workshop? (i/e): " workshop_type
if [[ $workshop_type == "i" ]]; then
  cp $HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops-local.yml $HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops.yml || exit $?
else
  cp $HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops-external.yml $HOME/device-edge-workshops/provisioner/workshop_vars/rhde-gitops.yml || exit $?
fi

$HOME/device-edge-workshops/provisioner/workshop_vars/rhde_gitops-external.yml $HOME/device-edge-workshops/provisioner/demo_vars/rhde_gitops.yml

if [ ! -f $HOME/device-edge-workshops/provisioner/aap.tar.gz ]; then
  cp $HOME/aap.tar.gz $HOME/device-edge-workshops/provisioner/aap.tar.gz
fi

# Get primary interface name
# https://stackoverflow.com/questions/13322485/how-to-get-the-primary-ip-address-of-the-local-machine-on-linux-and-os-x

# Get the current network interface and store it in a variable
network_interface=$(ifconfig | grep -oE '^[a-zA-Z0-9]+' | head -n 1)

# Print the network interface to verify
echo "Current network interface: $network_interface"

# Dynamically get the IP address of the local server
LOCAL_IP=$(ip addr show $network_interface | grep "inet\b" | awk '{print $2}' | cut -d/ -f1 | head -1)

# ask for user password to be used for ansible_become_password and ansible_become_password
read -sp "Please enter your password: " password

if [[ $workshop_type == "i" ]]; then
cat > $HOME/device-edge-workshops/local-inventory.yml<<EOF
all:
  children:
    local:
      children:
        edge_management:
          hosts:
            edge-manager-local:
              ansible_host: ${LOCAL_IP}
              ansible_user: cloud-user
              ansible_password:  ${password}
              ansible_become_password:  ${password}

              external_connection: eth0
              internal_connection: eth1 # Interface name for the internal lab network
EOF
elif [[ $workshop_type == "e" ]]; then
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
              ansible_user: cloud-user # Replace with the appropriate username
              ansible_password: ${password}  # Replace with the ansible user's password
              ansible_become_password: ${password}   # Replace with the become (sudo) password

              external_connection: eth0 # Connection name for the external connection
              internal_connection: eth1  # Interface name for the internal lab network

EOF
fi 
# Check if the environment variables exist
source .env
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ]; then
  echo "Missing required environment variables. Exiting..."
  echo "Please set the following environment variables:"
  echo "
  export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY
  export AWS_DEFAULT_REGION=us-east-2"
  exit 1
fi

# Specify the directories
CERTS_DIR="/home/${USER}/workshop-certs/external.${ROUTE53}.opentlc.com"
EDA_DIR="/home/${USER}/workshop-build/eda"

# Create the directories if they don't exist
if [ ! -d "$CERTS_DIR" ]; then
  sudo mkdir -p "$CERTS_DIR"
fi

if [ ! -d "$EDA_DIR" ]; then
  sudo mkdir -p "$EDA_DIR"
fi

# Change ownership of the directories to root
sudo chown -R root:root "$CERTS_DIR"
sudo chown -R ${USER}:${USER} "$EDA_DIR"

# Set permissions of the directory to 0644
sudo chmod 755 -R  "$EDA_DIR"
sudo chown -R ${USER}:${USER} /home/${USER}/workshop-build
sudo chown -R ${USER}:${USER} /home/${USER}/workshop-certs

cp $HOME/extra-vars.yml $HOME/device-edge-workshops/extra-vars.yml

# Specify the directories
CERTS_DIR="/home/${USER}/workshop-certs/training.sandbox1190.opentlc.com"
EDA_DIR="/home/${USER}/workshop-build/eda"

# Create the directories if they don't exist
if [ ! -d "$CERTS_DIR" ]; then
    sudo mkdir -p "$CERTS_DIR"
fi

if [ ! -d "$EDA_DIR" ]; then
    sudo mkdir -p "$EDA_DIR"
fi

# Change ownership of the directories to root
sudo chown -R root:root "$CERTS_DIR"
sudo chown -R ${USER}:${USER} "$EDA_DIR"

# Set permissions of the directory to 0644
sudo chmod 755 -R  "$EDA_DIR"
sudo chown -R ${USER}:${USER} /home/${USER}/workshop-build
sudo chown -R ${USER}:${USER} /home/${USER}/workshop-certs


cp $HOME/extra-vars.yml $HOME/device-edge-workshops/extra-vars.yml
cp $HOME/manifest.zip  $HOME/device-edge-workshops/provisioner/
echo -e "cd $HOME/device-edge-workshops/\n"
echo -e "ansible-navigator run provisioner/provision_lab.yml --inventory local-inventory.yml --extra-vars @extra-vars.yml -m stdout -vv --become"
#ansible-navigator run provisioner/provision_lab.yml --inventory local-inventory.yml --extra-vars @extra-vars.yml -m stdout -vvvv --become

#ansible-navigator run provisioner/teardown_lab.yml --inventory local-inventory.yml --extra-vars @extra-vars.yml -m stdout -vvvv --become


#ansible-navigator run provisioner/provision_lab.yml --inventory local-inventory.yml --extra-vars "ansible_user=root" --extra-vars @extra-vars.yml -m stdout -vv --become



#### EXTERNAL Mode
* Failed on first run 
* Failed n second run
* On third 
```
run TASK [../roles/workshop_local_network : add nm conn for workshop] **************
task path: /root/device-edge-workshops/roles/workshop_local_network/tasks/setup-connection.yml:27
fatal: [edge-manager-local]: FAILED! => {"changed": false, "msg": "Error: Connection activation failed: No suitable device found for this connection (device eno1 not available because profile is not compatible with device (mismatching interface name)).\n", "name": "rhde_gitops-workshop", "rc": 4}

    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eno1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether 3c:ec:ef:72:01:86 brd ff:ff:ff:ff:ff:ff
    altname enp4s0
3: eno2: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether 3c:ec:ef:72:01:87 brd ff:ff:ff:ff:ff:ff
    altname enp5s0
4: enp2s0f0: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc mq master bond0 state UP group default qlen 1000
    link/ether 04:3f:72:d7:6e:f2 brd ff:ff:ff:ff:ff:ff
5: enp2s0f1: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc mq master bond0 state UP group default qlen 1000
    link/ether 04:3f:72:d7:6e:f2 brd ff:ff:ff:ff:ff:ff permaddr 04:3f:72:d7:6e:f3
6: bond0: <BROADCAST,MULTICAST,MASTER,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 04:3f:72:d7:6e:f2 brd ff:ff:ff:ff:ff:ff
    inet 147.28.151.239/31 scope global noprefixroute bond0
       valid_lft forever preferred_lft forever
    inet 10.68.72.129/31 scope global noprefixroute bond0:0
       valid_lft forever preferred_lft forever
    inet6 2604:1380:45f1:7000::1/127 scope global noprefixroute
       valid_lft forever preferred_lft forever
    inet6 fe80::63f:72ff:fed7:6ef2/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
7: cni-podman0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether b2:16:8f:95:4f:5a brd ff:ff:ff:ff:ff:ff
    inet 10.88.0.1/16 brd 10.88.255.255 scope global cni-podman0
       valid_lft forever preferred_lft forever
    inet6 fe80::b016:8fff:fe95:4f5a/64 scope link
       valid_lft forever preferred_lft forever
10: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 52:54:00:3d:02:f7 brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
       valid_lft forever preferred_lft forever


cat local-inventory.yml
---
all:
  children:
    local:
      children:
        edge_local_management:
          hosts:
            edge-manager-local:
              ansible_host: 44.55.55.10 # Replace with the IP address of your local server
              ansible_user: lab-user # Replace with the appropriate username
              ansible_password: change  # Replace with the ansible user's password
              ansible_become_password: change   # Replace with the become (sudo) password

              external_connection: bond0  # Connection name for the external connection
              internal_connection: bond0  # Interface name for the internal lab network

```