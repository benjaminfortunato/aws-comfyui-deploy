#!/usr/bin/env pwsh
# Manual cleanup script for retained Cognito resources

# Define function to delete Cognito User Pool
function Remove-CognitoUserPool {
    param (
        [string]$UserPoolId
    )
    
    if ([string]::IsNullOrEmpty($UserPoolId)) {
        Write-Host "No User Pool ID provided. Skipping." -ForegroundColor Yellow
        return
    }
    
    try {
        Write-Host "Deleting Cognito User Pool: $UserPoolId" -ForegroundColor Yellow
        aws cognito-idp delete-user-pool --user-pool-id $UserPoolId
        Write-Host "Successfully deleted User Pool: $UserPoolId" -ForegroundColor Green
    } catch {
        Write-Host "Error deleting User Pool: $_" -ForegroundColor Red
    }
}

Write-Host "Checking for Cognito resources in your account..." -ForegroundColor Yellow

# List all User Pools
try {
    $userPools = aws cognito-idp list-user-pools --max-results 60 | ConvertFrom-Json
    
    if ($userPools.UserPools.Count -gt 0) {
        Write-Host "Found the following Cognito User Pools:" -ForegroundColor Yellow
        
        $i = 1
        $userPools.UserPools | ForEach-Object {
            Write-Host "[$i] ID: $($_.Id), Name: $($_.Name), Created: $($_.CreationDate)" -ForegroundColor Cyan
            $i++
        }
        
        # Check for ones that seem related to ComfyUI
        $comfyPools = $userPools.UserPools | Where-Object { $_.Name -like "*comfy*" -or $_.Name -like "*ComfyUI*" }
        
        if ($comfyPools.Count -gt 0) {
            Write-Host "`nDetected potential ComfyUI related User Pools:" -ForegroundColor Yellow
            $comfyPools | ForEach-Object {
                Write-Host "ID: $($_.Id), Name: $($_.Name), Created: $($_.CreationDate)" -ForegroundColor Green
            }
            
            $deleteConfirm = Read-Host "Do you want to delete these User Pools? (y/n)"
            if ($deleteConfirm -eq "y") {
                $comfyPools | ForEach-Object {
                    Remove-CognitoUserPool -UserPoolId $_.Id
                }
            }
        } else {
            Write-Host "`nNo User Pools with 'comfy' or 'ComfyUI' in their name were found." -ForegroundColor Yellow
            
            $manualId = Read-Host "Enter a specific User Pool ID to delete (or leave empty to skip)"
            if (-not [string]::IsNullOrEmpty($manualId)) {
                Remove-CognitoUserPool -UserPoolId $manualId
            }
        }
    } else {
        Write-Host "No User Pools found in your account." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error listing User Pools: $_" -ForegroundColor Red
}

Write-Host "`nCleanup completed." -ForegroundColor Green
Write-Host "Run the cleanup_and_redeploy.ps1 script again to continue with the stack deployment." -ForegroundColor Cyan
