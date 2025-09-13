# S3 Static Website Deployment Script
param(
    [string]$BucketName = "s3.huyng2603.io",
    [string]$StackName = "s3-static-website"
)

Write-Host "🚀 Deploying S3 Static Website Stack" -ForegroundColor Green
Write-Host "Stack Name: $StackName" -ForegroundColor Cyan
Write-Host "Bucket Name: $BucketName" -ForegroundColor Cyan

aws cloudformation deploy `
    --template-file cloudformation_templates/s3_static_web_deployment.yaml `
    --stack-name $StackName `
    --parameter-overrides BucketName=$BucketName

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
}