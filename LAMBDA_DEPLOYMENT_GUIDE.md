# GitHub to S3 Sync Lambda Deployment Guide

This guide walks you through deploying a Lambda function that automatically syncs files from a GitHub repository to an S3 bucket.

## Prerequisites

### 1. AWS CLI Setup
```bash
# Install AWS CLI (if not already installed)
# Windows: Download from https://aws.amazon.com/cli/
# macOS: brew install awscli
# Linux: sudo apt-get install awscli

# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region, and output format
```

### 2. Required Permissions
Your AWS user/role needs these permissions:
- `cloudformation:*`
- `lambda:*`
- `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PassRole`
- `s3:*` (for the target bucket)
- `events:*` (for EventBridge scheduling)

### 3. Python Environment
```bash
# Ensure Python 3.7+ is installed
python --version

# Install required packages
pip install boto3 requests
```

## Files Overview

The deployment consists of these key files:

- `lambda_scripts/lambda_github_s3_sync.py` - Main Lambda function code
- `cloudformation_templates/lambda_github_s3_sync_deployment.yaml` - CloudFormation template
- `lambda_scripts/lambda_requirements.txt` - Python dependencies
- `lambda_scripts/deploy_lambda.py` - Automated deployment script
- `lambda_scripts/test_event.json` - Sample test event

## Deployment Methods

### Method 1: Automated Deployment (Recommended)

#### Step 1: Deploy CloudFormation Stack
```bash
# Deploy the infrastructure
aws cloudformation deploy \
  --template-file cloudformation_templates/lambda_github_s3_sync_deployment.yaml \
  --stack-name github-s3-sync \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    RepoUrl=https://github.com/yourusername/your-repo.git \
    BucketName=your-s3-bucket-name \
    Branch=main
```

#### Step 2: Create Deployment Package
```bash
# Create package directory
mkdir lambda_package

# Install dependencies
pip install -r lambda_scripts/lambda_requirements.txt -t lambda_package

# Copy Lambda function
copy lambda_scripts/lambda_github_s3_sync.py lambda_package/

# Create ZIP package (Windows PowerShell)
powershell "Compress-Archive -Path lambda_package/* -DestinationPath lambda_deployment_package.zip -Force"

# Create ZIP package (Linux/macOS)
cd lambda_package && zip -r ../lambda_deployment_package.zip . && cd ..
```

#### Step 3: Update Lambda Function Code
```bash
# Update the function with actual code
aws lambda update-function-code \
  --function-name github-s3-sync \
  --zip-file fileb://lambda_deployment_package.zip
```

### Method 2: Manual Step-by-Step Deployment

#### Step 1: Validate CloudFormation Template
```bash
aws cloudformation validate-template --template-body file://cloudformation_templates/lambda_github_s3_sync_deployment.yaml
```

#### Step 2: Create CloudFormation Stack
```bash
aws cloudformation create-stack \
  --stack-name github-s3-sync \
  --template-body file://cloudformation_templates/lambda_github_s3_sync_deployment.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=RepoUrl,ParameterValue=https://github.com/yourusername/repo.git \
    ParameterKey=BucketName,ParameterValue=your-bucket-name \
    ParameterKey=Branch,ParameterValue=main \
    ParameterKey=GitHubToken,ParameterValue=your-github-token
```

#### Step 3: Wait for Stack Creation
```bash
aws cloudformation wait stack-create-complete --stack-name github-s3-sync
```

#### Step 4: Get Stack Outputs
```bash
aws cloudformation describe-stacks \
  --stack-name github-s3-sync \
  --query "Stacks[0].Outputs"
```

#### Step 5: Prepare Lambda Package
```bash
# Create temporary directory
mkdir temp_lambda && cd temp_lambda

# Install dependencies
pip install requests boto3 -t .

# Copy function code
cp ../lambda_scripts/lambda_github_s3_sync.py .

# Create deployment package
zip -r ../lambda_function.zip .

# Clean up
cd .. && rm -rf temp_lambda
```

#### Step 6: Update Lambda Function
```bash
aws lambda update-function-code \
  --function-name github-s3-sync \
  --zip-file fileb://lambda_function.zip
```

## Configuration Parameters

### CloudFormation Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `RepoUrl` | GitHub repository URL | `https://github.com/yourusername/your-repo.git` | Yes |
| `BucketName` | S3 bucket name | `s3.nghuy.link` | Yes |
| `Branch` | Git branch to sync | `main` | No |
| `GitHubToken` | GitHub personal access token | Empty | No* |

*Required for private repositories

### Lambda Event Parameters

When invoking the Lambda function, use this event structure:

```json
{
  "repo_url": "https://github.com/yourusername/repo.git",
  "bucket_name": "your-s3-bucket",
  "branch": "main",
  "source_dir": "dist",
  "exclude_patterns": [".git", "*.md", "node_modules"],
  "github_token": "ghp_your_token_here"
}
```

## Testing the Deployment

