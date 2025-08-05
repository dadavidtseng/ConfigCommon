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
        Write-Error "Git 未安裝或無法找到。請確認 Git 已正確安裝並加入到 PATH 環境變數中。"
        return $false
    }
}

function Copy-ConfigToRepository {
    param(
        [string]$TargetRepo,
        [string]$SourcePath,
        [string]$WorkingDir
    )

    Write-Host "正在處理倉儲：$TargetRepo" -ForegroundColor Yellow
    $targetPath = Join-Path $WorkingDir $TargetRepo.Split('/')[1]

    try {
        if (Test-Path $targetPath) {
            Write-Host "  目錄已存在，正在更新倉儲..." -ForegroundColor Green
            Push-Location $targetPath
            git pull origin main 2>$null
            if ($LASTEXITCODE -ne 0) {
                git pull origin master 2>$null
            }
            Pop-Location
        } else {
            Write-Host "  正在複製倉儲..." -ForegroundColor Green
            git clone "https://github.com/$TargetRepo.git" $targetPath
            if ($LASTEXITCODE -ne 0) {
                throw "無法複製倉儲 $TargetRepo"
            }
        }

        # 確保 .github/workflows 目錄存在
        $workflowsDir = Join-Path $targetPath ".github\workflows"
        if (-not (Test-Path $workflowsDir)) {
            New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null
            Write-Host "  建立 .github\workflows 目錄" -ForegroundColor Cyan
        }

        $targetConfigPath = Join-Path $workflowsDir $ConfigFile

        if (Test-Path $SourcePath) {
            Copy-Item $SourcePath $targetConfigPath -Force
            Write-Host "  已複製 $ConfigFile 到 $TargetRepo\.github\workflows\" -ForegroundColor Green

            Push-Location $targetPath
            $gitStatus = git status --porcelain

            if ($gitStatus) {
                Write-Host "  發現檔案變更，正在提交..." -ForegroundColor Cyan
                git add ".github/workflows/$ConfigFile"
                git commit -m "update: clone $ConfigFile from $SourceRepo"

                $pushChoice = Read-Host "  是否要推送變更到遠端倉儲？(y/N)"
                if ($pushChoice -match '^[Yy]') {
                    git push
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  變更已成功推送" -ForegroundColor Green
                    } else {
                        Write-Warning "  推送失敗，請手動檢查"
                    }
                } else {
                    Write-Host "  變更已提交但未推送到遠端" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  檔案內容相同，無需更新" -ForegroundColor Gray
            }
            Pop-Location
        } else {
            Write-Error "  找不到來源檔案：$SourcePath"
        }

        Write-Host "  完成處理 $TargetRepo" -ForegroundColor Green
        Write-Host ""

    } catch {
        Write-Error "  處理 $TargetRepo 時發生錯誤：$($_.Exception.Message)"
        if (Get-Location | Where-Object { $_.Path -eq $targetPath }) {
            Pop-Location
        }
    }
}

# 設定工作目錄
if ([string]::IsNullOrEmpty($WorkingDirectory)) {
    $tempDir = Join-Path $env:TEMP "sync-config-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $WorkingDirectory = $tempDir
    $isTemporary = $true
} else {
    $isTemporary = $false
}

Write-Host "=== 設定檔案同步工具 ===" -ForegroundColor Cyan
Write-Host "來源倉儲：$SourceRepo" -ForegroundColor White
Write-Host "設定檔案：$ConfigFile" -ForegroundColor White
Write-Host "目標倉儲：$($TargetRepositories -join ', ')" -ForegroundColor White
if ($isTemporary) {
    Write-Host "使用臨時目錄：$WorkingDirectory" -ForegroundColor Gray
} else {
    Write-Host "工作目錄：$WorkingDirectory" -ForegroundColor White
}
Write-Host ""

if (-not (Test-GitInstalled)) {
    exit 1
}

