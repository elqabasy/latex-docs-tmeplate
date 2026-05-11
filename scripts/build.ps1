param(
  [string]$Source,
  [string]$OutputDir = "build"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$OutputPath = Join-Path $ProjectRoot $OutputDir
$TempPath = Join-Path $OutputPath ".latex"

if ($Source) {
  $SourcePath = Join-Path $ProjectRoot $Source
  if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Source file not found: $SourcePath"
  }
  $SourcePaths = @((Resolve-Path -LiteralPath $SourcePath).Path)
}
else {
  $SourcePaths = @(Get-ChildItem -Path (Join-Path $ProjectRoot "src") -Filter "*.tex" -File | Sort-Object Name | ForEach-Object { $_.FullName })
  if ($SourcePaths.Count -eq 0) {
    throw "No .tex files found under src."
  }
}

$xelatex = Get-Command xelatex -ErrorAction SilentlyContinue
if (-not $xelatex) {
  throw "xelatex was not found in PATH. Install MiKTeX or TeX Live with XeLaTeX support."
}

Push-Location $ProjectRoot
try {
  New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

  foreach ($SourcePath in $SourcePaths) {
    if (Test-Path -LiteralPath $TempPath) {
      Remove-Item -LiteralPath $TempPath -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $TempPath | Out-Null

    for ($i = 1; $i -le 2; $i++) {
      & $xelatex.Source `
        -interaction=nonstopmode `
        -halt-on-error `
        "-output-directory=$TempPath" `
        $SourcePath

      if ($LASTEXITCODE -ne 0) {
        throw "XeLaTeX failed on pass $i for $SourcePath."
      }
    }

    $pdfName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath) + ".pdf"
    $builtPdf = Join-Path $TempPath $pdfName
    if (-not (Test-Path -LiteralPath $builtPdf)) {
      throw "Expected PDF was not produced: $builtPdf"
    }

    Copy-Item -LiteralPath $builtPdf -Destination (Join-Path $OutputPath $pdfName) -Force
    Write-Host "Built $(Join-Path $OutputDir $pdfName)"
  }
}
finally {
  Pop-Location
  if (Test-Path -LiteralPath $TempPath) {
    Remove-Item -LiteralPath $TempPath -Recurse -Force
  }
}