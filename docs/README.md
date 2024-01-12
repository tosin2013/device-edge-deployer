# Run workflows using Ansible Navigator

**Install Ansible Automation Platform**
```
$ ansible-navigator run demos/rhde-pipeline/playbooks/configure-standalone-openshift.yaml -t install_ansible -m stdout # --vault-password-file $HOME/.vault_password 
```

**Register Ansible Automation Platform**
*To-Do add to automation*

**Update vault.yaml**
```
$ INVENTORY="vmc"
$ vim inventories/${INVENTORY}/group_vars/sno_clusters/vault.yaml

controller_hostname: CHANGEME
controller_password: CHANGEME
```

**Configure Ansible Automation Platform**
```
$ ansible-navigator run demos/rhde-pipeline/playbooks/configure-standalone-openshift.yaml -t configure_controller  -m stdout
```

[Configure OpenShift Virtualization for Pipelines](configure-openshift-virtualization.md)


**Configure Ansible Automation Platform - Secrets**
```
$ ansible-navigator run demos/rhde-pipeline/playbooks/configure-standalone-openshift.yaml  -t configure_secrets  -m stdout
```

**Install OpenShift Pipelines**
```
$ ansible-navigator run demos/rhde-pipeline/playbooks/configure-standalone-openshift.yaml -t  configure_pipelines -m stdout
```


[Run OpenShift pipeline edge tasks on OpenShift Virt](tkn-tasks.md)
[Run Build Pipelines using AWS External Image Builder](aws-external-image-builder.md)