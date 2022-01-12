
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [System.String]
    $Subscription,
    [Parameter(Mandatory = $false)]
    [System.String[]]
    $ResourceGroups,
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

$resourceGroupNames = $ResourceGroups
if ($null -eq $resourceGroupNames){
    $resourceGroupNames = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName
}

Write-Output "Certificate Name; Subject Name; Thumbprint; Issuer; IssueDate; Expiration Date; Hostnames; KeyVault; Resource Group"

foreach ($resourceGroupName in $resourceGroupNames) {
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
        Write-Output ("{0}; {1}; {2}; {3}; {4}; {5}; {6}; {7}; {8}" -f 
            $cert.Name, $cert.SubjectName, $cert.Thumbprint, $cert.Issuer, $cert.IssueDate, $cert.ExpirationDate, $hostNames, $keyVaultName, $resourceGroupName)
    }
}
