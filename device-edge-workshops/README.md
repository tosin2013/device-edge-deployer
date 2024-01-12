python update_config.py your_config_file.yaml


export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-east-2

ansible-navigator run provisioner/provision_lab.yml --inventory local-inventory.yml --extra-vars @rhde_gitops.yml -m stdout -vvvv


 ssh -i  provisioner/training.sandbox1190.opentlc.com/ssh-key.pem ec2-user@controller.training.sandbox1190.opentlc.com

 