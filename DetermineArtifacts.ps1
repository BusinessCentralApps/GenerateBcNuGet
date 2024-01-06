Write-Host "Determine Artifacts"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

# Get array of apps
$appsFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$apps = @(Copy-AppFilesToFolder -appFiles @("$env:apps".Split(',')) -folder $appsFolder)

# Get workflow input
$nuGetServerUrl, $githubRepository = GetNuGetServerUrlAndRepository -nuGetServerUrl $env:nuGetServerUrl
$nuGetToken = $env:nuGetToken
$country = $env:country
if ($country -eq '') { $country = 'w1' }
$artifactType = $env:artifactType
if ($artifactType -eq '') { $artifactType = 'sandbox' }
$artifactVersion = "$env:artifactVersion".Trim()

# Determine runtime dependency package ids for all apps and whether any of the apps doesn't exist as a nuGet package
$runtimeDependencyPackageIds, $newPackage = GetRuntimeDependencyPackageIds -apps $apps -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken

# If artifact Version is empty or it is a starting version (like 20.0-) then determine which artifact versions are needed
if ($artifactVersion -eq '' -or $artifactVersion.EndsWith('-')) {

    # Find the highest application dependency for the apps in order to determine which BC Application version to use for runtime packages
    $highestApplicationDependency = GetHighestApplicationDependency -apps $apps -lowestVersion ($artifactVersion.Split('-')[0])

    # Determine which artifacts are needed for any of the apps
    $allArtifactVersions = @(GetArtifactVersionsSince -type $artifactType -country $country -version "$highestApplicationDependency")

    if ($newPackage) {
        # If a new package is to be created, all artifacts are needed
        $artifactVersions = $allArtifactVersions
    }
    else {
        # all indirect packages exists - determine which runtime package versions doesn't exist for the app
        $artifactVersions = @(GetArtifactVersionsNeeded -apps $apps -allArtifactVersions $allArtifactVersions -runtimeDependencyPackageIds $runtimeDependencyPackageIds -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken)
    }
}
else {
    $artifactVersions = @($artifactVersion.Split(',') | ForEach-Object {
        $version = NormalizeVersionStr -versionStr $_
        $artifactUrl = Get-BCArtifactUrl -type $artifactType -country $country -version $version -select Closest
        if (-not $artifactUrl) {
            throw "Cannot find artifact for $_"
        }
        [System.Version]($artifactUrl.Split('/')[4])
    })
}

$artifactVersions = @($artifactVersions | ForEach-Object { @{ "artifactVersion" = "$_"; "incompatibleArtifactVersion" = "$($_.Major).$($_.Minor+1)" } })

Write-Host "Artifact versions:"
$artifactVersions | ForEach-Object { Write-Host "- $(ConvertTo-Json -InputObject $_ -Compress)" }
Add-Content -Path $ENV:GITHUB_OUTPUT -Value "ArtifactVersions=$(ConvertTo-Json -InputObject @($artifactVersions) -Compress)" -Encoding UTF8
Add-Content -Path $ENV:GITHUB_OUTPUT -Value "ArtifactVersionCount=$($artifactVersions.Count)" -Encoding UTF8

Write-Host "RuntimeDependencyPackageIds:"
$runtimeDependencyPackageIds.Keys | ForEach-Object { Write-Host "- $_ = $($runtimeDependencyPackageIds."$_")" }
Add-Content -Path $ENV:GITHUB_OUTPUT -Value "RuntimeDependencyPackageIds=$(ConvertTo-Json -InputObject $runtimeDependencyPackageIds -Compress)" -Encoding UTF8
