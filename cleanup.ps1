#!/usr/bin/env pwsh
# Script to clean up the failed deployment without automatic redeployment
# This script helps clean up resources from a failed ComfyUI AWS deployment

Write-Host "ComfyUI AWS Deployment - Cleanup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will clean up resources from a failed deployment without automatic redeployment." -ForegroundColor Yellow
Write-Host ""

# Check if CloudFormation stack exists
$stackExists = $false
try {
    $stack = aws cloudformation describe-stacks --stack-name ComfyUIStack | ConvertFrom-Json
    $stackExists = $true
    $stackStatus = $stack.Stacks[0].StackStatus
    Write-Host "Current stack status: $stackStatus" -ForegroundColor Yellow
    
    # Check if specific resources are in CREATE_IN_PROGRESS state that might be stuck
    $stuckResources = aws cloudformation describe-stack-resources --stack-name ComfyUIStack | ConvertFrom-Json | 
        Select-Object -ExpandProperty StackResources | 
        Where-Object { $_.ResourceStatus -eq "CREATE_IN_PROGRESS" }
    
    if ($stuckResources) {
        Write-Host "Found resources still in CREATE_IN_PROGRESS state:" -ForegroundColor Red
        $stuckResources | ForEach-Object {
            Write-Host " - $($_.LogicalResourceId) has been in $($_.ResourceStatus) state since $($_.Timestamp)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Stack doesn't exist or can't be accessed." -ForegroundColor Yellow
}

if ($stackExists) {
    # Get resources that might be retained and need manual deletion
    Write-Host "Checking for resources that might need manual deletion..." -ForegroundColor Yellow
    $resources = aws cloudformation list-stack-resources --stack-name ComfyUIStack | ConvertFrom-Json

    # List of potential problematic resources
    $cognito = $resources.StackResourceSummaries | Where-Object { $_.ResourceType -like "*Cognito*" }
    if ($cognito) {
        Write-Host "Found Cognito resources that might cause issues:" -ForegroundColor Red
        $cognito | ForEach-Object {
            Write-Host " - $($_.LogicalResourceId) ($($_.ResourceType)): $($_.PhysicalResourceId)" -ForegroundColor Red
        }
    }
    
    # Delete the failed CloudFormation stack with retain option for problematic resources
    Write-Host "Attempting to delete the ComfyUIStack stack (this might take a while)..." -ForegroundColor Yellow
    aws cloudformation delete-stack --stack-name ComfyUIStack

    # Wait for the stack deletion to complete or fail
    Write-Host "Waiting for stack deletion to complete (this might take a few minutes)..." -ForegroundColor Yellow
    
    # Configure timeout for stack deletion waiting (10 minutes)
    $maxWaitTime = [TimeSpan]::FromMinutes(10)
    $startTime = Get-Date
    $deleteComplete = $false
    
    while (-not $deleteComplete -and ((Get-Date) - $startTime) -lt $maxWaitTime) {
        try {
            $stackStatus = aws cloudformation describe-stacks --stack-name ComfyUIStack | ConvertFrom-Json | 
                Select-Object -ExpandProperty Stacks | 
                Select-Object -ExpandProperty StackStatus
            
            if ($stackStatus -like "*DELETE_IN_PROGRESS*") {
                Write-Host "Stack deletion in progress... (Status: $stackStatus)" -ForegroundColor Yellow
                Start-Sleep -Seconds 30
            } else {
                Write-Host "Stack status changed to: $stackStatus" -ForegroundColor Yellow
                $deleteComplete = $true
            }
        } catch {
            # If we can't get the stack status, it might be fully deleted
            Write-Host "Stack may be fully deleted or no longer accessible." -ForegroundColor Green
            $deleteComplete = $true
        }
    }
    
    if ((Get-Date) - $startTime -ge $maxWaitTime) {
        Write-Host "Stack deletion timed out after 10 minutes." -ForegroundColor Red
    } else {
        Write-Host "Stack deletion process completed." -ForegroundColor Green
    }
        
    # Check if the stack is in DELETE_FAILED state
    try {
        $stack = aws cloudformation describe-stacks --stack-name ComfyUIStack | ConvertFrom-Json
        if ($stack.Stacks[0].StackStatus -eq "DELETE_FAILED") {
            Write-Host "Stack is in DELETE_FAILED state. Will attempt to delete with RetainResources option." -ForegroundColor Yellow
            
            # Get resources that are preventing deletion
            $failedResources = aws cloudformation list-stack-resources --stack-name ComfyUIStack | ConvertFrom-Json
            $failedResourcesList = $failedResources.StackResourceSummaries | Where-Object { $_.ResourceStatus -eq "DELETE_FAILED" } | ForEach-Object { $_.LogicalResourceId }
            
            if ($failedResourcesList) {
                Write-Host "Found resources preventing deletion:" -ForegroundColor Red
                $failedResourcesList | ForEach-Object {
                    Write-Host " - $_" -ForegroundColor Red
                }
                
                # Form the retain-resources parameter
                $retainParam = $failedResourcesList -join " "
                Write-Host "Attempting deletion with retain-resources..." -ForegroundColor Yellow
                aws cloudformation delete-stack --stack-name ComfyUIStack --retain-resources $retainParam
                
                # Wait again
                Write-Host "Waiting for stack deletion to complete with retained resources..." -ForegroundColor Yellow
                Start-Sleep -Seconds 60
                
                try {
                    aws cloudformation describe-stacks --stack-name ComfyUIStack | Out-Null
                    Write-Host "Stack still exists. You may need to manually delete some resources from the AWS console." -ForegroundColor Yellow
                } catch {
                    Write-Host "Stack has been deleted successfully." -ForegroundColor Green
                }
            } else {
                Write-Host "Could not identify specific resources preventing deletion." -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Stack might have been deleted or is in an unexpected state." -ForegroundColor Yellow
    }
}

Write-Host "Stack deletion complete or stack does not exist." -ForegroundColor Green
Write-Host "Cleaning up cdk.out directory..." -ForegroundColor Yellow

# Clean up the cdk.out directory
if (Test-Path -Path "cdk.out") {
    Remove-Item -Path "cdk.out" -Recurse -Force
}

# Check for orphaned Cognito resources
Write-Host "Checking for any orphaned Cognito resources..." -ForegroundColor Yellow

# Function to detect and clean up Cognito resources
function Check-OrphanedCognitoResources {
    try {
        $userPools = aws cognito-idp list-user-pools --max-results 60 | ConvertFrom-Json
        
        if ($userPools.UserPools.Count -gt 0) {
            $comfyUserPools = $userPools.UserPools | Where-Object { $_.Name -like "*ComfyUI*" }
            
            if ($comfyUserPools) {
                Write-Host "Found ComfyUI-related Cognito User Pools that might be orphaned:" -ForegroundColor Yellow
                foreach ($pool in $comfyUserPools) {
                    Write-Host "  - $($pool.Name) (ID: $($pool.Id))" -ForegroundColor Yellow
                }
                
                $confirmation = Read-Host "Would you like to delete these Cognito User Pools? (y/n)"
                if ($confirmation -eq "y") {
                    foreach ($pool in $comfyUserPools) {
                        Write-Host "Deleting Cognito User Pool: $($pool.Id)" -ForegroundColor Yellow
                        aws cognito-idp delete-user-pool --user-pool-id $pool.Id
                        Write-Host "Successfully deleted User Pool: $($pool.Id)" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host "No ComfyUI-related Cognito User Pools found." -ForegroundColor Green
            }
        } else {
            Write-Host "No Cognito User Pools found in your account." -ForegroundColor Green
        }
    } catch {
        Write-Host "Error checking for Cognito resources: $_" -ForegroundColor Red
    }
}

# Call the function
Check-OrphanedCognitoResources

Write-Host ""
Write-Host "Cleanup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Verify in the AWS CloudFormation console that the stack has been deleted" -ForegroundColor White
Write-Host "2. If any resources are still showing as retained, delete them manually from their respective AWS service consoles" -ForegroundColor White
Write-Host "3. When you're ready to deploy again, run 'npx cdk deploy'" -ForegroundColor White
Write-Host ""
Write-Host "For IP-based restriction deployment, use the modified code that disables Cognito authentication." -ForegroundColor Yellow
