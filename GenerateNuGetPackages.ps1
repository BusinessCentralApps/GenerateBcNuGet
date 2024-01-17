Write-Host "Generate Runtime NuGet Packages"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

$appsFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$apps = @(Copy-AppFilesToFolder -appFiles @("$env:apps".Split(',')) -folder $appsFolder)

$nuGetServerUrl, $githubRepository = GetNuGetServerUrlAndRepository -nuGetServerUrl $env:nuGetServerUrl
$nuGetToken = $env:nuGetToken
$symbolsOnly = ($env:symbolsOnly -eq 'true')
$packageIdTemplate = $env:packageIdTemplate

foreach($appFile in $apps) {
    $appJson = Get-AppJsonFromAppFile -appFile $appFile

    # Test whether a NuGet package exists for this app?
    $bcContainerHelperConfig.TrustedNuGetFeeds = @( 
        [PSCustomObject]@{ "url" = $nuGetServerUrl;  "token" = $nuGetToken; "Patterns" = @("*.$($appJson.id)") }
    )
    $package = Get-BcNuGetPackage -packageName $appJson.id -version $appJson.version -select Exact
    if (-not $package) {
        # If the app doesn't exist as a nuGet package, create it
        $useAppFile = GetAppFile -appFile $appFile -symbolsOnly:$symbolsOnly
        $package = New-BcNuGetPackage -appfile $useAppFile -githubRepository $githubRepository -packageId $packageIdTemplate -dependencyIdTemplate $packageIdTemplate
        Push-BcNuGetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -bcNuGetPackage $package
        if ($useAppFile -ne $appFile) {
            Remove-Item -Path $useAppFile -Force
        }
    }
}
