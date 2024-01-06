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
1. NuGet.org
2. GitHub
3. Azure DevOps

| ![NOTE]
|please note that if you place your full .app files here)


### Step-by-step

1. Fork this repository to your personal or organizational account
2. 
Follow this fairly simple process to get started:

