#!/bin/bash

# GitHub to S3 Sync Lambda - Quick Deployment Script
# Usage: ./quick_deploy.sh [repo-url] [bucket-name] [branch]

set -e

# Default values
REPO_URL=${1:-"https://github.com/yourusername/your-repo.git"}
BUCKET_NAME=${2:-"s3.huyng2603.io"}
BRANCH=${3:-"main"}
STACK_NAME="github-s3-sync"
FUNCTION_NAME="github-s3-sync"

echo "🚀 GitHub to S3 Sync Lambda Deployment"
echo "======================================"
echo "Repository: $REPO_URL"
echo "Bucket: $BUCKET_NAME"
echo "Branch: $BRANCH"
echo ""

# Step 1: Validate template
echo "📋 Validating CloudFormation template..."
aws cloudformation validate-template --template-body file://lambda_deployment.yaml > /dev/null
echo "✅ Template is valid"

# Step 2: Deploy CloudFormation stack
echo "☁️  Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file lambda_deployment.yaml \
  --stack-name $STACK_NAME \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    RepoUrl=$REPO_URL \
    BucketName=$BUCKET_NAME \
    Branch=$BRANCH

echo "✅ CloudFormation stack deployed"

# Step 3: Create deployment package
echo "📦 Creating Lambda deployment package..."

# Clean up previous package
rm -rf lambda_package
rm -f lambda_deployment_package.zip

# Create package directory
mkdir lambda_package

# Install dependencies
echo "📥 Installing Python dependencies..."
pip install -r lambda_requirements.txt -t lambda_package --quiet

# Copy Lambda function
cp lambda_github_s3_sync.py lambda_package/

# Create ZIP package
cd lambda_package
zip -r ../lambda_deployment_package.zip . > /dev/null
cd ..

echo "✅ Deployment package created"

# Step 4: Update Lambda function code
echo "🔄 Updating Lambda function code..."
aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://lambda_deployment_package.zip > /dev/null

echo "✅ Lambda function updated"

# Step 5: Get function info
echo "📊 Function Information:"
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionArn'].OutputValue" \
  --output text

# Step 6: Test function (optional)
read -p "🧪 Would you like to test the function? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧪 Testing Lambda function..."
    
    # Create test event
    cat > test_event.json << EOF
{
  "repo_url": "$REPO_URL",
  "bucket_name": "$BUCKET_NAME",
  "branch": "$BRANCH"
}
EOF

    # Invoke function
    aws lambda invoke \
      --function-name $FUNCTION_NAME \
      --payload file://test_event.json \
      response.json > /dev/null

    echo "📄 Test Response:"
    cat response.json | python -m json.tool
    
    # Clean up test files
    rm test_event.json response.json
fi

# Step 7: Clean up
echo "🧹 Cleaning up temporary files..."
rm -rf lambda_package
rm -f lambda_deployment_package.zip

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📝 Next Steps:"
echo "1. Test the function in AWS Console"
echo "2. Enable EventBridge rule for scheduled sync (if needed)"
echo "3. Monitor CloudWatch logs for execution details"
echo ""
echo "📋 Function Details:"
echo "   Name: $FUNCTION_NAME"
echo "   Stack: $STACK_NAME"
echo "   Region: $(aws configure get region)"
echo ""
echo "🔧 To enable hourly sync:"
echo "   aws events put-rule --name github-sync-schedule --schedule-expression 'rate(1 hour)' --state ENABLED"