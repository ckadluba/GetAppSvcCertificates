
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

function SearchAndLinkSllBindingsForWebAppOrSlot {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject[]]
        $CertsAggregates,

        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Management.WebSites.Models.HostNameSslState[]]
        $HostNameSslStates,

        [Parameter(Mandatory = $true)]
        [System.String]
        $WebAppName,

        [Parameter(Mandatory = $false)]
        [System.String]
        $WebAppSlotName
    )

    $activeHostNameSslStates = $HostNameSslStates | Where-Object { ($_.SslState -ne "Disabled") -and ($_.Thumbprint -ne "") }

    foreach ($hostNameSslState in $activeHostNameSslStates) {
        $certsAggregateMatches = $CertsAggregates | Where-Object { $_.Thumbprint -eq $hostNameSslState.Thumbprint }
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

    # Only add web app and slot to certs found in the same RG
    $certAggregatesOfCurrentResourceGroup = $certsAggregates | Where-Object { $_.ResourceGroupName -eq $ResourceGroupName }
    if ($null -eq $certAggregatesOfCurrentResourceGroup) {
        Write-Host "No web app certificates found in RG $resourceGroupName"
        continue
    }

    Write-Host "Searching web apps in RG $resourceGroupName"
    $webApps = Get-AzWebApp -ResourceGroupName "$resourceGroupName"

    foreach ($webApp in $webApps) {
        $webAppName = $webApp.Name
        SearchAndLinkSllBindingsForWebAppOrSlot $certAggregatesOfCurrentResourceGroup $webApp.HostNameSslStates $webAppName

        Write-Host "Searching deployment slots of web app $webAppName"
        $webAppSlots = Get-AzWebAppSlot -WebApp $webApp
        foreach ($webAppSlot in $webAppSlots) {
            $webAppSlotName = ($webAppSlot.Name -split '/')[-1]
            SearchAndLinkSllBindingsForWebAppOrSlot $certAggregatesOfCurrentResourceGroup $webAppSlot.HostNameSslStates $webAppName $webAppSlotName
        }
    }
}

Write-Output $certsAggregates | ConvertTo-Csv -Delimiter ';'
