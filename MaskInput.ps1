if ($env:GITHUB_EVENT_NAME -eq 'workflow_dispatch') {
  $eventPath = Get-Content -Encoding UTF8 -Path $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json
  if ($null -ne $eventPath.inputs) {
    $eventPath.inputs.psObject.Properties | Where-Object { @('Apps','Dependencies','NuGetToken','LicenseFileUrl') -contains $_.Name } | ForEach-Object {
      $property = $_.Name
      $value = $eventPath.inputs."$property"
      Write-Host "::add-mask::$value"
    }
  }
}

