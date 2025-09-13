# GitHub to S3 Sync Lambda Function

Automatically sync files from a GitHub repository to an S3 bucket using AWS Lambda.

## Quick Start

### Option 1: One-Command Deployment (Windows)
```powershell
.\quick_deploy.ps1 "https://github.com/yourusername/repo.git" "your-bucket-name" "main"
```

### Option 2: One-Command Deployment (Linux/macOS)
```bash
chmod +x quick_deploy.sh
./quick_deploy.sh "https://github.com/yourusername/repo.git" "your-bucket-name" "main"
```

### Option 3: Manual Deployment
```bash
# 1. Deploy infrastructure
aws cloudformation deploy \
  --template-file lambda_deployment.yaml \
  --stack-name github-s3-sync \
  --capabilities CAPABILITY_IAM

# 2. Create and upload code package
mkdir lambda_package
pip install -r lambda_requirements.txt -t lambda_package
cp lambda_github_s3_sync.py lambda_package/
cd lambda_package && zip -r ../package.zip . && cd ..

# 3. Update Lambda function
aws lambda update-function-code \
  --function-name github-s3-sync \
  --zip-file fileb://package.zip
```

## Files

| File | Purpose |
|------|---------|
| `lambda_github_s3_sync.py` | Main Lambda function code |
| `lambda_deployment.yaml` | CloudFormation infrastructure template |
| `lambda_requirements.txt` | Python dependencies |
| `quick_deploy.ps1` | Windows PowerShell deployment script |
| `quick_deploy.sh` | Linux/macOS bash deployment script |
| `LAMBDA_DEPLOYMENT_GUIDE.md` | Detailed deployment documentation |

## Configuration

### Required Parameters
- **RepoUrl**: GitHub repository URL
- **BucketName**: Target S3 bucket name
- **Branch**: Git branch to sync (default: main)

### Optional Parameters
- **GitHubToken**: Personal access token for private repos

## Usage

### Manual Trigger
```bash
aws lambda invoke \
  --function-name github-s3-sync \
  --payload '{"repo_url":"https://github.com/user/repo.git","bucket_name":"my-bucket","branch":"main"}' \
  response.json
```

### Scheduled Sync
```bash
# Enable hourly sync
aws events put-rule \
  --name github-sync-schedule \
  --schedule-expression "rate(1 hour)" \
  --state ENABLED
```

## Monitoring

- **CloudWatch Logs**: `/aws/lambda/github-s3-sync`
- **Metrics**: Lambda console → Monitoring tab
- **Costs**: CloudWatch billing dashboard

## Support

See `LAMBDA_DEPLOYMENT_GUIDE.md` for detailed documentation, troubleshooting, and advanced configuration options.