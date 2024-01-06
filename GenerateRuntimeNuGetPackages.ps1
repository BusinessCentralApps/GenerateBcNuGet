Write-Host "Generate Runtime NuGet Packages"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

$containerName = 'bcserver'

# Get apps and depenedencies
$appsFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$apps = @(Copy-AppFilesToFolder -appFiles @("$env:apps".Split(',')) -folder $appsFolder)

$dependenciesFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$dependencies = @(Copy-AppFilesToFolder -appFiles @("$env:dependencies".Split(',')) -folder $dependenciesFolder)

# Get parameters from workflow (and dependent job)
$nuGetServerUrl, $githubRepository = GetNuGetServerUrlAndRepository -nuGetServerUrl $env:nuGetServerUrl
$nuGetToken = $env:nuGetToken
$country = $env:country
if ($country -eq '') { $country = 'w1' }
$additionalCountries = @("$env:additionalCountries".Split(',') | Where-Object { $_ -and $_ -ne $country })
$artifactType = $env:artifactType
if ($artifactType -eq '') { $artifactType = 'sandbox' }
# Artifact version is from the matrix
$artifactVersion = $env:artifactVersion
$incompatibleArtifactVersion = $env:incompatibleArtifactVersion
# Runtime Dependency Package Ids is from the determine artifacts job
$runtimeDependencyPackageIds = $env:runtimedependencyPackageIds | ConvertFrom-Json | ConvertTo-HashTable

$licenseFileUrl = $env:licenseFileUrl
if ([System.Version]$artifactVersion -ge [System.Version]'22.0.0.0') {
    $licenseFileUrl = ''
}

# Create Runtime packages for main country and additional countries
$runtimeAppFiles, $countrySpecificRuntimeAppFiles = GenerateRuntimeAppFiles -containerName $containerName -type $artifactType -country $country -additionalCountries $additionalCountries -artifactVersion $artifactVersion -apps $apps -dependencies $dependencies -licenseFileUrl $licenseFileUrl

# For every app create and push nuGet package (unless the exact version already exists)
foreach($appFile in $apps) {
    $appName = [System.IO.Path]::GetFileName($appFile)
    $runtimeDependencyPackageId = $runtimeDependencyPackageIds."$appName"    
    $package = Get-BcNuGetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $runtimeDependencyPackageId -version $artifactVersion -select Exact
    if (-not $package) {
        $runtimePackage = New-BcNuGetPackage -appfile $runtimeAppFiles."$appName" -countrySpecificAppFiles $countrySpecificRuntimeAppFiles."$appName" -packageId $runtimeDependencyPackageId -packageVersion $artifactVersion -applicationDependency "[$artifactVersion,$incompatibleArtifactVersion)" -githubRepository $githubRepository
        Push-BcNuGetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -bcNuGetPackage $runtimePackage
    }
}
