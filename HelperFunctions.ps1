$bcContainerHelperVersion = 'https://bccontainerhelper.blob.core.windows.net/public/preview.zip'

$tempName = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
Write-Host "Downloading BcContainerHelper developer version from $bcContainerHelperVersion"
$webclient = New-Object System.Net.WebClient
$webclient.DownloadFile($bcContainerHelperVersion, "$tempName.zip")
Expand-Archive -Path "$tempName.zip" -DestinationPath "$tempName"
Remove-Item "$tempName.zip"
$bcContainerHelperPath = (Get-Item -Path (Join-Path $tempName "*\BcContainerHelper.ps1")).FullName
. $bcContainerHelperPath

$ErrorActionPreference = "stop"

function GetRuntimeDependencyPackageId {
    Param(
        [string] $package
    )
    $nuspecFile = Join-Path $package 'manifest.nuspec'
    $nuspec = [xml](Get-Content -Path $nuspecFile -Encoding UTF8)
    $packageId = $nuspec.package.metadata.id
    if ($packageId -match "^([^.]+)\.([^.]+)\..*$($appJson.id)`$") {
        $publisherAndName = "$($Matches[1]).$($Matches[2])"
        Write-Host "Publisher is $($Matches[1]) and name is $($Matches[2])"
    }
    else {
        throw "Cannot determine publisher and name from the $packageId"
    }
    $runtimeDependencyPackageId = $nuspec.package.metadata.dependencies.dependency | Where-Object { $_.id -like "$($publisherAndName).runtime-*" } | Select-Object -ExpandProperty id
    if (-not $runtimeDependencyPackageId) {
        throw "Cannot determine dependency package id"
    }
    return $runtimeDependencyPackageId
}

function GetRuntimeDependencyPackageIds {
    Param(
        [string[]] $apps,
        [string] $nuGetServerUrl,
        [string] $nuGetToken
    )
    $runtimeDependencyPackageIds = @{}
    $newPackage = $false
    foreach($appFile in $apps) {
        $appName = [System.IO.Path]::GetFileName($appFile)
        $appJson = Get-AppJsonFromAppFile -appFile $appFile
        # Test whether a NuGet package exists for this app?
        $bcContainerHelperConfig.TrustedNuGetFeeds = @( 
            [PSCustomObject]@{ "url" = $nuGetServerUrl;  "token" = $nuGetToken; "Patterns" = @("*.runtime.$($appJson.id)") }
        )
        $package = Get-BcNuGetPackage -packageName "runtime.$($appJson.id)" -version $appJson.version -select Exact
        if (-not $package) {
            # If just one of the apps doesn't exist as a nuGet package, we need to create a new indirect nuGet package and build all runtime versions of the nuGet
            $package = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
            New-BcNuGetPackage -appfile $appFile -isIndirectPackage -packageId "{publisher}.{name}.runtime.{id}" -runtimeDependencyId '{publisher}.{name}.runtime-{version}' -destinationFolder $package | Out-Null
            $newPackage = $true
        }
        $runTimeDependencyPackageId = GetRuntimeDependencyPackageId -package $package
        if ($newPackage) {
            Remove-Item -Path $package -Recurse -Force
        }
        $runtimeDependencyPackageIds += @{ $appName = $runTimeDependencyPackageId }
    }
    return $runtimeDependencyPackageIds, $newPackage
}

function GetNuGetServerUrlAndRepository {
    Param(
        [string] $nuGetServerUrl
    )
    if ($nugetServerUrl -match '^https:\/\/github\.com\/([^\/]+)\/([^\/]+)$') {
        $githubRepository = $nuGetServerUrl
        $nuGetServerUrl = "https://nuget.pkg.github.com/$($Matches[1])/index.json"
    }
    else {
        $githubRepository = ''
    }
    return $nuGetServerUrl, $githubRepository
}
function NormalizeVersionStr {
    Param(
        [string] $versionStr
    )
    $version = [System.version]$versionStr
    if ($version.Build -eq -1) { $version = [System.Version]::new($version.Major, $version.Minor, 0, 0) }
    if ($version.Revision -eq -1) { $version = [System.Version]::new($version.Major, $version.Minor, $version.Build, 0) }
    return "$version"
}

# Find the highest application dependency for the apps in order to determine which BC Application version to use for runtime packages
function GetHighestApplicationDependency {
    Param(
        [string[]] $apps,
        [string] $lowestVersion
    )
    if (-not $lowestVersion) { $lowestVersion = '1.0' }
    $highestApplicationDependency = NormalizeVersionStr($lowestVersion)
    foreach($appFile in $apps) {
        $appJson = Get-AppJsonFromAppFile -appFile $appFile
        # Determine Application Dependency for this app
        if ($appJson.PSObject.Properties.Name -eq "Application") {
            $applicationDependency = $appJson.application
        }
        else {
            $baseAppDependency = $appJson.dependencies | Where-Object { $_.Name -eq "Base Application" -and $_.Publisher -eq "Microsoft" }
            if ($baseAppDependency) {
                $applicationDependency = $baseAppDependency.Version
            }
            else {
                throw "Cannot determine application dependency for $appFile"
            }
        }
        # Determine highest application dependency for all apps
        if ([System.Version]$applicationDependency -gt [System.Version]$highestApplicationDependency) {
            $highestApplicationDependency = $applicationDependency
        }
    }
    return $highestApplicationDependency
}

