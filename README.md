# GetAppSvcCertificates

A script to find expired or specific certificates on all Azure app services (or ASEs) within a specified subscription or resource groups. The script generates a (semicolon separated) CSV output including the name, thumbprint, hostname bindings, keyvault info if applicable and the resource group for all found certificates. 

# Usage Examples

Find all certificates in 'MySubscription'.

```powershell
.\Get-AppSvcCertificates.ps1 -Subscription "MySubscription"
```

Find all certificates in resource groups 'MyResGroup1' and 'MyResGroup2'. 

```powershell
.\Get-AppSvcCertificates.ps1 -Subscription "MySubscription" -ResourceGroups @("MyResGroup1", "MyResGroup2")
```

Find all certificates that expire before February 2022. 

```powershell
.\Get-AppSvcCertificates.ps1 -Subscription "MySubscription" -ExpiresBefore "2022-02-01"
```

Find certificate with thumbprint '4CEDFA18AB7018C0F8741AD6049D5AE4A29C5F8E'. 

```powershell
.\Get-AppSvcCertificates.ps1 -Subscription "MySubscription" -Thumbprint "4CEDFA18AB7018C0F8741AD6049D5AE4A29C5F8E"
```

# Prerequisites

* PowerShell 7
* PowerShell Az Module