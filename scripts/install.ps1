# cursor-config install script for Windows
# Usage: .\install.ps1 [-GitRepoPath "C:\path\to\repo"] [-PythonPath "python"]

param(
    [string]$GitRepoPath = "",
    [string]$PythonPath = "python"
)

$ErrorActionPreference = "Stop"
$CursorHome = Join-Path $env:USERPROFILE ".cursor"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

# Create directories
$Dirs = @(
    (Join-Path $CursorHome "rules"),
    (Join-Path $CursorHome "skills-cursor")
)
foreach ($Dir in $Dirs) {
    if (!(Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Write-Host "Created: $Dir"
    }
}

# Copy rules
$RulesSrc = Join-Path $RepoRoot "rules"
$RulesDst = Join-Path $CursorHome "rules"
Copy-Item -Path "$RulesSrc\*" -Destination $RulesDst -Force -Recurse
Write-Host "Rules installed to $RulesDst"

# Copy skills
$SkillsSrc = Join-Path $RepoRoot "skills"
$SkillsDst = Join-Path $CursorHome "skills-cursor"
Get-ChildItem $SkillsSrc -Directory | ForEach-Object {
    $dest = Join-Path $SkillsDst $_.Name
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item -Path $_.FullName -Destination $SkillsDst -Recurse -Force
}
Write-Host "Skills installed to $SkillsDst"

# Process mcp.json
$McpSrc = Join-Path $RepoRoot "mcp\mcp.json"
$McpDst = Join-Path $CursorHome "mcp.json"
$McpContent = Get-Content $McpSrc -Raw -Encoding UTF8

$UserHomeEscaped = $env:USERPROFILE -replace '\\', '\\\\'
$McpContent = $McpContent -replace '\{\{USER_HOME\}\}', $UserHomeEscaped
$McpContent = $McpContent -replace '\{\{PYTHON_PATH\}\}', ($PythonPath -replace '\\', '\\\\')

if ($GitRepoPath) {
    $GitRepoPathEscaped = $GitRepoPath -replace '\\', '\\\\'
    $McpContent = $McpContent -replace '\{\{GIT_REPO_PATH\}\}', $GitRepoPathEscaped
} else {
    Write-Host "WARNING: GIT_REPO_PATH not set. Edit $McpDst and replace {{GIT_REPO_PATH}} with your repo path."
}

Set-Content -Path $McpDst -Value $McpContent -Encoding UTF8 -NoNewline
Write-Host "MCP config installed to $McpDst"

Write-Host ""
Write-Host "Done! Set FIRECRAWL_API_KEY env var if you use firecrawl-mcp."
Write-Host "Restart Cursor to apply changes."
