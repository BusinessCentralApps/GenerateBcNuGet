Write-Host "Generate Indirect NuGet Package"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

$appsFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$apps = @(Copy-AppFilesToFolder -appFiles @("$env:apps".Split(',')) -folder $appsFolder)

$nuGetServerUrl, $githubRepository = GetNuGetServerUrlAndRepository -nuGetServerUrl $env:nuGetServerUrl
$nuGetToken = $env:nuGetToken

foreach($appFile in $apps) {
    $appJson = Get-AppJsonFromAppFile -appFile $appFile

    # Test whether a NuGet package exists for this app?
    $bcContainerHelperConfig.TrustedNuGetFeeds = @( 
        [PSCustomObject]@{ "url" = $nuGetServerUrl;  "token" = $nuGetToken; "Patterns" = @("*.runtime.$($appJson.id)") }
    )
    $package = Get-BcNuGetPackage -packageName "runtime.$($appJson.id)" -version $appJson.version -select Exact
    if (-not $package) {
        # If just one of the apps doesn't exist as a nuGet package, we need to create a new indirect nuGet package and build all runtime versions of the nuGet
        $package = New-BcNuGetPackage -appfile $appFile -githubRepository $githubRepository -isIndirectPackage -packageId "{publisher}.{name}.runtime.{id}" -runtimeDependencyId '{publisher}.{name}.runtime-{version}'
        Push-BcNuGetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -bcNuGetPackage $package
    }
}
