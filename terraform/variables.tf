variable "allowed_cidr" {
  description = "CIDR IP address that will be allowed to access the API. Defaults to the insecure 0.0.0.0/0"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))$", var.allowed_cidr))
    error_message = "The allowed_cidr value must be a valid CIDR address."
  }
}

variable "worker_count" {
  description = "The number of EC2 instances to create as Kubernetes worker nodes"
  type        = number
  default     = 1
}

variable "ec2_type" {
  description = "The EC2 instance type to be deployed"
  type        = string
  default     = "t2.micro"
}

variable "ec2_key_pair" {
  description = "EC2 key pair assigned to the instances."
  type        = string
  default     = ""
}

variable "flask_nodeport" {
  description = "NodePort used for flask API."
  type        = number
  default     = 30690
}

variable "pod_network_cidr" {
  description = "Pod network CIDR"
  type        = string
  default     = "192.168.0.0/16"
}
