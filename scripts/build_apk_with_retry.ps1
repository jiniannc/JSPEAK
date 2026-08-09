# Gradle 8.6~8.14의 Windows 버그(transforms 이동 실패, gradle/gradle#31438) 우회 빌드 스크립트.
# 실패 시 임시 transforms 폴더를 최종 이름으로 rename 한 뒤 재시도한다.
# 사용: powershell -File scripts\build_apk_with_retry.ps1 [-Mode debug|release] [-ContentUrl <url>]
param(
    [string]$Mode = "debug",
    [string]$ContentUrl = ""
)

$gradleHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { "$env:USERPROFILE\.gradle" }

function Fix-Transforms {
    $transformDirs = Get-ChildItem "$gradleHome\caches" -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName "transforms" } |
        Where-Object { Test-Path $_ }
    $fixed = 0
    foreach ($base in $transformDirs) {
        Get-ChildItem $base -Directory | Where-Object { $_.Name -match '^([0-9a-f]{32})-' } | ForEach-Object {
            $target = Join-Path $base $_.Name.Substring(0, 32)
            try {
                if (Test-Path $target) {
                    Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop
                } else {
                    Rename-Item $_.FullName $target -ErrorAction Stop
                    $script:fixed++
                }
                $fixed++
            } catch { }
        }
    }
    Write-Host ">> transforms 정리: $fixed 개 처리"
}

$buildArgs = @("build", "apk", "--$Mode")
if ($ContentUrl) { $buildArgs += "--dart-define=CONTENT_URL=$ContentUrl" }

for ($i = 1; $i -le 8; $i++) {
    Write-Host "=== 빌드 시도 $i/8 ==="
    & flutter $buildArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "=== 빌드 성공 ==="
        exit 0
    }
    Fix-Transforms
}
Write-Host "=== 8회 시도 후에도 실패 ==="
exit 1
