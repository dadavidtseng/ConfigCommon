param(
    [Parameter(Mandatory=$true)]
    [string[]]$TargetRepositories,
    [Parameter(Mandatory=$false)]
    [string]$SourceRepo = "dadavidtseng/ConfigCommon",
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "sync-config-common.yml",
    [Parameter(Mandatory=$false)]
    [string]$WorkingDirectory = "",
    [Parameter(Mandatory=$false)]
    [switch]$KeepTempFiles = $false
)

function Test-GitInstalled {
    try {
        git --version | Out-Null
        return $true
    } catch {
        Write-Error "Git is not installed or cannot be found. Please ensure Git is properly installed and added to the PATH environment variable."
        return $false
    }
}

function Copy-ConfigToRepository {
    param(
        [string]$TargetRepo,
        [string]$SourcePath,
        [string]$WorkingDir
    )

    Write-Host "Processing repository: $TargetRepo" -ForegroundColor Yellow
    $targetPath = Join-Path $WorkingDir $TargetRepo.Split('/')[1]

    try {
        if (Test-Path $targetPath) {
            Write-Host "  Directory exists, updating repository..." -ForegroundColor Green
            Push-Location $targetPath
            git pull origin main 2>$null
            if ($LASTEXITCODE -ne 0) {
                git pull origin master 2>$null
            }
            Pop-Location
        } else {
            Write-Host "  Cloning repository..." -ForegroundColor Green
            git clone "https://github.com/$TargetRepo.git" $targetPath
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to clone repository $TargetRepo"
            }
        }

        # Ensure .github/workflows directory exists
        $workflowsDir = Join-Path $targetPath ".github\workflows"
        if (-not (Test-Path $workflowsDir)) {
            New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null
            Write-Host "  Created .github\workflows directory" -ForegroundColor Cyan
        }

        $targetConfigPath = Join-Path $workflowsDir $ConfigFile

        if (Test-Path $SourcePath) {
            Copy-Item $SourcePath $targetConfigPath -Force
            Write-Host "  Copied $ConfigFile to $TargetRepo\.github\workflows\" -ForegroundColor Green

            Push-Location $targetPath
            $gitStatus = git status --porcelain

            if ($gitStatus) {
                Write-Host "  File changes detected, committing..." -ForegroundColor Cyan
                git add ".github/workflows/$ConfigFile"
                git commit -m "update: clone $ConfigFile from $SourceRepo"

                $pushChoice = Read-Host "  Push changes to remote repository? (y/N)"
                if ($pushChoice -match '^[Yy]') {
                    git push
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  Changes successfully pushed" -ForegroundColor Green
                    } else {
                        Write-Warning "  Push failed, please check manually"
                    }
                } else {
                    Write-Host "  Changes committed but not pushed to remote" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  File content is identical, no update needed" -ForegroundColor Gray
            }
            Pop-Location
        } else {
            Write-Error "  Source file not found: $SourcePath"
        }

        Write-Host "  Finished processing $TargetRepo" -ForegroundColor Green
        Write-Host ""

    } catch {
        $errorMessage = $_.Exception.Message
        Write-Error "  Error occurred while processing $TargetRepo`: $errorMessage"
        if (Get-Location | Where-Object { $_.Path -eq $targetPath }) {
            Pop-Location
        }
    }
}

# Set working directory
if ([string]::IsNullOrEmpty($WorkingDirectory)) {
    $tempDir = Join-Path $env:TEMP "sync-config-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $WorkingDirectory = $tempDir
    $isTemporary = $true
} else {
    $isTemporary = $false
}

Write-Host "=== Configuration File Sync Tool ===" -ForegroundColor Cyan
Write-Host "Source Repository: $SourceRepo" -ForegroundColor White
Write-Host "Configuration File: $ConfigFile" -ForegroundColor White
Write-Host "Target Repositories: $($TargetRepositories -join ', ')" -ForegroundColor White
if ($isTemporary) {
    Write-Host "Using temporary directory: $WorkingDirectory" -ForegroundColor Gray
} else {
    Write-Host "Working Directory: $WorkingDirectory" -ForegroundColor White
}
Write-Host ""

