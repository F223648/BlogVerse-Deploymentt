# Assignment 4: CI/CD Pipeline on AWS

This repository models a fully functional CI/CD pipeline built around Jenkins, SonarQube, Terraform, Docker, and AWS.

## Directory Structure
- `app/`: Sample Node.js application containing the web app, tests, and Dockerfile.
- `jenkins/`: Terraform module for provisioning the Jenkins Controller & Agent instances. Includes `setup.md`.
- `pipelines/`: Secondary Jenkinsfiles (`infra-pipeline.jenkinsfile`, `rollback.jenkinsfile`).
- `modules/`: Underlying VPC, Compute, and Security Terraform modules.
- `Jenkinsfile`: The main declarative pipeline managing application stages (Build, Test, Scan, Push, Deploy).

*Note: The groovy shared library resides in its own repository according to the spec: `jenkins-shared-library`.*

## Prerequisites
- AWS Account configured locally (Administrator permissions).
- GitHub Personal Access Token (for Jenkins to clone repos).
- (Optional) Slack webhook for receiving build notifications.

## 1. Initial Infrastructure Bring-Up
First, deploy everything by running Terraform from the root repository:
```bash
terraform init
terraform plan
terraform apply --auto-approve
```
This deploys:
- Networking stack (VPC, Subnets)
- Jenkins Controller (Public Subnet) & Jenkins Agent (Private Subnet)
- SonarQube Server
- ECR Repository
- Blue/Green ASG & ALB Infrastructure

## 2. Setting Up Jenkins & SonarQube
1. Access Jenkins UI via the IP output from Terraform: `terraform output jenkins_controller_url`.
2. Grab the admin initial password from the controller by following `jenkins/setup.md`.
3. Configure the `linux-agent`, AWS/GitHub Credentials, and the SonarQube token.
4. Add the *Global Pipeline Library* (`jenkins-shared-library`) pointing to your actual GitHub URL.
   
For SonarQube: Access it on Port 9000 using `admin/admin`, force a password reset, and generate a Global Analysis Token.

## 3. Running the Pipelines
Create the following pipeline jobs in Jenkins:

### The Application Pipeline (Multibranch)
- **Type**: Multibranch Pipeline
- **Source**: Your assignment GitHub repository containing `Jenkinsfile`.
- **Behavior**: Will automatically trigger the CI/CD pipeline out to the Blue-Green staging deployment using AWS ECR and Launch Template updates.

### The Infra Pipeline (Standard Pipeline)
- **Type**: Pipeline Job (Parameterized)
- **Configuration Path**: `pipelines/infra-pipeline.jenkinsfile`.
- **Parameters**: ACTION (plan, apply, destroy), AUTO_APPROVE.
- **Behavior**: Facilitates automated Terraform syntax lint checks, `tfsec` scanning, and execution.

### The Rollback Pipeline (Standard Pipeline)
- **Type**: Pipeline Job
- **Configuration Path**: `pipelines/rollback.jenkinsfile`.
- **Behavior**: If a deployment slips past testing onto the Live target group, this manually kicks the ALB listener back to the prior color target group.

## 4. Teardown
To cleanly destroy all AWS resources created:
```bash
terraform destroy
```

## Contribution Table
| Name | Roll Number | Contribution |
|------|-------------|--------------|
| Student A | 1234 | Jenkins Setup, Pipeline |
| Student B | 5678 | Terraform Blue-Green |
