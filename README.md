# Picus SRE Case Study

A serverless hybrid application demonstrating modern cloud architecture with Flask, DynamoDB, AWS ECS Fargate, AWS Lambda, and Application Load Balancer - all deployed with zero-downtime via GitHub Actions and Terraform.

## Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security](#security)

## Architecture

```
┌─────────┐
│  User   │
└────┬────┘
     │ HTTPS
     ▼
┌─────────────────────┐
│  Application Load   │
│     Balancer        │  (Port 443 HTTPS + 80→443 Redirect)
└──────┬──────┬───────┘
       │      │
       │      │  DELETE /picus/*
       │      └──────────────────┐
       │                         │
       │ GET/POST /picus/*       │
       ▼                         ▼
┌──────────────┐         ┌──────────────┐
│ ECS Fargate  │         │   Lambda     │
│   Service    │         │  Function    │
└──────┬───────┘         └──────┬───────┘
       │                         │
       └────────┬────────────────┘
                │
                ▼
        ┌──────────────┐
        │  DynamoDB    │
        │    Table     │
        └──────────────┘
```

### Request Routing

- **GET /picus/list** → ECS Fargate (List all items)
- **POST /picus/put** → ECS Fargate (Create item)
- **GET /picus/get/{key}** → ECS Fargate (Retrieve item)
- **DELETE /picus/{key}** → Lambda Function (Delete item)
- **GET /health** → ECS Fargate (Health check)

## Features

- **Hybrid Architecture**: ECS Fargate + AWS Lambda with ALB routing
- **Zero-Downtime Deployment**: Rolling updates with health checks and circuit breaker
- **HTTPS by Default**: ACM certificate with TLS 1.3 and automatic HTTP redirect
- **Infrastructure as Code**: Complete Terraform setup (45+ resources)
- **CI/CD Automation**: Separate GitHub Actions pipelines for ECS and Lambda
- **Security Hardened**: Least privilege IAM, encryption at rest, private subnets

## Quick Start

### Complete Deployment (~20-25 minutes)

#### 1. Deploy Infrastructure (10-15 minutes)

```bash
cd terraform
terraform init
terraform plan
terraform apply  # Type 'yes' to confirm
```

**Save these outputs:**
```bash
export ECR_REPO=$(terraform output -raw ecr_repository_url)
export ALB_DNS=$(terraform output -raw alb_dns_name)
export TABLE_NAME=$(terraform output -raw dynamodb_table_name)
```

#### 2. Build and Push Docker Image (5-8 minutes)

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REPO

# Build and push (AMD64 architecture for ECS compatibility)
docker build --platform linux/amd64 -t picus-app:latest .
docker tag picus-app:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

**Note**: Use `--platform linux/amd64` especially when building on Apple Silicon (ARM64) Macs.

#### 3. Deploy ECS Service (2-3 minutes)

```bash
aws ecs update-service \
  --cluster picus-cluster \
  --service picus-service \
  --force-new-deployment \
  --region us-east-1
```

#### 4. Deploy Lambda Function (2-3 minutes)

```bash
cd lambda
npm install
npx serverless deploy --stage dev --region us-east-1
```

#### 5. Connect Lambda to ALB (1-2 minutes)

```bash
# Get Lambda ARN
LAMBDA_ARN=$(aws lambda get-function \
  --function-name picus-dev-delete \
  --query 'Configuration.FunctionArn' \
  --output text \
  --region us-east-1)

# Get Target Group ARN
cd terraform
TG_ARN=$(terraform output -raw lambda_target_group_arn)
cd ..

# Grant ALB permission to invoke Lambda
aws lambda add-permission \
  --function-name picus-dev-delete \
  --statement-id AllowALBInvoke \
  --action lambda:InvokeFunction \
  --principal elasticloadbalancing.amazonaws.com \
  --source-arn $TG_ARN \
  --region us-east-1

# Register Lambda with ALB
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$LAMBDA_ARN \
  --region us-east-1
```

#### 6. Test Deployment

```bash
# Health check (HTTPS)
curl https://app.fatihkoc.net/health

# Create an item
ITEM_ID=$(curl -X POST https://app.fatihkoc.net/picus/put \
  -H "Content-Type: application/json" \
  -d '{"data": {"test": "deployment", "timestamp": "'$(date +%s)'"}}' \
  | jq -r '.id')

echo "Created item: $ITEM_ID"

# List items
curl https://app.fatihkoc.net/picus/list | jq

# Get item
curl https://app.fatihkoc.net/picus/get/$ITEM_ID | jq

# Delete item (Lambda)
curl -X DELETE https://app.fatihkoc.net/picus/$ITEM_ID | jq

# Test HTTP to HTTPS redirect
curl -I http://app.fatihkoc.net/health
# Should return: HTTP/1.1 301 Moved Permanently
```

### Zero-Downtime Deployment

The application achieves zero-downtime through:
1. **Minimum Healthy Percent**: 100% (keeps all tasks running)
2. **Maximum Percent**: 200% (starts new tasks before stopping old)
3. **Health Checks**: ALB only routes to healthy tasks
4. **Deployment Circuit Breaker**: Auto-rollback on failures
5. **Rolling Updates**: Gradual task replacement

## Project Structure

```
serverless-practice/
├── .github/
│   └── workflows/
│       ├── deploy-ecs.yml      # ECS deployment pipeline
│       ├── deploy-lambda.yml   # Lambda deployment pipeline
│       └── README.md           # Workflows documentation
├── app/
│   ├── __init__.py
│   ├── main.py                 # Flask application
│   └── requirements.txt        # Python dependencies
├── lambda/
│   ├── handler.py              # DELETE endpoint Lambda
│   ├── serverless.yml          # Serverless Framework config
│   ├── requirements.txt        # Lambda dependencies
│   └── package.json            # NPM dependencies
├── terraform/
│   ├── main.tf                 # VPC, networking, security groups
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── dynamodb.tf             # DynamoDB table
│   ├── ecs.tf                  # ECS cluster, service, task
│   ├── alb.tf                  # ALB, target groups, HTTPS/HTTP listeners
│   ├── acm.tf                  # ACM certificate and DNS validation
│   ├── route53.tf              # DNS records
│   ├── iam.tf                  # IAM roles and policies
│   └── ecr.tf                  # ECR repository
├── Dockerfile                  # Multi-stage Docker build
├── .dockerignore              # Docker ignore patterns
├── .gitignore                 # Git ignore patterns
├── .cursorignore              # Cursor ignore patterns
├── .cursorrules               # Coding guidelines
└── README.md                  # This file
```

## Automated Deployment via GitHub Actions

### 1. Configure GitHub Secrets

Add to your repository (Settings → Secrets → Actions):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 2. Push to Main Branch

```bash
git add .
git commit -m "feat: initial deployment"
git push origin main
```

GitHub Actions automatically:
1. Runs tests and linting
2. Builds and pushes Docker image to ECR
3. Deploys Lambda function with Serverless
4. Updates ECS service with new image
5. Runs integration tests

## CI/CD Pipeline

This project uses **separate GitHub Actions workflows** for independent component deployment:

### ECS Pipeline (`deploy-ecs.yml`)

**Triggers:** Changes to `app/`, `Dockerfile`, or manual dispatch

**Jobs:**
1. **Test** - Python linting, formatting, and unit tests
2. **Build & Push** - Docker image build (AMD64) with layer caching to ECR
3. **Deploy ECS** - Zero-downtime deployment to ECS Fargate
4. **Integration Tests** - Validate all API endpoints

### Lambda Pipeline (`deploy-lambda.yml`)

**Triggers:** Changes to `lambda/` or manual dispatch

**Jobs:**
1. **Security Checks** - NPM audit, Python CVE scanning, SAST, IAM validation
2. **Deploy Lambda** - Serverless Framework deployment
3. **Test Lambda** - Validate DELETE endpoint via application

## Security

### IAM Roles & Policies
- **Least Privilege**: Each service has minimal required permissions
- **ECS Task Role**: DynamoDB read/write only
- **Lambda Role**: DynamoDB delete and get only
- **Task Execution Role**: ECR pull and CloudWatch logs

### Network Security
- **Private Subnets**: ECS tasks run in private subnets
- **Security Groups**: ALB allows 80/443, ECS only from ALB
- **NAT Gateway**: Outbound internet access for private subnets

### Data Security
- **DynamoDB**: Encryption at rest enabled
- **ECR**: Image scanning on push enabled
- **Secrets**: Use AWS Secrets Manager (not environment variables)

### Best Practices Implemented
- No hardcoded credentials
- HTTPS enabled with ACM certificate
- Automatic HTTP to HTTPS redirect
- TLS 1.3 security policy
- IAM roles instead of access keys
- Security group restrictions
- CloudWatch logging enabled
- Point-in-time recovery for DynamoDB
- Pre-commit hooks for code quality and Terraform validation
- Automated security scanning in CI/CD pipeline
