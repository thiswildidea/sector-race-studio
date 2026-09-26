# 编译 EXE 并打包成可分发的 ZIP。
# 用的是 Windows 自带的 .NET Framework 编译器，不需要安装任何东西。
# 改完 sector_race_studio.html 后重新跑一次本脚本即可。

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { throw "找不到 C# 编译器：$csc" }

$html = "sector_race_studio.html"
$exe  = "行业板块竞速动画.exe"
if (-not (Test-Path $html)) { throw "找不到应用本体：$html" }

# ---- 生成 app.ico ----
# 坑 1: 不能直接调 python。本机 PATH 里的 python 是微软商店占位程序
#       (WindowsApps\python.exe),跑它会直接返回 9009,脚本一行都没执行。
# 坑 2: 不能只判断 app.ico 不存在时才生成,否则改完 gen_icon.py 永远不生效。
function Get-PythonExe {
    $cands = @()
    $cands += (Get-Command python.exe -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
    $cands += (Get-Command python     -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
    $cands += @(
        "$HOME\.conda\envs\PythonGUI\python.exe",          # 本机 Conda 环境(优先)
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "C:\Python313\python.exe", "C:\Python312\python.exe", "C:\Python311\python.exe",
        "$HOME\.workbuddy\binaries\python\versions\3.13.12\python.exe",
        "$HOME\.workbuddy\binaries\python\envs\default\Scripts\python.exe"
    )
    foreach ($c in ($cands | Where-Object { $_ } | Select-Object -Unique)) {
        if ($c -match 'WindowsApps') { continue }          # 排除商店占位程序
        if (-not (Test-Path -LiteralPath $c)) { continue }
        & $c -c "import zlib, struct" 2>$null              # 真跑一次才算数
        if ($LASTEXITCODE -eq 0) { return $c }
    }
    return $null
}

$py = Get-PythonExe
if ($py) {
    Write-Host ("生成图标: {0}" -f $py)
    & $py gen_icon.py
    if ($LASTEXITCODE -ne 0) { throw "gen_icon.py 执行失败(退出码 $LASTEXITCODE)" }
} elseif (Test-Path "app.ico") {
    Write-Warning "未找到可用的 Python,沿用已有的 app.ico(图标可能已过期)"
} else {
    throw @"
未找到可用的 Python,无法生成 app.ico。请二选一:
  1) 安装 Python 后重跑本脚本;
  2) 手动放一个 app.ico 到本目录。
"@
}
if (-not (Test-Path "app.ico")) { throw "app.ico 未生成,无法设置 exe 图标" }

& $csc `
  /nologo /target:winexe /optimize+ /codepage:65001 `
  /out:$exe `
  /resource:"$html,APPHTML" `
  /win32icon:app.ico `
  /win32manifest:app.manifest `
  /reference:System.dll /reference:System.Windows.Forms.dll `
  SectorRaceStudio.cs

if ($LASTEXITCODE -ne 0) { throw "编译失败" }
Write-Host ("编译完成: {0}  ({1:N0} KB)" -f $exe, ((Get-Item $exe).Length / 1KB))

# ---- 打包分发包：exe 为主，另附一份免 exe 的降级方案 ----
$dist = "dist"
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Path $dist | Out-Null

Copy-Item $exe $dist
Copy-Item $html $dist
Copy-Item "启动-行业板块竞速动画.cmd" $dist
Copy-Item "使用说明.txt" $dist

$zip = "行业板块竞速动画_v1.0.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$dist\*" -DestinationPath $zip

Write-Host ("分发包: {0}  ({1:N0} KB)" -f $zip, ((Get-Item $zip).Length / 1KB))
Get-ChildItem $dist | Select-Object Name, @{n = 'KB'; e = { [math]::Round($_.Length / 1KB, 1) } } | Format-Table -AutoSize
