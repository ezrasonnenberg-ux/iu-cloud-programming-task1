# Web Architecture on AWS with Terraform
**Course:** Cloud Programming (DLBSEPCP01_E)  
**Task 1:** Host a Simple Webpage on AWS (Development Phase Draft)

## 1. Project Overview
This project provides Infrastructure as Code (IaC) using **Terraform** to deploy a highly available, auto-scaling, and low-latency web architecture on Amazon Web Services (AWS) within Free Tier limits.

### Architecture Highlights
* **Amazon VPC:** Spans 2 Availability Zones (`eu-central-1a` and `eu-central-1b`) to ensure High Availability.
* **Application Load Balancer (ALB):** Distributes incoming web traffic across healthy web server instances.
* **Auto Scaling Group (ASG):** Automatically manages `t2.micro` EC2 instances running an Apache HTTP server.
* **Amazon CloudFront:** Global Content Delivery Network (CDN) caching webpage content at edge locations to minimize latency.
* **Security Groups:** Tiered access control (ALB accepts public HTTP traffic; EC2 instances accept traffic only from the ALB).

---

## 2. Repository Structure
* `main.tf`: Complete declarative configuration for VPC, subnets, security groups, ALB, Auto Scaling group, and CloudFront.
* `outputs.tf`: Outputs endpoints for the Application Load Balancer and CloudFront CDN.
* `README.md`: Project documentation and deployment instructions.

---

## 3. Deployment Instructions

### Prerequisites
1. An active [AWS Account](https://aws.amazon.com/free/) (Free Tier eligible).
2. [Terraform CLI](https://www.terraform.io/downloads) installed locally (version >= 1.0).
3. [AWS CLI](https://aws.amazon.com/cli/) configured with your AWS credentials:
   ```bash
   aws configure
