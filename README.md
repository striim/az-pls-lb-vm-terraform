# Please read carefully before you apply this script

This script will create a public IP address, a VM, an internal Load Balancer with NAT rules, and an Azure Private Link Service. You will get charged for these Azure resources. Before using this Terraform script, you are agreeing to the following:

1. You have an Azure vNet and subnet created.
2. You have an active VPN between your Azure vNet and the on-prem/AWS/GCP network.
3. You can access your on-prem/AWS/GCP database from that Azure vNet.

## Disclaimer
You agree that Striim is not responsible for creating, deleting, or managing any Azure resources and is not liable for any associated costs in your Azure account.

## To create resources:
```sh
terraform init
terraform plan -var-file="pass_values.tfvars"
terraform apply -var-file="pass_values.tfvars" -auto-approve
```

## To delete all resources:
```sh
terraform destroy -var-file="pass_values.tfvars" -auto-approve
```

## Some additional commands you might need:
### Export your SSH key to local (for Linux VM):
```sh
terraform output -raw ssh_private_key > ~/.ssh/<striim-integration-key>
chmod 600 ~/.ssh/<striim-integration-key>
```

### To connect to the Linux VM:
```sh
ssh -i ~/.ssh/<striim-integration-key> azureuser@<vm-ip-address>
```

### Linux command to see iptables rules:
```sh
sudo iptables -t nat -nvL
```

### Optionally, to create a port forwarding rule manually:
```sh
iptables -t nat -A PREROUTING -p tcp --dport SOURCE_PORT1 -j DNAT --to-destination DESTINATION_IP1:${DESTINATION_PORT1}
iptables -t nat -A POSTROUTING -p tcp -d DESTINATION_IP1 --dport DESTINATION_PORT1 -j SNAT --to-source $(hostname -i)
iptables-save
```

### Windows commands:
#### To see port forwarding rules:
```sh
netsh interface portproxy show all
```
#### To create a new rule:
```sh
netsh interface portproxy add v4tov4 listenport=<database-port> listenaddress=0.0.0.0 connectport=<database-port> connectaddress=<database-ip-address>
```
![striim-integration](https://github.com/user-attachments/assets/1a40636c-d9fd-4040-876c-ff2657a9378c)

