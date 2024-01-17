Write-Host "Generate Microsoft Apps NuGet Packages"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

# Get parameters from workflow (and dependent job)
$nuGetServerUrl, $githubRepository = GetNuGetServerUrlAndRepository -nuGetServerUrl $env:nuGetServerUrl
$nuGetToken = $env:nuGetToken

$country = $env:country
$artifactType = $env:artifactType
$artifactVersion = $env:artifactVersion
$symbolsOnly = ($env:symbolsOnly -eq 'true')
if ($symbolsOnly) {
    $symbolsStr = 'symbols'
}
else {
    $symbolsStr = ''
}

function AddToSummary {
    Param(
        [string] $message
    )
    Add-Content -Path $ENV:GITHUB_STEP_SUMMARY -Value $message -encoding utf8
    Write-Host $message
}

$artifactUrl = Get-BCArtifactUrl -type $artifactType -country $country -version $artifactVersion
if (-not ($artifactUrl)) {
    AddToSummary "No artifact found for type '$artifactType', country '$country' and version '$artifactVersion'"
}
else {
    $folders = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
    $applicationsFolder = Join-Path $folders[0] "Applications.$country"
    $localApps = Test-Path $applicationsFolder
    if ($localApps) {
        AddToSummary "Local apps exists for $country"
    }
    elseif ($country -ne 'w1') {
        throw "No local apps exists for $country"
    }
    else {
        $applicationsFolder = Join-Path $folders[1] "Applications"
    }
    if ($localApps -or $country -eq 'w1') {
        $alreadyAdded = @()
        @(Get-Item (Join-Path $folders[1] "ModernDev\program files\Microsoft Dynamics NAV\*\AL Development Environment\System.app"))+@(Get-ChildItem -Path (Join-Path $folders[0] "Extensions") -Filter '*.app' -Recurse)+@(Get-ChildItem -Path $applicationsFolder -Filter '*.app' -Recurse) | ForEach-Object {
            $appFileName = $_.FullName
            $appFileName = GetAppFile -appFile $appFileName -symbolsOnly:$symbolsOnly
            $appName = $_.Name
            if ($alreadyAdded -contains $appName) {
                Write-Host -ForegroundColor Yellow "$appName was already published to NuGet"
            }
            else {
                $alreadyAdded += @($appName)
                $package = $null
                $destinationFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
                if ($country -eq 'w1') {
                    $packageId = "{publisher}.{name}$symbolsStr.{id}"
                    if ($appName -eq "Microsoft_Application.app" -or $appName -like "Microsoft_Application_*.app") {
                        $packageId = "Microsoft.Application$symbolsStr"
                    }
                    elseif ($appName -eq 'System.app') {
                        $packageId = "Microsoft.Platform$symbolsStr"
                    }
                    $package = New-BcNuGetPackage -appfiles $appFileName -packageId $packageId -dependencyIdTemplate "{publisher}.{name}$symbolsStr.{id}" -applicationDependencyId "Microsoft.Application$symbolsStr" -platformDependencyId "Microsoft.Platform$symbolsStr" -destinationFolder $destinationFolder
                }
                else {
                    $packageId = "{publisher}.{name}.$($country)$symbolsStr.{id}"
                    if ($appName -eq "Microsoft_Application.app" -or $appName -like "Microsoft_Application_*.app") {
                        $packageId = "Microsoft.Application.$Country$symbolsStr"
                    }
                    elseif ($appName -eq 'System.app') {
                        $packageId = ""
                    }
                    if ($packageId) {
                        $package = New-BcNuGetPackage -appfiles $appFileName -packageId $packageId -dependencyIdTemplate "{publisher}.{name}.$country$symbolsStr.{id}" -applicationDependencyId "Microsoft.Application.$country$symbolsStr" -platformDependencyId "Microsoft.Platform$symbolsStr" -destinationFolder $destinationFolder
                    }
                }
                if ($package) {
                    $nuspecFile = Join-Path $destinationFolder 'manifest.nuspec'
                    $nuspec = [xml](Get-Content -Path $nuspecFile -Encoding UTF8)
                    $packageId = $nuspec.package.metadata.id
                    $cnt = 0
                    while ($true) {
                        try {
                            $cnt++
                            Push-BcNuGetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -bcNuGetPackage $package
                            AddToSummary -ForegroundColor Yellow "$packageId pushed to NuGet"
                            break
                        }
                        catch {
                            if ($_.Exception.Message -like '*Conflict - The feed already contains*') {
                                AddToSummary "$packageId already exists"
                                break
                            }
                            if ($cnt -eq 5) { throw $_ }
                            AddToSummary "Error pushing $($packageId): $($_.Exception.Message). Retry in 10 seconds"
                            Start-Sleep -Seconds 10
                        }
                    }
                    Remove-Item $package -Force
                }
                if (Test-Path $destinationFolder) {
                    Remove-Item $destinationFolder -Recurse -Force
                }
            }
            if ($appFileName -ne $_.FullName) {
                Remove-Item $appFileName -Force
            }
        }
    }
}