### Test 1: Manual Invocation
```bash
# Create test event
cat > test_event.json << EOF
{
  "repo_url": "https://github.com/yourusername/repo.git",
  "bucket_name": "your-bucket-name",
  "branch": "main"
}
EOF

# Invoke function
aws lambda invoke \
  --function-name github-s3-sync \
  --payload file://lambda_scripts/test_event.json \
  response.json

# Check response
cat response.json
```

### Test 2: AWS Console
1. Go to AWS Lambda Console
2. Find `github-s3-sync` function
3. Click "Test" tab
4. Create new test event with the JSON above
5. Click "Test" button

### Test 3: Check CloudWatch Logs
```bash
# Get log groups
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/github-s3-sync"

# Get latest log stream
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/github-s3-sync" \
  --order-by LastEventTime \
  --descending \
  --max-items 1

# View logs
aws logs get-log-events \
  --log-group-name "/aws/lambda/github-s3-sync" \
  --log-stream-name "STREAM_NAME_FROM_ABOVE"
```

## Enable Scheduled Sync (Optional)

### Enable EventBridge Rule
```bash
# Enable the scheduled rule (currently disabled by default)
aws events put-rule \
  --name github-sync-schedule \
  --schedule-expression "rate(1 hour)" \
  --state ENABLED \
  --description "Trigger GitHub sync every hour"

# Add Lambda target
aws events put-targets \
  --rule github-sync-schedule \
  --targets "Id"="1","Arn"="arn:aws:lambda:REGION:ACCOUNT:function:github-s3-sync","Input"='{"repo_url":"https://github.com/yourusername/repo.git","bucket_name":"your-bucket","branch":"main"}'
```

### Custom Schedule Examples
```bash
# Every 30 minutes
--schedule-expression "rate(30 minutes)"

# Daily at 2 AM UTC
--schedule-expression "cron(0 2 * * ? *)"

# Weekdays at 9 AM UTC
--schedule-expression "cron(0 9 ? * MON-FRI *)"
```

## Monitoring and Troubleshooting

### Check Function Status
```bash
aws lambda get-function --function-name github-s3-sync
```

### View Recent Invocations
```bash
aws lambda get-function-configuration --function-name github-s3-sync
```

### Common Issues

#### 1. Permission Errors
```bash
# Check IAM role permissions
aws iam get-role --role-name ROLE_NAME_FROM_FUNCTION
aws iam list-attached-role-policies --role-name ROLE_NAME
```

#### 2. Timeout Issues
```bash
# Increase timeout (max 15 minutes)
aws lambda update-function-configuration \
  --function-name github-s3-sync \
  --timeout 900
```

#### 3. Memory Issues
```bash
# Increase memory
aws lambda update-function-configuration \
  --function-name github-s3-sync \
  --memory-size 1024
```

#### 4. GitHub API Rate Limits
- Add GitHub personal access token to environment variables
- Use private repositories sparingly
- Consider caching mechanisms

## Updating the Function

### Update Code Only
```bash
# Recreate package and update
pip install -r lambda_scripts/lambda_requirements.txt -t lambda_package --upgrade
cp lambda_scripts/lambda_github_s3_sync.py lambda_package/
powershell "Compress-Archive -Path lambda_package/* -DestinationPath lambda_deployment_package.zip -Force"

aws lambda update-function-code \
  --function-name github-s3-sync \
  --zip-file fileb://lambda_deployment_package.zip
```

### Update Configuration
```bash
# Update environment variables
aws lambda update-function-configuration \
  --function-name github-s3-sync \
  --environment Variables='{GITHUB_TOKEN=your_new_token}'
```

### Update Infrastructure
```bash
# Update CloudFormation stack
aws cloudformation deploy \
  --template-file cloudformation_templates/lambda_github_s3_sync_deployment.yaml \
  --stack-name github-s3-sync \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    RepoUrl=https://github.com/new-repo.git
```

## Cleanup

### Delete Everything
```bash
# Delete CloudFormation stack (removes all resources)
aws cloudformation delete-stack --stack-name github-s3-sync

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name github-s3-sync

# Clean up local files
rm -rf lambda_package/
rm lambda_deployment_package.zip
rm response.json
```

## Security Best Practices

1. **Use least privilege IAM policies**
2. **Store GitHub tokens in AWS Secrets Manager** (not environment variables)
3. **Enable CloudTrail logging**
4. **Use VPC endpoints** for S3 access if in VPC
5. **Regularly rotate access tokens**
6. **Monitor CloudWatch metrics and alarms**

## Cost Optimization

- **Right-size memory allocation** based on actual usage
- **Use provisioned concurrency** only if needed
- **Monitor invocation patterns** and adjust scheduling
- **Consider S3 storage classes** for synced content
- **Set up billing alerts**

## Support

For issues or questions:
1. Check CloudWatch logs first
2. Validate IAM permissions
3. Test with minimal event payload
4. Review AWS Lambda documentation
5. Check GitHub API status

---

**Last Updated**: September 2025
**Version**: 1.0