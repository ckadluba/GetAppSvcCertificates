
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [System.String]
    $Subscription,
    [Parameter(Mandatory = $false)]
    [System.DateTime]
    $ExpiresBefore,
    [Parameter(Mandatory = $false)]
    [System.String]
    $Thumbprint
)

$context = Get-AzContext
if ($null -eq $context.Subscription || $context.Subscription.Name -ne $Subscription) {
    Connect-AzAccount -Subscription "$Subscription"
}

Write-Output "Cert Name; Thumbprint; Expiration Date; Hostnames; KeyVault; Resource Group"

$resourceGroups = Get-AzResourceGroup
foreach ($resourceGroup in $resourceGroups) {
    $resourceGroupName = $resourceGroup.ResourceGroupName
    $certs = Get-AzWebAppCertificate -ResourceGroupName "$resourceGroupName"
    foreach ($cert in $certs) {
        if ($null -ne $ExpiresBefore) {
            if ([System.DateTime]::Compare($ExpiresBefore, $cert.ExpirationDate) -lt 0) {
                continue
            }
        }

        if ($Thumbprint -ne "") {
            if ($cert.Thumbprint -ne $Thumbprint) {
                continue
            }
        }

        $hostNames = [System.String]::Join(", ", $cert.HostNames)
        $keyVaultName = ($cert.KeyVaultId -split '/')[-1]
        Write-Output ("{0}; {1}; {2}; {3}; {4}; {5}" -f $cert.Name, $cert.Thumbprint, $cert.ExpirationDate, $hostNames, $keyVaultName, $resourceGroupName)
    }
}
