Write-Host "Generate Microsoft Apps NuGet Packages"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

# Get parameters from workflow (and dependent job)
$nuGetServerUrl, $githubRepository = GetNuGetServerUrlAndRepository -nuGetServerUrl $env:nuGetServerUrl
$nuGetToken = $env:nuGetToken

$country = $env:country
$artifactType = $env:artifactType
$artifactVersion = $env:artifactVersion
$symbolsOnly = ($env:symbolsOnly -eq 'true')

$artifactUrl = Get-BCArtifactUrl -type $artifactType -country $country -version $artifactVersion
if (-not ($artifactUrl)) {
    Write-Host "No artifact found for type '$artifactType', country '$country' and version '$artifactVersion'"
}
else {
    $folders = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
    $applicationsFolder = Join-Path $folders[0] "Applications.$country"
    $localApps = Test-Path $applicationsFolder
    if ($localApps) {
        Write-Host "Local apps exists for $country"
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
            $appFileName = GetAppFile -appFile $_.FullName -symbolsOnly:$symbolsOnly
            $appName = $_.Name
            if ($alreadyAdded -contains $appName) {
                Write-Host -ForegroundColor Yellow "$($appName) was already published to NuGet"
            }
            else {
                $alreadyAdded += @($appName)
                if ($country -eq 'w1') {
                    $packageId = "{publisher}.{name}.{id}"
                    if ($appName -eq "Microsoft_Application.app" -or $appName -like "Microsoft_Application_*.app") {
                        $packageId = "Microsoft.Application"
                    }
                    elseif ($appName -eq 'System.app') {
                        $packageId = "Microsoft.Platform"
                    }
                    $package = New-BcNuGetPackage -appfiles $appFileName -packageId $packageId -dependencyIdTemplate "{publisher}.{name}.{id}" -applicationDependencyId "Microsoft.Application" -platformDependencyId "Microsoft.Platform"
                }
                else {
                    $package = $null
                    $packageId = "{publisher}.{name}.$($country).{id}"
                    if ($appName -eq "Microsoft_Application.app" -or $appName -like "Microsoft_Application_*.app") {
                        $packageId = "Microsoft.Application.$Country"
                    }
                    elseif ($appName -eq 'System.app') {
                        $packageId = ""
                    }
                    if ($packageId) {
                        $package = New-BcNuGetPackage -appfiles $appFileName -packageId $packageId -dependencyIdTemplate "{publisher}.{name}.$($country).{id}" -applicationDependencyId "Microsoft.Application.$country" -platformDependencyId "Microsoft.Platform"
                    }
                }
                if ($package) {
                    $cnt = 0
                    while ($true) {
                        try {
                            $cnt++
                            Push-BcNuGetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -bcNuGetPackage $package
                            break
                        }
                        catch {
                            if ($_.Exception.Message -like '*Conflict - The feed already contains*') {
                                Write-Host "Package already exists"
                                break
                            }
                            if ($cnt -eq 5) { throw $_ }
                            Write-Host "Error pushing package: $($_.Exception.Message). Retry in 10 seconds"
                            Start-Sleep -Seconds 10
                        }
                    }
                    Remove-Item $package -Force
                }
            }
            if ($appFileName -ne $_.FullName) {
                Remove-Item $appFileName -Force
            }
        }
    }
}