# 建立工作目錄
if (-not (Test-Path $WorkingDirectory)) {
    New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
}

Push-Location $WorkingDirectory

try {
    $sourceRepoName = $SourceRepo.Split('/')[1]
    $sourceRepoPath = Join-Path $WorkingDirectory $sourceRepoName

    Write-Host "正在準備來源倉儲..." -ForegroundColor Yellow

    if (Test-Path $sourceRepoPath) {
        Write-Host "來源倉儲已存在，正在更新..." -ForegroundColor Green
        Push-Location $sourceRepoPath
        git pull origin main 2>$null
        if ($LASTEXITCODE -ne 0) {
            git pull origin master 2>$null
        }
        Pop-Location
    } else {
        Write-Host "正在複製來源倉儲..." -ForegroundColor Green
        git clone "https://github.com/$SourceRepo.git" $sourceRepoPath
        if ($LASTEXITCODE -ne 0) {
            throw "無法複製來源倉儲 $SourceRepo"
        }
    }

    $sourceConfigPath = Join-Path $sourceRepoPath $ConfigFile

    if (-not (Test-Path $sourceConfigPath)) {
        Write-Error "在來源倉儲中找不到 $ConfigFile 檔案"
        exit 1
    }

    Write-Host "來源倉儲準備完成" -ForegroundColor Green
    Write-Host ""

    foreach ($repo in $TargetRepositories) {
        Copy-ConfigToRepository -TargetRepo $repo -SourcePath $sourceConfigPath -WorkingDir $WorkingDirectory
    }

    Write-Host "=== 同步作業完成 ===" -ForegroundColor Cyan

    # 清理臨時檔案
    if ($isTemporary -and -not $KeepTempFiles) {
        Write-Host ""
        Write-Host "正在清理臨時檔案..." -ForegroundColor Gray
        try {
            # 嘗試釋放可能的檔案鎖定
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            Start-Sleep -Milliseconds 500

            # 多次嘗試刪除
            $attempts = 0
            $maxAttempts = 3
            $deleted = $false

            while ($attempts -lt $maxAttempts -and -not $deleted) {
                try {
                    Remove-Item $WorkingDirectory -Recurse -Force -ErrorAction Stop
                    $deleted = $true
                    Write-Host "臨時檔案清理完成" -ForegroundColor Green
                } catch {
                    $attempts++
                    if ($attempts -lt $maxAttempts) {
                        Write-Host "  清理嘗試 $attempts 失敗，等待後重試..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                    }
                }
            }

            if (-not $deleted) {
                Write-Warning "無法完全清理臨時檔案：$WorkingDirectory"
                Write-Warning "這通常是因為檔案被其他程序使用中，您可稍後手動刪除該目錄"
            }
        } catch {
            Write-Warning "清理臨時檔案時發生錯誤：$($_.Exception.Message)"
            Write-Warning "臨時目錄：$WorkingDirectory"
        }
    }
} catch {
    Write-Error "執行過程中發生錯誤：$($_.Exception.Message)"

    # 發生錯誤時也要清理臨時檔案
    if ($isTemporary -and -not $KeepTempFiles) {
        Write-Host "正在清理臨時檔案..." -ForegroundColor Gray
        try {
            [System.GC]::Collect()
            Start-Sleep -Milliseconds 500
            Remove-Item $WorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            # 錯誤時不顯示警告，避免干擾主要錯誤訊息
        }
    }
    exit 1
} finally {
    Pop-Location
}

# 使用範例：
# 基本用法（會自動使用臨時目錄並清理）
# .\sync-config.ps1 -TargetRepositories @("username/repo1", "username/repo2")
#
# 保留臨時檔案用於偵錯
# .\sync-config.ps1 -TargetRepositories @("username/repo1") -KeepTempFiles
#
# 指定自訂工作目錄（不會自動清理）
# .\sync-config.ps1 -TargetRepositories @("username/repo1") -WorkingDirectory "C:\temp"