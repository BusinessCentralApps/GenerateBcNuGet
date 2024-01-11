Write-Host "Generate Runtime NuGet Packages"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

# Get parameters from workflow (and dependent job)
$nuGetServerUrl, $githubRepository = GetNuGetServerUrlAndRepository -nuGetServerUrl $env:nuGetServerUrl
$nuGetToken = $env:nuGetToken

$country = $env:country
$artifactType = $env:artifactType
$artifactVersion = $env:artifactVersion

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
            $appFileName = $_.FullName
            if ($alreadyAdded -contains $_.Name) {
                Write-Host -ForegroundColor Yellow "$($_.Name) was already published to NuGet"
            }
            else {
                $alreadyAdded += @($_.Name)
                if ($country -eq 'w1') {
                    $packageId = "{publisher}.{name}.{id}"
                    if ($_.Name -eq "Microsoft_Application.app" -or $_.Name -like "Microsoft_Application_*.app") {
                        $packageId = "Microsoft.Application"
                    }
                    elseif ($_.Name -eq 'System.app') {
                        $packageId = "Microsoft.Platform"
                    }
                    $package = New-BcNuGetPackage -appfiles $appFileName -packageId $packageId -dependencyIdTemplate "{publisher}.{name}.{id}" -applicationDependencyId "Microsoft.Application" -platformDependencyId "Microsoft.Platform"
                    Push-BcNuGetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -bcNuGetPackage $package
                    Remove-Item $package -Force
                }
                else {
                    $packageId = "{publisher}.{name}.$($country).{id}"
                    if ($_.Name -eq "Microsoft_Application.app" -or $_.Name -like "Microsoft_Application_*.app") {
                        $packageId = "Microsoft.Application.$Country"
                    }
                    elseif ($_.Name -eq 'System.app') {
                        $packageId = ""
                    }
                    if ($packageId) {
                        $package = New-BcNuGetPackage -appfiles $appFileName -packageId $packageId -dependencyIdTemplate "{publisher}.{name}.$($country).{id}" -applicationDependencyId "Microsoft.Application.$country" -platformDependencyId "Microsoft.Platform"
                        Push-BcNuGetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -bcNuGetPackage $package
                        Remove-Item $package -Force
                    }
                }
            }
        }
    }
}
