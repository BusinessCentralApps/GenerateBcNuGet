# Proof-Of-Concept: Generate BcNuGet packages

## What is this?

This repository contains code and workflows to generate NuGet packages with Business Central apps.

BcNuGet packages comes in two flavors:

1. Including the full .app file
2. Including runtime packages, compiled for supported versions of Business Central

You shouldn't place both these types of BcNuGet packages on the same NuGet Server. If people have access to the full package, they shouldn't need the runtime packages.

## Package Format

After healthy discussions on various media, the following format was the one agreed upon.

### Naming

Naming of the packages almost follows NuGet standards. We use `publisher.name.appid` - this allows people to use registered prefixes on nuget.org and increases visibility in the UI. For runtime package BcNuGet packages we use `publisher.name.runtime.appid` for two reasons: human distinction and the ability to host both packages in the same GitHub organization with separate security models.

### Content

One BcNuGet package is one Business Central app,

### Dependencies

Full dependency list is included in the BcNuGet packages - using `publisher.name.appid` and `version`

### Search/Dependency resolution

We only use the `appid` and `version` to resolve dependencies. This is what Business Central does and this allows partners to do publisher name or name changes seamlessly.

### Runtime packages

Runtime packages are a bit special because we need to provide a binary version of the .app for every minor version of Business Central the .app supports. Including all these binary files in the BcNuGet package would be possible, but it would require us to modify the BcNuGet package whenever a new version of Business Central has shipped.

Therefore, the runtime version of a BcNuGet package does NOT contain the actual .app. Instead, it is an indirect (empty) package, containing an extra dependency to another BcNuGet package named `publisher.name.runtime-version` and the version number of this package is the Microsoft Application the containing runtime package was built for. Also, the Microsoft.Application dependency in the package containing the runtime package file has a Microsoft.Application dependency on f.ex. `[23.2,23.3)` which allows us to find the right package for any Business Central version by looking at dependencies.

### Example of a BcNuGet package

This package contains version 5.1.23.0 of my BingMaps.PTE app. Note the Publisher and App names have been normalized as NuGet recommends. We do however keep dashes due to the appid part.

```
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
    <metadata>
        <id>FreddyKristiansen.BingMapsPTE.165d73c1-39a4-4fb6-85a5-925edc1684fb</id>
        <version>5.1.23.0</version>
        <title>BingMaps.PTE</title>
        <description>BingMaps Integration App with geocode functionality and map control</description>
        <authors>Freddy Kristiansen</authors>
        <dependencies>
            <dependency id="Microsoft.Application" version="21.5.53619.57262" />
            <dependency id="Microsoft.Platform" version="21.0.53597.57239" />
        </dependencies>
    </metadata>
    <files>
        <file src="Freddy Kristiansen_BingMaps.PTE_5.1.23.0.app" target="Freddy Kristiansen_BingMaps.PTE_5.1.23.0.app" />
    </files>
</package>
```

### Example of a BcNuGet indirect runtime package

This package contains version 5.1.23.0 of my BingMaps.PTE app as a runtime package. Only differences to the above full app package is `.runtime` in the package id, a dependency to a BcNuGet package containing the actual binary and no actual files in this package. In this, this package is called the indirect package and and package containing the actual runtime binary is called the BcNuGet compiled runtime package.

```
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
    <metadata>
        <id>FreddyKristiansen.BingMapsPTE.runtime.165d73c1-39a4-4fb6-85a5-925edc1684fb</id>
        <version>5.1.23.0</version>
        <title>BingMaps.PTE</title>
        <description>BingMaps Integration App with geocode functionality and map control</description>
        <authors>Freddy Kristiansen</authors>
        <dependencies>
            <dependency id="Microsoft.Application" version="21.5.53619.57262" />
            <dependency id="Microsoft.Platform" version="21.0.53597.57239" />
            <dependency id="FreddyKristiansen.BingMapsPTE.runtime-5-1-23-0" version="1.0.0.0" />
        </dependencies>
    </metadata>
</package>
```

### Example of a BcNuGet compiled runtime package

