# Proof-Of-Concept: Generate BcNuGet packages

## What is this?

This repository contains code and workflows to generate NuGet packages with Business Central apps.

BcNuGet packages comes in two flavors:

1. Including the full .app file
2. Including runtime packages, compiled for supported versions of Business Central

It is NOT supported to put both these types of BcNuGet packages on the same NuGet Server (it also wouldn't make much sense I think...)

## How to get started?

To get started, make sure you have all the prerequisites and then follow the step-by-step guide.

### Prerequisites

You need a NuGet Server where you can place your BcNuGet packages. The tool supports 3 options:
1. nuget.org (public only)
2. GitHub (private)
3. Azure DevOps (public or private)

> [!NOTE]
> nuget.org is public. ALL packages published to nuget.org are available for everybody to download. **Publishing BcNuGet packages to nuget.org might expose your Intellectual Property (IP).**

For the selected option, you will need a server url and an authentication token (API Key). The following describes how to obtain these:

#### Using nuget.org

The NuGet server url for nuget.org is always `https://api.nuget.org/v3/index.json`. In order to obtain an API Key, you first need a nuget.org account.

[Register for a free account on nuget.org](https://learn.microsoft.com/en-us/nuget/nuget-org/individual-accounts#add-a-new-individual-account) if you don't have one already.

Go to [https://www.nuget.org/account/apikeys](https://www.nuget.org/account/apikeys) and create an API Key with permissions to push new packages and package versions.

> [!NOTE]
> nuget.org is public. People doesn't need an invitation or an authentication token in order to read packages from nuget.org.


#### Using GitHub

In order to use GitHub you need a GitHub account, which you probably have since you are reading this. If not, sign up by visiting [https://github.com/signup](https://github.com/signup).

On GitHub, the NuGet Server is scoped to the organization. In order to create a new NuGet Server, you need to create a new organization. Go to [https://github.com/account/organizations/new?plan=free](https://github.com/account/organizations/new?plan=free) to create a free GitHub organization. I used FreddyKristiansen-RuntimePackages for the server which contains my runtime packages.

The NuGet server url for my GitHub organization is `https://nuget.pkg.github.com/FreddyKristiansen-RuntimePackages/index.json` - replace the organization name to access yours.

In order to push new packages and package versions, you need to create a Personal Access Token (classic) with write:packages permissions.

> [!WARNING]
> Do NOT share this token with other people, this token should ONLY be used for generating packages.

> [!NOTE]
> GitHub packages is private.
> In order to invite other people to access your NuGet packages, you need to invite them to your organization (read permissions is sufficient) and they will then need to create their own Personal Access Token with read:packages permissions to use for access.

### Step-by-step

1. Fork this repository to your personal or organizational account
2. 
Follow this fairly simple process to get started:

