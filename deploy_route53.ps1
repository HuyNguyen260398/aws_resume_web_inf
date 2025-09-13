# Route 53 Hosted Zone Deployment Script
param(
    [string]$DomainName = "huyng2603.io",
    [string]$StackName = "route53-hosted-zone"
)

Write-Host "🚀 Deploying Route 53 Hosted Zone Stack" -ForegroundColor Green
Write-Host "Stack Name: $StackName" -ForegroundColor Cyan
Write-Host "Domain Name: $DomainName" -ForegroundColor Cyan

aws cloudformation deploy `
    --template-file cloudformation_templates/route53_hosted_zone.yaml `
    --stack-name $StackName `
    --parameter-overrides DomainName=$DomainName

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Get name servers from stack outputs" -ForegroundColor White
    Write-Host "2. Update DNS settings at your domain registrar" -ForegroundColor White
    
    # Get name servers
    Write-Host ""
    Write-Host "🔍 Getting name servers..." -ForegroundColor Yellow
    aws cloudformation describe-stacks `
        --stack-name $StackName `
        --query "Stacks[0].Outputs[?OutputKey=='NameServers'].OutputValue" `
        --output text
} else {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
}