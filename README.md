# character_register

Store the information about your roleplaying game characters in a database 
with API calls. This project uses Terraform and Kubernetes to get fast and safe 
deployments, and to serve as a reusable and portable pattern for future projects.

## Overview

The infrastructure is deployed to AWS using Terraform. The config creates the 
IAM resources necessary for SSH connections to the instances through Session 
Manager.

Kubeadm is used to manually deploy a Kubernetes cluster. [Calico][calico] is 
used for networking. The workload consists of a mysql database and a Flask API.

## Deployment

Before applying the Terraform configs, you must configure AWS authentication as 
described in the AWS provider [documentation][authentication].

1. Apply the terraform config. For additional input variables, see the section 
below.
```shell
terraform apply -var="allowed_cidr=<your_public_cidr_ip>" -var="ec2_key_pair=<your_ec2_key_pair>"
```
2. SSH into the k8s_master instance
3. Verify the control plane is running
```shell
kubectl cluster-info
```
4. Check the Calico pods, waiting until each pod shows a `STATUS` of `Running`
```shell
watch kubectl get pods -n calico-system
```
4. Generate the token and take note of the command to join nodes to the cluster
```shell
kubeadm token create --print-join-command
```
5. SSH into each k8s_worker instance and run the `kubeadm join` command
```shell
 sudo kubeadm join --token <token> <control-plane-host>:<control-plane-port> --discovery-token-ca-cert-hash sha256:<hash>
 ```
7. On the k8s_master instance, `kubectl apply` the `pv.yaml` manifest
8. `kubectl apply` the `mysql.yaml` manifest
9. Verify the service is running
10. `kubectl apply` the `flask.yaml` manifest

## Usage

Add a character
```shell
curl --header "Content-Type: application/json" --request POST --data '{"name":"Merlin","race":"Human","character_class":"Wizard","level":20,"hp":60}' <lb_dns_name>/add_character
```

List all characters
```shell
curl <lb_dns_name>/list_characters
```

## Input Variables

Below are the default values for the input variables. Pass your own values with 
the `terraform apply` command or write them to a tfvars file.

**NOTE:** If you change `flask_nodeport`, you will need to update `nodePort` in 
`flask.yaml` as well.

```terraform
allowed_cidr   = "0.0.0.0/0"
ec2_type       = "t3a.small"
ec2_key_pair   = ""
worker_count   = 2
flask_nodeport = 30066
```

[calico]: https://www.tigera.io/project-calico/
[authentication]: https://registry.terraform.io/providers/hashicorp/aws/2.42.0/docs#authentication
