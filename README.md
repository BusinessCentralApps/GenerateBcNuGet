# Proof-Of-Concept: Generate BcNuGet packages

## What is this?

This repository contains code and workflows to generate NuGet packages with Business Central apps.

BcNuGet packages comes in two flavors:

1. Including the full .app file
2. Including runtime packages, compiled for supported versions of Business Central

It is NOT supported to put both these types of BcNuGet packages on the same NuGet Server (it also wouldn't make much sense I think...)

## Prerequisites

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

## Running the

In order to run this tool, you need to create a fork in your own organization or in your personal GitHub account.

## Run the tool




### Step-by-step

1. Fork this repository to your personal or organizational account
2. 
Follow this fairly simple process to get started:

