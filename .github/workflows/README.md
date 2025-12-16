# GitHub Actions Workflows

This project uses separate CI/CD workflows for independent deployment of ECS and Lambda components.

## Workflows Overview

### 1. **deploy-ecs.yml** - ECS Application Deployment

**Triggers:**
- Push to `main` branch when changes are made to:
  - `app/**` (Flask application code)
  - `Dockerfile`
  - `.dockerignore`
  - `.github/workflows/deploy-ecs.yml`
- Manual trigger via workflow_dispatch

**Jobs:**
1. **test** - Run Python tests and linting
2. **build-and-push** - Build Docker image and push to ECR
3. **deploy-ecs** - Deploy new image to ECS Fargate
4. **integration-test** - Test deployed endpoints

**Duration:** ~5-8 minutes

### 2. **deploy-lambda.yml** - Lambda Function Deployment

**Triggers:**
- Push to `main` branch when changes are made to:
  - `lambda/**` (Lambda function code)
  - `.github/workflows/deploy-lambda.yml`
- Manual trigger via workflow_dispatch

**Jobs:**
1. **deploy-lambda** - Deploy Lambda function via Serverless Framework
2. **test-lambda** - Test Lambda DELETE endpoint via ALB

**Duration:** ~2-3 minutes

## Why Separate Workflows?

### Advantages:

1. **Independent Deployments**
   - Deploy ECS without triggering Lambda deployment
   - Deploy Lambda without rebuilding Docker images
   - Faster iteration on individual components

2. **Reduced Build Time**
   - ECS changes don't wait for Lambda deployment
   - Lambda changes don't trigger Docker builds
   - Only run what changed

3. **Better Resource Usage**
   - No wasted GitHub Actions minutes
   - Parallel development possible
   - Clearer CI/CD logs

4. **Easier Debugging**
   - Isolated failure points
   - Clearer workflow status
   - Component-specific logs

5. **Scalability**
   - Easy to add more microservices
   - Each component has its own pipeline
   - No monolithic workflow complexity

## Workflow Comparison

| Aspect | Before (Monolithic) | After (Separated) |
|--------|-------------------|-------------------|
| **ECS-only change** | 12-15 min (builds everything) | 5-8 min (ECS only) |
| **Lambda-only change** | 12-15 min (builds everything) | 2-3 min (Lambda only) |
| **Both change** | 12-15 min | 7-11 min (parallel) |
| **Debugging** | Complex, coupled | Simple, isolated |
| **Maintenance** | Single large file | Modular files |

## Manual Deployment

You can manually trigger deployments from GitHub:

1. Go to **Actions** tab
2. Select workflow:
   - `Deploy ECS Application` for Flask app
   - `Deploy Lambda Function` for DELETE endpoint
3. Click **Run workflow**
4. Select branch (usually `main`)
5. Click **Run workflow**

## Environment Variables

Both workflows use these GitHub Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Both workflows use these environment variables:
- `AWS_REGION: us-east-1`
- Component-specific resource names

## File Structure

```
.github/
└── workflows/
    ├── README.md              # This file
    ├── deploy-ecs.yml         # ECS/Flask deployment
    └── deploy-lambda.yml      # Lambda deployment
```

## Deployment Flow

### ECS Deployment Flow:
```
Push to main (app/ changes)
    ↓
1. Test & Lint (Python)
    ↓
2. Build Docker Image (AMD64)
    ↓
3. Push to ECR (with cache)
    ↓
4. Deploy to ECS Fargate
    ↓
5. Integration Tests
```

### Lambda Deployment Flow:
```
Push to main (lambda/ changes)
    ↓
1. Install Serverless Framework
    ↓
2. Deploy Lambda Function
    ↓
3. Test DELETE endpoint
    ↓
4. Check Lambda logs
```

## Common Commands

### Check Workflow Status
```bash
# List recent workflow runs
gh run list

# View specific workflow runs
gh run list --workflow=deploy-ecs.yml
gh run list --workflow=deploy-lambda.yml

# Watch a running workflow
gh run watch
```

### Manual Trigger
```bash
# Trigger ECS deployment
gh workflow run deploy-ecs.yml

# Trigger Lambda deployment
gh workflow run deploy-lambda.yml
```

### View Logs
```bash
# View latest ECS deployment logs
gh run view --log

# View logs for specific workflow
gh run view $(gh run list --workflow=deploy-ecs.yml --limit 1 --json databaseId -q '.[0].databaseId') --log
```

## Troubleshooting

### ECS Deployment Fails

**Check:**
1. ECR repository exists
2. ECS cluster and service are running
3. Task definition is valid
4. Docker build succeeds locally
5. AWS credentials have ECS permissions

**Logs:**
```bash
# GitHub Actions logs
gh run view --log

# ECS service events
aws ecs describe-services --cluster picus-cluster --services picus-service

# CloudWatch logs
aws logs tail /ecs/picus-api --follow
```

### Lambda Deployment Fails

**Check:**
1. Serverless Framework configuration is valid
2. Lambda function name doesn't conflict
3. IAM role has correct permissions
4. DynamoDB table exists
5. AWS credentials have Lambda permissions

**Logs:**
```bash
# GitHub Actions logs
gh run view --log

# Lambda logs
aws logs tail /aws/lambda/picus-dev-delete --follow
```

## Best Practices

1. **Test locally before pushing**
   ```bash
   # Test ECS changes
   docker build --platform linux/amd64 -t picus-app:latest .
   docker run -p 8000:8000 picus-app:latest
   
   # Test Lambda changes
   cd lambda
   npx serverless invoke local --function delete --data '{"pathParameters": {"id": "test"}}'
   ```

2. **Use feature branches**
   - Create branch for changes
   - Test thoroughly
   - Merge to main when ready

3. **Monitor deployments**
   - Watch GitHub Actions progress
   - Check CloudWatch logs
   - Verify endpoints work

4. **Rollback if needed**
   ```bash
   # Rollback ECS
   aws ecs update-service --cluster picus-cluster --service picus-service \
     --task-definition picus-app:PREVIOUS_REVISION
   
   # Rollback Lambda
   cd lambda
   npx serverless rollback --timestamp TIMESTAMP
   ```

## Migration from Monolithic Workflow

The old `deploy.yml` has been split into:
- `deploy-ecs.yml` - Contains test, build-and-push, deploy-ecs, integration-test jobs
- `deploy-lambda.yml` - Contains deploy-lambda, test-lambda jobs

No functionality was lost, only reorganized for better separation of concerns.
