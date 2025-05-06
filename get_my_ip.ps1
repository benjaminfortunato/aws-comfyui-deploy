#!/usr/bin/env pwsh
# Get your public IP address and format it for use in app.py

Write-Host "Getting your current public IP address..." -ForegroundColor Cyan

try {
    # Try to get IP from ipify API
    $ip = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
    
    if ($ip) {
        Write-Host "Your public IP address is: $ip" -ForegroundColor Green
        Write-Host "`nTo restrict access to ComfyUI to only your IP, update app.py with:" -ForegroundColor Yellow
        Write-Host "allowed_ip_v4_address_ranges=[`"$ip/32`"]," -ForegroundColor Cyan
        
        Write-Host "`nWould you like to automatically update app.py with your IP? (y/n)" -ForegroundColor Magenta
        $updateConfirm = Read-Host
        
        if ($updateConfirm -eq "y") {
            $appPyPath = Join-Path -Path $PSScriptRoot -ChildPath "app.py"
            $appPyContent = Get-Content -Path $appPyPath -Raw
            
            # Update the IP address in app.py
            $newContent = $appPyContent -replace 'allowed_ip_v4_address_ranges=\["[^"]+"\]', "allowed_ip_v4_address_ranges=[`"$ip/32`"]"
            Set-Content -Path $appPyPath -Value $newContent
            
            Write-Host "`nUpdated app.py with your current IP address." -ForegroundColor Green
        }
    } else {
        Write-Host "Could not retrieve your IP address." -ForegroundColor Red
    }
} catch {
    Write-Host "Error retrieving your IP address: $_" -ForegroundColor Red
    Write-Host "`nAlternatively, you can check your IP by visiting https://whatismyip.com and update app.py manually." -ForegroundColor Yellow
}