if (-not (Test-GitInstalled)) {
    exit 1
}

# Create working directory
if (-not (Test-Path $WorkingDirectory)) {
    New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
}

Push-Location $WorkingDirectory

try {
    $sourceRepoName = $SourceRepo.Split('/')[1]
    $sourceRepoPath = Join-Path $WorkingDirectory $sourceRepoName

    Write-Host "Preparing source repository..." -ForegroundColor Yellow

    if (Test-Path $sourceRepoPath) {
        Write-Host "Source repository exists, updating..." -ForegroundColor Green
        Push-Location $sourceRepoPath
        git pull origin main 2>$null
        if ($LASTEXITCODE -ne 0) {
            git pull origin master 2>$null
        }
        Pop-Location
    } else {
        Write-Host "Cloning source repository..." -ForegroundColor Green
        git clone "https://github.com/$SourceRepo.git" $sourceRepoPath
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to clone source repository $SourceRepo"
        }
    }

    $sourceConfigPath = Join-Path $sourceRepoPath $ConfigFile

    if (-not (Test-Path $sourceConfigPath)) {
        Write-Error "$ConfigFile file not found in source repository"
        exit 1
    }

    Write-Host "Source repository preparation complete" -ForegroundColor Green
    Write-Host ""

    foreach ($repo in $TargetRepositories) {
        Copy-ConfigToRepository -TargetRepo $repo -SourcePath $sourceConfigPath -WorkingDir $WorkingDirectory
    }

    Write-Host "=== Sync Operation Complete ===" -ForegroundColor Cyan

    # Clean up temporary files
    if ($isTemporary -and -not $KeepTempFiles) {
        Write-Host ""
        Write-Host "Cleaning up temporary files..." -ForegroundColor Gray
        try {
            # Attempt to release possible file locks
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            Start-Sleep -Milliseconds 500

            # Multiple deletion attempts
            $attempts = 0
            $maxAttempts = 3
            $deleted = $false

            while ($attempts -lt $maxAttempts -and -not $deleted) {
                try {
                    Remove-Item $WorkingDirectory -Recurse -Force -ErrorAction Stop
                    $deleted = $true
                    Write-Host "Temporary file cleanup complete" -ForegroundColor Green
                } catch {
                    $attempts++
                    if ($attempts -lt $maxAttempts) {
                        Write-Host "  Cleanup attempt $attempts failed, waiting before retry..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                    }
                }
            }

            if (-not $deleted) {
                Write-Warning "Unable to completely clean temporary files: $WorkingDirectory"
                Write-Warning "This is usually because files are in use by other processes. You can manually delete the directory later."
            }
        } catch {
            $cleanupError = $_.Exception.Message
            Write-Warning "Error occurred while cleaning temporary files: $cleanupError"
            Write-Warning "Temporary directory: $WorkingDirectory"
        }
    }
} catch {
    $mainError = $_.Exception.Message
    Write-Error "Error occurred during execution: $mainError"

    # Clean temporary files even when error occurs
    if ($isTemporary -and -not $KeepTempFiles) {
        Write-Host "Cleaning up temporary files..." -ForegroundColor Gray
        try {
            [System.GC]::Collect()
            Start-Sleep -Milliseconds 500
            Remove-Item $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            # Don't show warnings on error to avoid interfering with main error message
        }
    }
    exit 1
} finally {
    Pop-Location
}

# Usage Examples:
# Basic usage (automatically uses temporary directory and cleans up)
# .\sync-config.ps1 -TargetRepositories @("username/repo1", "username/repo2")
#
# Keep temporary files for debugging
# .\sync-config.ps1 -TargetRepositories @("username/repo1") -KeepTempFiles
#
# Specify custom working directory (won't auto-clean)
# .\sync-config.ps1 -TargetRepositories @("username/repo1") -WorkingDirectory "C:\temp"