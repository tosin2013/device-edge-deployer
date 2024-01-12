# Run OpenShift pipeline edge tasks on OpenShift Virt

## Requirements 
* login to OpenShift
* Install tkn cli

### Install tkn cli
**Get the tar.xz**
```
curl -LO https://github.com/tektoncd/cli/releases/download/v0.31.1/tkn_0.31.1_Linux_x86_64.tar.gz
```

**Extract tkn to your PATH (e.g. /usr/local/bin)**
```
sudo tar xvzf tkn_0.31.1_Linux_x86_64.tar.gz -C /usr/local/bin/ tkn
```

### Start testing
```
oc project image-builder
```


### Create VM from template
```
tkn clustertask start create-vm-from-template \
  -p templateName=rhel9-image-builder-template \
  -p templateNamespace=image-builder \
  -p vmNamespace=image-builder \
  -p runStrategy=RerunOnFailure \
  -p startVM=true
```

### Expose virtual machine SSH
```
$ tkn taskrun list
$ GET_TASK_RUN=$(tkn taskrun list | grep create-vm-from-template-run | awk '{print $1}')
$ VM_NAME=$(tkn taskrun logs  ${GET_TASK_RUN}  | grep "app:" | head -1 | awk '{print $3}')
$ tkn task start manage-virtual-machine-connectivity \
  -p virtualMachineName="$VM_NAME"
```

### Create host in controller
```
tkn task start manage-host-in-controller \
  -p virtualMachineName="$VM_NAME"
```

### Preconfigure virtual machine on OpenShift
```
tkn task start preconfigure-virtual-machine \
  -p virtualMachineName="$VM_NAME"
```
### Install image builder
```
tkn task start install-image-builder \
  -p virtualMachineName="$VM_NAME"
```

### Expose image builder
```
tkn task start manage-image-builder-connectivity \
  -p virtualMachineName="$VM_NAME"
```

### Compose image
```
tkn task start compose-image \
  -p virtualMachineName="$VM_NAME"
```

### Push image to registry
```
tkn task start push-image-to-registry \
  -p virtualMachineName="$VM_NAME"
```

### Deploy composed image
```
tkn task start deploy-composed-image \
  -p virtualMachineName="$VM_NAME"
````