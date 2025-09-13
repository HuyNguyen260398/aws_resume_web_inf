# GitHub to S3 Sync Lambda - Quick Deployment Script (PowerShell)
# Usage: .\quick_deploy.ps1 [repo-url] [bucket-name] [branch]

param(
    [string]$RepoUrl = "https://github.com/yourusername/your-repo.git",
    [string]$BucketName = "s3.nghuy.link", 
    [string]$Branch = "main"
)

$StackName = "github-s3-sync"
$FunctionName = "github-s3-sync"

Write-Host "🚀 GitHub to S3 Sync Lambda Deployment" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Repository: $RepoUrl" -ForegroundColor Cyan
Write-Host "Bucket: $BucketName" -ForegroundColor Cyan
Write-Host "Branch: $Branch" -ForegroundColor Cyan
Write-Host ""

try {
    # Step 1: Validate template
    Write-Host "📋 Validating CloudFormation template..." -ForegroundColor Yellow
    aws cloudformation validate-template --template-body file://lambda_deployment.yaml | Out-Null
    Write-Host "✅ Template is valid" -ForegroundColor Green

    # Step 2: Deploy CloudFormation stack
    Write-Host "☁️  Deploying CloudFormation stack..." -ForegroundColor Yellow
    aws cloudformation deploy `
        --template-file lambda_deployment.yaml `
        --stack-name $StackName `
        --capabilities CAPABILITY_IAM `
        --parameter-overrides `
        RepoUrl=$RepoUrl `
        BucketName=$BucketName `
        Branch=$Branch

    Write-Host "✅ CloudFormation stack deployed" -ForegroundColor Green

    # Step 3: Create deployment package
    Write-Host "📦 Creating Lambda deployment package..." -ForegroundColor Yellow

    # Clean up previous package
    if (Test-Path "lambda_package") { Remove-Item -Recurse -Force "lambda_package" }
    if (Test-Path "lambda_deployment_package.zip") { Remove-Item -Force "lambda_deployment_package.zip" }

    # Create package directory
    New-Item -ItemType Directory -Name "lambda_package" | Out-Null

    # Install dependencies
    Write-Host "📥 Installing Python dependencies..." -ForegroundColor Yellow
    pip install -r lambda_requirements.txt -t lambda_package --quiet

    # Copy Lambda function
    Copy-Item "lambda_github_s3_sync.py" "lambda_package/"

    # Create ZIP package
    Compress-Archive -Path "lambda_package/*" -DestinationPath "lambda_deployment_package.zip" -Force

    Write-Host "✅ Deployment package created" -ForegroundColor Green

    # Step 4: Update Lambda function code
    Write-Host "🔄 Updating Lambda function code..." -ForegroundColor Yellow
    aws lambda update-function-code `
        --function-name $FunctionName `
        --zip-file fileb://lambda_deployment_package.zip | Out-Null

    Write-Host "✅ Lambda function updated" -ForegroundColor Green

    # Step 5: Get function info
    Write-Host "📊 Function Information:" -ForegroundColor Cyan
    $FunctionArn = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionArn'].OutputValue" `
        --output text
    Write-Host "   ARN: $FunctionArn" -ForegroundColor White

    # Step 6: Test function (optional)
    $TestFunction = Read-Host "🧪 Would you like to test the function? (y/N)"
    if ($TestFunction -eq "y" -or $TestFunction -eq "Y") {
        Write-Host "🧪 Testing Lambda function..." -ForegroundColor Yellow
        
        # Create test event
        $TestEvent = @{
            repo_url = $RepoUrl
            bucket_name = $BucketName
            branch = $Branch
        } | ConvertTo-Json

        $TestEvent | Out-File -FilePath "test_event.json" -Encoding UTF8

        # Invoke function
        aws lambda invoke `
            --function-name $FunctionName `
            --payload file://test_event.json `
            response.json | Out-Null

        Write-Host "📄 Test Response:" -ForegroundColor Cyan
        Get-Content "response.json" | ConvertFrom-Json | ConvertTo-Json -Depth 10

        # Clean up test files
        Remove-Item "test_event.json", "response.json" -ErrorAction SilentlyContinue
    }

    # Step 7: Clean up
    Write-Host "🧹 Cleaning up temporary files..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "lambda_package" -ErrorAction SilentlyContinue
    Remove-Item -Force "lambda_deployment_package.zip" -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Test the function in AWS Console" -ForegroundColor White
    Write-Host "2. Enable EventBridge rule for scheduled sync (if needed)" -ForegroundColor White
    Write-Host "3. Monitor CloudWatch logs for execution details" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Function Details:" -ForegroundColor Cyan
    Write-Host "   Name: $FunctionName" -ForegroundColor White
    Write-Host "   Stack: $StackName" -ForegroundColor White
    $Region = aws configure get region
    Write-Host "   Region: $Region" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 To enable hourly sync:" -ForegroundColor Cyan
    Write-Host "   aws events put-rule --name github-sync-schedule --schedule-expression 'rate(1 hour)' --state ENABLED" -ForegroundColor White

} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}