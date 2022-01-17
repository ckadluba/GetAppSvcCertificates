
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

function SearchAndLinkSllBindingsForWebApp {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject[]]
        $CertsAggregates,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [System.String]
        $AseId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $WebAppName,

        [Parameter(Mandatory = $false)]
        [System.String]
        $WebAppSlotName
    )

    if ($WebAppSlotName -eq "") {
        Write-Host "Searching web app SSL bindings of web app $WebAppName"
        $sslBindings = Get-AzWebAppSSLBinding -ResourceGroupName "$ResourceGroupName" -WebAppName $WebAppName
    }
    else {
        Write-Host "Searching web app SSL bindings of web app $WebAppName slot $WebAppSlotName"
        $sslBindings = Get-AzWebAppSSLBinding -ResourceGroupName "$ResourceGroupName" -WebAppName $WebAppName -Slot "$WebAppSlotName"
    }

    foreach ($sslBinding in $sslBindings) {
        $certsAggregateMatches = $CertsAggregates
            | Where-Object { ($_.Thumbprint -eq $sslBinding.Thumbprint) -and ($_.AseId -eq $AseId) }
        foreach ($certsAggregateMatch in $certsAggregateMatches) {
            if ($certsAggregateMatch.WebAppName -eq "") {
                $certsAggregateMatch.WebAppName = $WebAppName
            }
            else {
                throw "Error: web app $WebAppName has an SSL binding for cert $(certsAggregateMatch.Name) but web app $(certsAggregateMatch.WebAppName) slot $(certsAggregateMatch.WebAppSlot) also has."
            }
            if ($certsAggregateMatch.WebAppSlot -eq "") {
                $certsAggregateMatch.WebAppSlot = $WebAppSlotName
            }
            else {
                throw "Error: web app $WebAppName slot $WebAppSlotName has an SSL binding for cert $(certsAggregateMatch.Name) but web app $(certsAggregateMatch.WebAppName) slot $(certsAggregateMatch.WebAppSlot) also has."
            }
        }
    }    
}

$context = Get-AzContext
if (($null -eq $context.Subscription) -or ($context.Subscription.Name -ne $Subscription)) {
    Write-Host "Connect account and set context to subscription $Subscription"
    Connect-AzAccount -Subscription "$Subscription" | Out-Null
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
        $certObj | Add-Member "WebAppSlot" ""

        $certsAggregates += $certObj
    }
}

Write-Host "Searching web apps and SSL bindings in resource groups of subscription $Subscription"
foreach ($resourceGroupName in $resourceGroupNames) {
    Write-Host "Searching web apps in RG $resourceGroupName"
    $webApps = Get-AzWebApp -ResourceGroupName "$resourceGroupName"

    foreach ($webApp in $webApps) {
        $webAppName = $webApp.Name
        SearchAndLinkSllBindingsForWebApp $certsAggregates $resourceGroupName $webApp.HostingEnvironmentProfile.Id $webAppName

        Write-Host "Searching deploymemt slots of web app $webAppName"
        $webAppSlots = Get-AzWebAppSlot -WebApp $webApp
        foreach ($webAppSlot in $webAppSlots) {
            $webAppSlotName = ($webAppSlot.Name -split '/')[-1]
            SearchAndLinkSllBindingsForWebApp $certsAggregates $resourceGroupName $webAppSlot.HostingEnvironmentProfile.Id $webAppName $webAppSlotName
        }
    }
}

# Write CSV output
Write-Output "Certificate Name;Subject Name;Thumbprint;Issuer;IssueDate;Expiration Date;Hostnames;KeyVault Name;KeyVault Secret Name;Resource Group;ASE Name;Web App Name;Web App Slot"
foreach ($certAggregate in $certsAggregates) {
    Write-Output ("{0};{1};{2};{3};{4};{5};{6};{7};{8};{9};{10};{11};{12}" -f 
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
        $certAggregate.WebAppName,
        $certAggregate.WebAppSlot)
}
