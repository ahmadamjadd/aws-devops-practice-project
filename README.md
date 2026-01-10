# AWS DevOps Practice: End-to-End CI/CD with Terraform & ECS Fargate

## 🚀 Project Overview
This project demonstrates a fully automated **Infrastructure as Code (IaC)** deployment using **Terraform**. It sets up a complete CI/CD pipeline on AWS to build, secure, and deploy a containerized Python application to **Amazon ECS (Elastic Container Service)** using the **Fargate** serverless launch type.

The entire infrastructure—from networking to the deployment pipeline—is provisioned automatically with Terraform.

## 🏗️ Architecture
* **Infrastructure:** Terraform (Modularized)
* **Container Registry:** Amazon ECR (Elastic Container Registry)
* **Orchestration:** Amazon ECS (Fargate)
* **CI/CD Pipeline:** AWS CodePipeline
* **Build Service:** AWS CodeBuild
* **Source Control:** GitHub (via AWS CodeStar Connections)
* **Artifact Storage:** Amazon S3

## 📂 Project Structure
The Terraform code is modularized for readability and maintainability:
* `provider.tf`: AWS provider configuration.
* `network.tf`: Networking lookups (VPC, Subnets).
* `iam.tf`: Roles and Policies (Least Privilege Principle).
* `ecs.tf`: ECS Cluster, Service, Task Definitions, and ECR.
* `pipeline.tf`: CodePipeline, CodeBuild project, and GitHub connection.
* `account_details.tf`: Data sources for dynamic Account ID and Region fetching.
* `buildspec.yml`: Build instructions for CodeBuild.

## 🛠️ Prerequisites
Before running this project, ensure you have:
1.  **Terraform installed** (v1.0+).
2.  **AWS CLI configured** with valid credentials (`aws configure`).
3.  **GitHub Account** and a repository containing this code.

## ⚙️ Configuration
**Before running the code, you must update one setting:**

1.  Open `pipeline.tf`.
2.  Find the `source` stage inside the `aws_codepipeline` resource.
3.  Update the `FullRepositoryId` to match your own GitHub repository:
    ```hcl
    FullRepositoryId = "YOUR_GITHUB_USERNAME/YOUR_REPO_NAME"
    ```

## 🚀 How to Run (Deployment Guide)

### Step 1: Initialize Terraform
Download the necessary providers.
```bash
terraform init
```

### Step 2: Review the Plan
See what resources will be created..
```bash
terraform init
```

### Step 3: Apply the Infrastructurem
Provision the resources on AWS.
```bash
terraform apply --auto-approve
```

### ⚠️ CRITICAL STEP: Connect GitHub (Do not skip!)
After `terraform apply` finishes, the pipeline will **fail** initially. This is normal! You must manually authorize AWS to access your GitHub account.

1.  Log in to the **AWS Console**.
2.  Go to **Developer Tools** > **Settings** > **Connections**.
3.  Find the connection named `github-connection`.
4.  You will see its status is **Pending**.
5.  Click on it and press **"Update Pending Connection"**.
6.  Follow the pop-up instructions to authorize the AWS Connector App on GitHub.
7.  Once the status turns **Available** (Green), go to **CodePipeline** and click **"Release Change"** to restart the pipeline.

### Step 4: Access the Application
1.  Go to the **Amazon ECS Console**.
2.  Click on the Cluster `my-python-cluster` -> Service `my-python-service`.
3.  Click on the **Tasks** tab and select the running task.
4.  Find the **Public IP** address in the task details.
5.  Open the IP in your browser:
    ```text
    http://<PUBLIC-IP>:5000
    ```

## 🧹 Cleanup
To avoid incurring charges, destroy the infrastructure when you are done:
```bash
terraform destroy --auto-approve
```

## 🔧 Troubleshooting
**Issue: "Repository does not exist"**
* Ensure your `buildspec.yml` uses the environment variables (`$IMAGE_REPO_NAME`) rather than hardcoded names.
* Ensure the `aws_ecr_repository` resource in Terraform matches the name expected by CodeBuild.

**Issue: Pipeline fails at Source stage**
* Check your GitHub Connection status in the AWS Console. It must be **Available**.

