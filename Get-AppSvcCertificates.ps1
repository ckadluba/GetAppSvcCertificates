
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
    [System.String[]]
    $Thumbprints
)

$context = Get-AzContext
if ($null -eq $context.Subscription || $context.Subscription.Name -ne $Subscription) {
    Write-Host "Connect account and set context to subscription $Subscription"
    Connect-AzAccount -Subscription "$Subscription"
}

$resourceGroupNames = $ResourceGroups
if ($null -eq $resourceGroupNames) {
    Write-Host "Searching all resource groups in subscription $Subscription"
    $resourceGroupNames = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName
}

$certsAggregates = @()

Write-Host "Searching web app certificates in resource groups of subscription $Subscription"
foreach ($resourceGroupName in $resourceGroupNames) {
    Write-Host "Searching web app certificates in RG $resourceGroupName"
    $certs = Get-AzWebAppCertificate -ResourceGroupName "$resourceGroupName"
    foreach ($cert in $certs) {
        if ($null -ne $ExpiresBefore) {
            if ([System.DateTime]::Compare($ExpiresBefore, $cert.ExpirationDate) -lt 0) {
                continue
            }
        }

        if ($null -ne $Thumbprints) {
            if (-not ($Thumbprints.Contains($cert.Thumbprint))) {
                continue
            }
        }

        $certObj = New-Object -TypeName PSObject
        $certObj | Add-Member -NotePropertyName "Name" -NotePropertyValue $cert.Name
        $certObj | Add-Member -NotePropertyName "SubjectName" -NotePropertyValue $cert.SubjectName
        $certObj | Add-Member -NotePropertyName "Thumbprint" -NotePropertyValue $cert.Thumbprint
        $certObj | Add-Member -NotePropertyName "Issuer" -NotePropertyValue $cert.Issuer
        $certObj | Add-Member -NotePropertyName "IssueDate" -NotePropertyValue $cert.IssueDate
        $certObj | Add-Member -NotePropertyName "ExpirationDate" -NotePropertyValue $cert.ExpirationDate
        $certObj | Add-Member -NotePropertyName "KeyVaultSecretName" -NotePropertyValue $cert.KeyVaultSecretName
        
        $hostNames = [System.String]::Join(", ", $cert.HostNames)
        $keyVaultName = ($cert.KeyVaultId -split '/')[-1]
        $certObj | Add-Member -NotePropertyName "HostNamesFlat" -NotePropertyValue $hostNames
        $certObj | Add-Member "KeyVaultName" $keyVaultName
        $certObj | Add-Member "ResourceGroupName" $resourceGroupName
        $certObj | Add-Member "AseName" $cert.HostingEnvironmentProfile.Name
        $certObj | Add-Member "AseId" $cert.HostingEnvironmentProfile.Id
        $certObj | Add-Member "WebAppName" ""

        $certsAggregates += $certObj
    }
}

Write-Host "Searching web apps and SSL bindings in resource groups of subscription $Subscription"
foreach ($resourceGroupName in $resourceGroupNames) {
    Write-Host "Searching web apps in RG $resourceGroupName"
    $webApps = Get-AzWebApp -ResourceGroupName "$resourceGroupName"

    foreach ($webApp in $webApps) {
        $webAppName = $webApp.Name
        Write-Host "Searching web app SSL bindings of web app $webAppName"
        $sslBindings = Get-AzWebAppSSLBinding -ResourceGroupName "$resourceGroupName" -WebAppName $webAppName
        foreach ($sslBinding in $sslBindings) {
            $certsAggregatesMatch = $certsAggregates
                | Where-Object { ($_.Thumbprint -eq $sslBinding.Thumbprint) -and ($_.AseId -eq $webApp.HostingEnvironmentProfile.Id) }
            foreach ($certsAggregateMatch in $certsAggregatesMatch) {
                if ($certsAggregateMatch.WebAppName -eq "") {
                    $certsAggregateMatch.WebAppName = $webAppName
                }
                else {
                    $certsAggregateMatch.WebAppName += ", " + $webAppName
                }
            }
        }
    }
}

# Write CSV output
Write-Output "Certificate Name;Subject Name;Thumbprint;Issuer;IssueDate;Expiration Date;Hostnames;KeyVault Name;KeyVault Secret Name;Resource Group;ASE Name;Web App Name"
foreach ($certAggregate in $certsAggregates) {
    Write-Output ("{0};{1};{2};{3};{4};{5};{6};{7};{8};{9};{10};{11}" -f 
        $certAggregate.Name, 
        $certAggregate.SubjectName, 
        $certAggregate.Thumbprint, 
        $certAggregate.Issuer, 
        $certAggregate.IssueDate, 
        $certAggregate.ExpirationDate, 
        $certAggregate.HostNamesFlat, 
        $certAggregate.KeyVaultName, 
        $certAggregate.KeyVaultSecretName, 
        $certAggregate.ResourceGroupName, 
        $certAggregate.AseName, 
        $certAggregate.WebAppName)
}
