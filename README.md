# Project Title: AWS Serverless Static Website (S3 + CloudFront + Terraform)

## Project Overview

- The goal of this project was to deploy a high available, global website while minimizing operational costs and user latency. Instead of managing a traditional web sever (like EC2), this architecture uses a fully serverless approach with Amazon S3 for storage and Amazon CloudFront as a Delivery Network (CDN). The entire infrastructure is provisioned and managed using Terraform (Infrastructure as a Code).

## Architecture Flow

The architecture is designed with security and performance in mind.

## User Request Flow:

- User -> CloudFront -> (Edge Location) -> Origin Access Control (OAC) -> Private S3 Bucket

- User: Requests the website via HTTPS.
- CloudFront: Caches the content globally to reduce the latency for the end user. it also enforces HTTPS.
- OAC (origin Access Control): A security mechanism that signs the request from CloudFront to S3.
- S3 Bucket: Remains completely private (Block public access enabled). it will only accept requests from this specific cloudfront distribution.

# Challenges & Debugging(Real-World Experience)

During th Deployment, I encountered a few classic AWS networking and configuration issues:

1. The 403 Access Denied Error

   - The issue: After configuring S3, OAC, and cloudFront, visiting the CloudFront URL returned a 403 Access Denied XML error.
   - The Root Cause: This was not an IAM or bucket policy permission issue. The issue was the Default Root Object setting on the CloudFront distribution. When a user visits the root URL (/), CloudFront forwards that exact path to S3. Because S3 does not have a file named /, it denied the request.
   - The Fix: I updated the CloudFront distribution settings to specify index.html as the default_root_object. This ensures CloudFront rewrites root requests to index.html before asking S3 for the file.

2. The Missing OAC Signature

   - The Issue: Even after fixing the root object, requests were still failing.

   - the Root Cause: The Origin Access Control (OAC) was created but not properly attached to the CloudFront origin, and the signing behavior was incorrect.

   - The Fix: I ensured the OAC was set to "Sign requests" and updated the S3 Bucket Policy to use StringEquals to strictly match the CloudFront distribution's ARN.

## Why Terraform? (Infrastructure as Code)

- While this could have been built manually in the AWS Console, using Terraform was a deliberate choice:

- Reusability & Speed: Clicking through the console for multiple services is time-consuming and prone to human error. Terraform allows me to deploy the entire stack in seconds.

- State Management: Terraform tracks the state of the infrastructure. If a resource is accidentally deleted, running terraform apply restores it to the desired state.

- Implicit Dependencies: Terraform automatically understands the order of operations. For example, it knows it must create the CloudFront distribution before it can write the S3 Bucket Policy that references the CloudFront ARN.

## How to Deploy

- Ensure you have the AWS CLI installed and configured with an IAM User (never the Root account).

- Clone this repository.

- Navigate to the Terraform directory: cd terraform

- Initialize the directory: terraform init

- Review the resources to be created: terraform plan

- Deploy the infrastructure: terraform apply
