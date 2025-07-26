# 🚀 AWS Architecture via Terraform

This project provisions a simple cloud infrastructure on AWS using Terraform. It deploys a basic web app behind a load balancer with auto-scaling capabilities.

---

## ✅ What It Sets Up

- Custom Virtual Private Cloud (VPC)
- Public subnets across multiple Availability Zones
- Dedicated NAT Gateway in each public subnet for high availability
- Private subnets with outbound access via their AZ’s NAT
- Internet Gateway and routing
- Security Groups for ALB and EC2
- Application Load Balancer (ALB)
- Auto Scaling Group (ASG) with EC2 instances
- EC2 launch template with user data to serve an HTML page
- DNS verification via ALB output

---

## 📦 Prerequisites

- AWS CLI installed and configured:
  ```bash
  aws configure
  ```
- Terraform v1.0 or later installed
- Valid AWS credentials with permission to create resources

---

## 📥 Clone and Configure

1. Clone this repository:

   ```bash
   git clone https://github.com/trushashah14/AWS-Architecture-using-Terraform.git
   cd AWS-Architecture-using-Terraform
   ```

2. Update AWS region, AZ, and AMI ID as needed:

   - In `provider.tf`:
     ```hcl
     provider "aws" {
       region = "us-east-1"  # Change this if you're deploying to another region
     }
     ```

   - In `sg_asg_alb.tf`:
     ```hcl
     image_id = "ami-0c94855ba95c71c99"  # Update this to a valid AMI ID in your region
     ```

   - In `vpc.tf`:
     ```hcl
     variable "vpc_availability_zones" {
     type        = list(string)                        
     description = "Availability Zones"                
     default     = ["us-west-1b", "us-west-1c"]      // Adjust this Two AZs according to the region 
     }
     ```
---

## 🔧 Usage

### 1. Initialize Terraform:

```bash
terraform init
```

### 2. Validate the configuration:

```bash
terraform validate
```

### 3. Apply and create resources:

```bash
terraform apply
```

> When prompted, type `yes` to confirm.

### 4. Access the App:

Terraform will output the ALB’s DNS name. Copy that URL into your browser — if setup was successful, you'll see your EC2-hosted HTML page!

---

## 🧨 Destroy Resources

To clean up everything after testing:

```bash
terraform destroy
```

> Confirm with `yes` when prompted.

---

## 📁 File Overview

- `provider.tf` – AWS provider configuration  
- `vpc.tf` – VPC, subnet, internet gateway, and routing  
- `sg_asg_alb.tf` – Security groups, ALB, ASG, launch template, listener  
- `userdata.sh` – EC2 startup script to install Apache and serve HTML  
- `README.md` – Documentation (this file)

---

# The same Architecture is build through AWS UI , refer this [document](https://docs.google.com/document/d/16x2zFxIRKabWw7mMnTvIER3ZO6jFdwp2rZwswtEyLZ8/edit?tab=t.0) for the steps 