This package contains version 5.1.23.0 of my BingMaps.PTE app compiled with Business Central version 23.2.14098.14562 (first BC version in 23.2 minor) and is compatible with all 23.2 versions (but not 23.3). When 23.3 ships, we add another version to the BcNuGet compiled runtime package.

```
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
    <metadata>
        <id>FreddyKristiansen.BingMapsPTE.runtime-5-1-23-0</id>
        <version>23.2.14098.14562</version>
        <title>BingMaps.PTE</title>
        <description>BingMaps Integration App with geocode functionality and map control</description>
        <authors>Freddy Kristiansen</authors>
        <dependencies>
            <dependency id="Microsoft.Application" version="[23.2.14098.14562,23.3)" />
            <dependency id="Microsoft.Platform" version="21.0.53597.57239" />
        </dependencies>
    </metadata>
    <files>
        <file src="Freddy Kristiansen_BingMaps.PTE_5.1.23.0.runtime-23.2.14098.14562-w1.app" target="Freddy Kristiansen_BingMaps.PTE_5.1.23.0.runtime-23.2.14098.14562-w1.app" />
    </files>
</package>
```

> [!NOTE]
> Business Central runtime packages are only really guaranteed to work if they are compiled for the same minor version AND the same localization they are built for. Theoretically, there can be a difference between a US and a DK runtime package.
>
> Therefore, a compiled runtime package can contain multiple country versions of the same runtime package in subfolders with the name of the localization. After downloading a compiled runtime package, if a folder exists with the name of the needed localization - this is the package used - else the package in the root is used. The root does not have to be w1 - it is just always the default.
>
> When (sometime in the future) Business Central doesn't have localizations anymore - this problem does away and we have a clean model.

## Prerequisites

You need to have a direct download URL to the apps you want to create BcNuGet packages for. For testing purposes, you can use this URL: `https://github.com/microsoft/bcsamples-bingmaps.pte/releases/download/6.0.0/bcsamples-bingmaps.pte-main-Apps-5.1.23.0.zip`, which points to a release in the public BingMaps.PTE repository. The URL can contain a SAS token if private.

