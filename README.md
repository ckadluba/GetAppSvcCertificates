# GetAppSvcCertificates

A script to find expired or specific certificates on all Azure app services (or ASEs) within a specified subscription or resource groups. The script generates a (semicolon separated) CSV output including the name, thumbprint, hostname bindings, keyvault info if applicable, ASE and web app ssl bindings and the resource group for all found certificates. 

# Usage
```
Get-AppSvcCertificates -Subscription <SubscriptionName> [-ResourceGroups <ResourceGroupNamesArray>] [-ExpiresBefore <ExpirationDate>] [-Thumbprints <ThumbprintsArray>]
```

# Examples

Find all certificates in 'MySubscription' and write ouput to file certs.csv

```powershell
.\Get-AppSvcCertificates.ps1 -Subscription "MySubscription" | Out-File certs.csv
```

Find all certificates in resource groups 'MyResGroup1' and 'MyResGroup2'. 

```powershell
.\Get-AppSvcCertificates.ps1 -Subscription "MySubscription" -ResourceGroups @("MyResGroup1", "MyResGroup2")
```

Find all certificates that expire before February 2022. 

```powershell
.\Get-AppSvcCertificates.ps1 -Subscription "MySubscription" -ExpiresBefore "2022-02-01"
```

Find certificate with thumbprints '4CEDFA18AB7018C0F8741AD6049D5AE4A29C5F8E' and '5AACFE71AB4BEF90F8741AD2349D5BCEA21C5BCE'. 

```powershell
.\Get-AppSvcCertificates.ps1 -Subscription "MySubscription" -Thumbprints @("4CEDFA18AB7018C0F8741AD6049D5AE4A29C5F8E", "5AACFE71AB4BEF90F8741AD2349D5BCEA21C5BCE")
```

# Prerequisites

* PowerShell 7
* PowerShell Az Module