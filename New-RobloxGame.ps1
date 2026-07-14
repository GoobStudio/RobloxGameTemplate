<#
.SYNOPSIS
    Bootstraps a new Roblox game project from GoobStudio/RobloxGameTemplate.

.DESCRIPTION
    Clones the latest template, stamps the project name into
    default.project.json and the README, starts a fresh git history,
    and pushes it to the repo you provide.

    Create an EMPTY repo on GitHub first (no README or .gitignore).

.EXAMPLE
    .\New-RobloxGame.ps1 -RepoUrl https://github.com/GoobStudio/MyNewGame

.EXAMPLE
    .\New-RobloxGame.ps1 -RepoUrl https://github.com/GoobStudio/MyNewGame -Name CoolGame -Path C:\Projects
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoUrl,

    # Project name stamped into default.project.json and the README.
    # Defaults to the repo name from the URL.
    [string]$Name,

    # Parent folder the project is created in. Defaults to the current directory.
    [string]$Path = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$TemplateUrl = "https://github.com/GoobStudio/RobloxGameTemplate.git"

$repoName = ($RepoUrl.TrimEnd('/') -split '/')[-1] -replace '\.git$', ''
if (-not $Name) { $Name = $repoName }

$target = Join-Path $Path $repoName
if (Test-Path $target) {
    throw "Target folder already exists: $target"
}

Write-Host "Cloning template into $target ..."
git clone --depth 1 $TemplateUrl $target
if (-not (Test-Path (Join-Path $target "default.project.json"))) {
    throw "Clone failed - could not fetch template from $TemplateUrl"
}

# Detach from the template's history; the bootstrapper doesn't belong in a game repo
Remove-Item (Join-Path $target ".git") -Recurse -Force
Remove-Item (Join-Path $target "New-RobloxGame.ps1") -Force

# Stamp the project name (plain string replace, no regex surprises)
foreach ($file in @("default.project.json", "README.md")) {
    $fullPath = Join-Path $target $file
    $content = [System.IO.File]::ReadAllText($fullPath)
    $content = $content.Replace("RobloxGameTemplate", $Name)
    [System.IO.File]::WriteAllText($fullPath, $content)
}

# Strip the template-only section from the README
$readmePath = Join-Path $target "README.md"
$readme = [System.IO.File]::ReadAllText($readmePath)
$readme = $readme -replace '(?s)<!-- TEMPLATE:START -->.*?<!-- TEMPLATE:END -->\r?\n?', ''
[System.IO.File]::WriteAllText($readmePath, $readme)

# Fresh history, pointed at the new repo
Push-Location $target
try {
    git init -b main
    git add .
    git commit -m "Initial commit from RobloxGameTemplate"
    git remote add origin $RepoUrl
    git push -u origin main
    if (-not $?) {
        Write-Warning "Push failed. Make sure an empty repo exists at $RepoUrl, then run 'git push -u origin main' inside $target."
    } else {
        Write-Host ""
        Write-Host "Done! '$Name' created at $target and pushed to $RepoUrl"
        Write-Host "Next: cd `"$target`" then 'rojo serve' and connect from Studio."
    }
}
finally {
    Pop-Location
}
