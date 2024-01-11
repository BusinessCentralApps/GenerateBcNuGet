Write-Host "Generate Runtime NuGet Packages"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

$country = $env:country
$artifactType = $env:artifactType
$artifactVersion = $env:artifactVersion

$artifactUrl = Get-BCArtifactUrl -type $artifactType -country $country -version $artifactVersion
$artifacts = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
