# Device Edge Deployer 


### Pre-requisites
```
# sudo subscription-manager register
# sudo subscription-manager refresh
# subscription-manager list --available --all | grep "Ansible Automation Platform" -B 3 -A 6
# subscription-manager attach --pool=POOL_ID 
```

```
sudo su - 
git clone https://github.com/tosin2013/device-edge-deployer.git
cd device-edge-deployer
./hack/setup-bastion.sh
```

```

$ cd $HOME/device-edge-deployer
$ cp /tmp/baremetal-playbooks/env-tempate.txt .
$ cp /tmp/baremetal-playbooks/extra-vars.yml /home/cloud-user/extra-vars.yml
$ ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''
$ vim /home/cloud-user/extra-vars.yml
$ ssh-copy-id $USER@192.168.1.10
$ cp /tmp/baremetal-playbooks/manifest.zip ~/
$ ./device-edge-workshops/rhel8_equinix_quickstart_script_internal.sh
```