function GetArtifactVersionsSince {
    Param(
        [string] $type,
        [string] $country,
        [string] $version,
        [switch] $includeLatest
    )
    $artifactVersions = @()
    $applicationVersion = [System.Version]$version
    while ($true) {
        $artifacturl = Get-BCArtifactUrl -type $type -country $country -version "$applicationVersion" -select Closest
        if ($artifacturl) {
            $artifactVersions += @([System.Version]($artifacturl.split('/')[4]))
            if ($includeLatest) {
                $latestArtifacturl = Get-BCArtifactUrl -type $type -country $country -version "$($applicationVersion.Major).$($applicationVersion.Minor).$([Int32]::MaxValue).$([Int32]::MaxValue)" -select Closest
                if ($latestArtifacturl -ne $artifacturl) {
                    $artifactVersions += @([System.Version]($latestArtifacturl.split('/')[4]))
                }
            }
            $applicationVersion = [System.Version]"$($applicationVersion.Major).$($applicationVersion.Minor+1).0.0"
        }
        elseif ($applicationVersion.Minor -eq 0) {
            break
        }
        else {
            $applicationVersion = [System.Version]"$($applicationVersion.Major+1).0.0.0"
        }
    }
    return $artifactVersions
}

function GetArtifactVersionsNeeded {
    Param(
        [string[]] $apps,
        [System.Version[]] $allArtifactVersions,
        [hashtable] $runtimeDependencyPackageIds,
        [string] $nuGetServerUrl,
        [string] $nuGetToken
    )

    # Look for latest artifacts first
    [Array]::Reverse($allArtifactVersions)
    # Search for runtime nuGet packages for all apps
    $artifactsNeeded = @()
    foreach($appFile in $apps) {
        $appName = [System.IO.Path]::GetFileName($appFile)
        foreach($artifactVersion in $allArtifactVersions) {
            $runtimeDependencyPackageId = $runtimeDependencyPackageIds."$appName"
            $bcContainerHelperConfig.TrustedNuGetFeeds = @( 
                [PSCustomObject]@{ "url" = $nuGetServerUrl;  "token" = $nuGetToken; "Patterns" = @($runtimeDependencyPackageId) }
            )
            $package = Get-BcNuGetPackage -packageName $runtimeDependencyPackageId -version "$artifactVersion" -select Exact
            if ($package) {
                break
            }
            else {
                $artifactsNeeded += @($artifactVersion)
            }
        }
    }
    return ($artifactsNeeded | Select-Object -Unique)
}

function GenerateRuntimeAppFiles {
    Param(
        [string] $containerName,
        [string] $type,
        [string] $country,
        [string[]] $additionalCountries,
        [string] $artifactVersion,
        [string[]] $apps,
        [string[]] $dependencies,
        [string] $licenseFileUrl
    )
    $artifacturl = Get-BCArtifactUrl -type $type -country $country -version $artifactVersion -select Closest
    $global:runtimeAppFiles = @{}
    $global:countrySpecificRuntimeAppFiles = @{}
    Convert-BcAppsToRuntimePackages -containerName $containerName -artifactUrl $artifacturl -imageName '' -apps $apps -publishApps $dependencies -licenseFile $licenseFileUrl -skipVerification -afterEachRuntimeCreation { Param($ht)
        if (-not $ht.runtimeFile) { throw "Could not generate runtime package" }
        $appName = [System.IO.Path]::GetFileName($ht.appFile)
        $global:runtimeAppFiles += @{ $appName = $ht.runtimeFile }
        $global:countrySpecificRuntimeAppFiles += @{ $appName = @{} }
    } | Out-Null
    foreach($ct in $additionalCountries) {
        $artifacturl = Get-BCArtifactUrl -type $type -country $ct -version $artifactVersion -select Closest
        Convert-BcAppsToRuntimePackages -containerName $containerName -artifactUrl $artifacturl -imageName '' -apps $apps -publishApps $dependencies -licenseFile $licenseFileUrl -skipVerification -afterEachRuntimeCreation { Param($ht)
            if (-not $ht.runtimeFile) { throw "Could not generate runtime package" }
            $appName = [System.IO.Path]::GetFileName($ht.appFile)
            $global:countrySpecificRuntimeAppFiles."$appName" += @{ $ct = $ht.runtimeFile }
        } | Out-Null
    }
    return $global:runtimeAppFiles, $global:countrySpecificRuntimeAppFiles
}

function GetAppFile {
    Param(
        [string] $appFile,
        [switch] $symbolsOnly
    )
    if ([System.IO.Path]::GetFileName($appFile) -eq 'System.app') {
        # System app is already a symbols file
        return $appFile
    }
    elseif ($symbolsOnly) {
        $symbolsFile = Join-Path ([System.IO.Path]::GetTempPath()) "([Guid]::NewGuid().ToString()).app"
        Create-SymbolsFileFromAppFile -appFile $appFile -symbolsFile $symbolsFile
        if (-not (Test-Path $symbolsFile)) {
            throw "Could not create symbols file from $appFile"
        }
        return $symbolsFile
    }
    else {
        return $appFile
    }
}