You need a GitHub account and the [GitHub CLI](https://cli.github.com/) installed.

You need a NuGet Server where you can place your BcNuGet packages. Thìs tool supports 3 options:
1. nuget.org (public only)
2. GitHub (private only)
3. Azure DevOps (public or private)

> [!NOTE]
> nuget.org is public. ALL packages published to nuget.org are available for everybody to download. **Publishing BcNuGet packages to nuget.org might expose your Intellectual Property (IP).**

For the selected option, you will need a server url and an authentication token (API Key). The following describes how to obtain these:

### Using nuget.org

The NuGet server url for nuget.org is always `https://api.nuget.org/v3/index.json`. In order to obtain an API Key, you first need a nuget.org account.

[Register for a free account on nuget.org](https://learn.microsoft.com/en-us/nuget/nuget-org/individual-accounts#add-a-new-individual-account) if you don't have one already.

Go to [https://www.nuget.org/account/apikeys](https://www.nuget.org/account/apikeys) and create an API Key with permissions to push new packages and package versions.

> [!WARNING]
> Do NOT share this API Key with other people, this token should ONLY be used for generating packages.

> [!NOTE]
> nuget.org is public.
> People doesn't need an invitation or an authentication token in order to read packages from nuget.org.

### Using GitHub

In order to use GitHub you need a GitHub account, which you probably have since you are reading this. If not, sign up by visiting [https://github.com/signup](https://github.com/signup).

On GitHub, the NuGet Server is scoped to the organization and access to packages is controlled by access to the owning repository. Since you cannot have both types of NuGet packages on the same server, you should create a new organization for NuGet Packages and create an empty repository for each set of packages you want to provide to other people. Go to [https://github.com/account/organizations/new?plan=free](https://github.com/account/organizations/new?plan=free) to create a free GitHub organization. I used FreddyKristiansen-RuntimePackages for the server which contains my runtime packages.

The NuGet server url for my GitHub organization is `https://nuget.pkg.github.com/FreddyKristiansen-RuntimePackages/index.json` - replace the organization name to access yours. GitHub doesn't support public NuGet packages, access is permitted to authenticated users only, who has access to the repository owning the package. I have created a repository called [https://github.com/FreddyKristiansen-RuntimePackages/BingMapsPTE](https://github.com/FreddyKristiansen-RuntimePackages/BingMapsPTE) and used this URL as the NuGet server url when running the Generate NuGet Packages tool.

In order to push new packages and package versions, you need to create a Personal Access Token (classic) with write:packages permissions.

> [!WARNING]
> Do NOT share this token with other people, this token should ONLY be used for generating packages.

> [!NOTE]
> GitHub packages are private (even if the owning repository is public)
> In order for people to get access to your NuGet packages, you need to invite them to your repository (read permissions is sufficient). They will then get an invitation to join the repository and after use their own Personal Access Token with read:packages permissions for accessing packages in your organization.

### Using Azure DevOps

In order to use Azure DevOps you need an Azure DevOps account. You can create an account by visiting [https://azure.microsoft.com/en-us/products/devops](https://azure.microsoft.com/en-us/products/devops).

On Azure DevOps you can create multiple NuGet feeds under your organization and/or under a repository. You can create an empty repository for each set of packages you want to provide to other people. If you create a public repository (like [https://dev.azure.com/freddydk/apps](https://dev.azure.com/freddydk/apps)) then your artifact feeds will also be public.

In order to push new packages and package versions, you need to create a Personal Access Token (classic) with Packaging Read&Write permissions. Visit [https://dev.azure.com/freddydk/_usersSettings/tokens](https://dev.azure.com/freddydk/_usersSettings/tokens) to create a personal access token.

> [!WARNING]
> Do NOT share this token with other people, this token should ONLY be used for generating packages.

> [!NOTE]
> Artifacts under Azure DevOps follows the permissions of the owning repository. If the repository is public, then users will not need an access token to query them.
> If the owning repository is private you need to give people permissions and they will have to create their own Personal Access Token to get access.

## Parameters

The Generate NuGet Packages workflow has a subset of the parameters from the Generate Runtime NuGet Packages workflow (nuGetServerUrl, nuGetToken, apps and run-name) and the parameters have the same meaning.

For the parameters, where the column masked is set yes, these values will not be visible in the workflow output.

| Name | Masked | Description | Default |
| :-- | :-- | :-- | :-- |
| `nuGetServerUrl` | | The url to your nuGet feed (based on type). Note that for GitHub, this should be the repository carrying the security model for the package. | |
| `nuGetToken` | yes | Auth Token with permissions to create packages and versions on the nuGet server. | |
| `apps` | yes | A comma-separated list of urls where the tool can download .zip files or .app files to publish as BcNuGet packages. All apps in this list will be published as BcNuGet packages. | |
| `dependencies` | yes | A comma-separated list of urls where the tool can download .zip files or .app files, which are needed dependencies when creating runtime packages. These apps will only be used during BcNuGet package generation. No BcNuGet package will be created from these. | |
| `country` | | Localization to use for the root runtime package. See [this](#example-of-a-bcnuget-compiled-runtime-package). | w1 |
| `additionalCountries` | | A comma-separated list of localizations for which a special compiled runtime version will be created and added in a subfolder. | |
| `artifactVersion` | | Which Business Central artifact versions to build runtime packages for. You can specify a comma-separated list of version numbers to use or a minimum-version followed by a - to indicate that you want all available Business Central versions after this version.  | all supported by app |
| `artifactType` | | onprem or sandbox | sandbox |
| `licenseFileUrl` | yes | When generating runtime packages for apps in non-public number ranges versions prior to 22.0, we need a license file for Business Central. This should be a direct download url to that license file and it will ONLY be used for versions prior to 22.0 | |
| `run-name` | | The name of the workflow run in the GitHub UI. | name of workflow |

These parameters can be specified directly in GitHub UI when invoking `Run workflow` - or they can be specified on the command-line when using `gh workflow run`.

## Running the tool

In order to run this tool, you need to create a fork in your own organization or in your personal GitHub account and under actions, enable workflows in the fork.

Running the **Generate NuGet Packages** workflow will generate BcNuGet packages with full apps.

Running the **Generate Runtime NuGet Packages** workflow will generate BcNuGet packages with runtime packages of your apps.

Mandatory fields are **nuGetServerUrl**, **nuGetToken** and **apps**. Parameters can be specified in the UI or created as secrets and variables, but they will most likely be provided as parameters when invoking the workflow from code using `gh workflow run`.

### Example 1

How I created full packages in [https://github.com/FreddyKristiansen-Apps/BingMapsPTE](https://github.com/FreddyKristiansen-Apps/BingMapsPTE)

```powershell
$apps = 'https://github.com/microsoft/bcsamples-bingmaps.pte/releases/download/6.0.0/bcsamples-bingmaps.pte-main-Apps-5.1.23.0.zip'
$nuGetServerUrl = 'https://github.com/FreddyKristiansen-Apps/BingMapsPTE'
$nuGetToken = '<my Personal Access Token>'
gh workflow run --repo freddydk/GenerateBcNuGet "Generate NuGet Packages" -f apps=$apps -f nuGetServerUrl=$nuGetServerUrl -f nuGetToken=$nuGetToken
```

### Example 2
 
How I created runtime packages in [https://github.com/FreddyKristiansen-RuntimePackages/BingMapsPTE](https://github.com/FreddyKristiansen-RuntimePackages/BingMapsPTE)

```powershell
$apps = 'https://github.com/microsoft/bcsamples-bingmaps.pte/releases/download/6.0.0/bcsamples-bingmaps.pte-main-Apps-5.1.23.0.zip'
$nuGetServerUrl = 'https://github.com/FreddyKristiansen-RuntimePackages/BingMapsPTE'
$nuGetToken = '<my Personal Access Token>'
gh workflow run --repo freddydk/GenerateBcNuGet "Generate Runtime NuGet Packages" -f apps=$apps -f nuGetServerUrl=$nuGetServerUrl -f nuGetToken=$nuGetToken -f country=w1
```

> [!NOTE]
> Re-running the same line again, will generate runtime packages for new versions of Business Central.

### Example 3
 
How I created full packages in [https://dev.azure.com/freddydk/apps/_artifacts/feed/Apps](https://dev.azure.com/freddydk/apps/_artifacts/feed/Apps)

```powershell
$apps = 'https://github.com/microsoft/bcsamples-bingmaps.pte/releases/download/6.0.0/bcsamples-bingmaps.pte-main-Apps-5.1.23.0.zip'
$nuGetServerUrl = 'https://pkgs.dev.azure.com/freddydk/apps/_packaging/Apps/nuget/v3/index.json'
$nuGetToken = '<my Personal Access Token>'
gh workflow run --repo freddydk/GenerateBcNuGet "Generate NuGet Packages" -f apps=$apps -f nuGetServerUrl=$nuGetServerUrl -f nuGetToken=$nuGetToken
```

### Example 4
 
How I created runtime packages in [https://dev.azure.com/freddydk/apps/_artifacts/feed/RuntimePackages](https://dev.azure.com/freddydk/apps/_artifacts/feed/RuntimePackages)

```powershell
$apps = 'https://github.com/microsoft/bcsamples-bingmaps.pte/releases/download/6.0.0/bcsamples-bingmaps.pte-main-Apps-5.1.23.0.zip'
$nuGetServerUrl = 'https://pkgs.dev.azure.com/freddydk/apps/_packaging/RuntimePackages/nuget/v3/index.json'
$nuGetToken = '<my Personal Access Token>'
gh workflow run --repo freddydk/GenerateBcNuGet "Generate Runtime NuGet Packages" -f apps=$apps -f nuGetServerUrl=$nuGetServerUrl -f nuGetToken=$nuGetToken -f country=w1
```

> [!NOTE]
> Re-running the same line again, will generate runtime packages for new versions of Business Central.

### Example 5
 
In order to publish runtime packages on nuget.org, you can use this

```powershell
$apps = '<your apps>'
$nuGetServerUrl = 'https://api.nuget.org/v3/index.json'
$nuGetToken = '<your NuGet API Key>'
gh workflow run --repo <your account>/GenerateBcNuGet "Generate Runtime NuGet Packages" -f apps=$apps -f nuGetServerUrl=$nuGetServerUrl -f nuGetToken=$nuGetToken -f country=w1
```
