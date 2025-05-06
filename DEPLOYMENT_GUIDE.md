# ComfyUI AWS Deployment Guide

This guide provides instructions for deploying ComfyUI on AWS infrastructure. This repository is based on the [aws-samples/cost-effective-aws-deployment-of-comfyui](https://github.com/aws-samples/cost-effective-aws-deployment-of-comfyui) project with key modifications to simplify authentication and improve deployment reliability.

## Key Differences from the Original AWS Repository

This modified version:

1. **Removes Cognito Authentication**: Eliminates the Cognito user pool requirement for simpler deployment
2. **Adds IP-Based Security**: Restricts access by IP address instead of login credentials
3. **Fixes Deployment Issues**: Resolves CloudFormation stack creation problems in the original repository
4. **Simplifies Deployment**: Provides enhanced scripts for one-click deployment and cleanup

## Prerequisites

- AWS CLI installed and configured with appropriate permissions
- Node.js and npm installed
- AWS CDK installed (`npm install -g aws-cdk`)
- An AWS account with permissions to create the required resources

## Deployment Steps

### 1. Configure Security (Important!)

Before deploying, configure the IP address restrictions in `app.py`:

```python
# Edit this section to add your IP address
allowed_ip_v4_address_ranges=["YOUR_IP_ADDRESS/32"],
```

You can use the helper script to automatically update with your current IP address:

```powershell
.\get_my_ip.ps1
```

This script will detect your current public IP address and update the `app.py` file automatically.

### 2. Deploy ComfyUI

From the root directory, run:

```powershell
npx cdk deploy
```

The deployment will take approximately 8-10 minutes to complete.

### 3. Access ComfyUI

After successful deployment:
- Find the ALB URL in the CloudFormation stack outputs (`ComfyUIStack.Endpoint`)
- Access ComfyUI directly through this URL from your allowed IP address
- For administrative functions, navigate to `/admin` on the same URL

## Troubleshooting

### If Deployment Fails

You have two options for handling failed deployments:

1. Run the cleanup and redeploy script which automatically fixes common issues and redeploys:
   ```powershell
   .\cleanup_and_redeploy.ps1
   ```
   This script will:
   - Fix syntax errors in key files
   - Delete the stuck CloudFormation stack
   - Clean up any problematic resources
   - Redeploy automatically with the fixed code

2. Run the cleanup script if you want to clean up resources without automatic redeployment:
   ```powershell
   .\cleanup.ps1
   ```
   This script will:
   - Delete the stuck CloudFormation stack
   - Clean up any problematic resources
   - Provide guidance on next steps
   
   Then deploy manually when ready:
   ```powershell
   npx cdk deploy
   ```

### Manual Cleanup

If you need to manually clean up resources:

1. Delete the CloudFormation stack:
   ```powershell
   aws cloudformation delete-stack --stack-name ComfyUIStack
   ```

2. Clean up any resources that fail to delete:
   ```powershell
   .\manual_cognito_cleanup.ps1
   ```

## Security Considerations

Since this deployment doesn't use Cognito authentication, consider:

1. **Regularly updating IP restrictions** using `get_my_ip.ps1` if you have a dynamic IP
2. **Using a VPN solution** for access management from multiple locations
3. **Adding additional AWS security groups** through the AWS Console after deployment

## Resource Management

### Deleting Deployments and Cleaning Up Resources

For the sake of preventing data loss from accidental deletions, the deletion process is semi-automated. You can use the `cleanup.ps1` script to clean up failed deployments. To completely cleanup and remove everything you've deployed, follow these steps:

1. Delete the Auto Scaling Group manually:
   - Login to your AWS console
   - Search for Auto Scaling Groups (EC2 feature) in the search bar
   - Select ComfyASG
   - Press Actions and then delete
   - Confirm deletion

2. After ASG deletion, run:
   ```bash
   npx cdk destroy
   ```

3. Delete EBS Volume:
   - Login to your AWS console
   - Search Volumes (EC2 feature) in the search bar
   - Select ComfyUIVolume
   - Press Actions and then delete
   - Confirm deletion

## More Information

- See `docs/USER_GUIDE.md` for usage instructions after deployment
- Refer to the original [aws-samples/cost-effective-aws-deployment-of-comfyui](https://github.com/aws-samples/cost-effective-aws-deployment-of-comfyui) for architecture details
