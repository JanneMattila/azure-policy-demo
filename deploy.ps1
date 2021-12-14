# References:
# https://github.com/Azure/azure-policy/blob/eb9d3c4df457e61df4ceaa83fe537770bbec25f3/samples/Web/deploy-webapp-ip-restrictions/azurepolicy.json
# https://github.com/Azure/azure-policy/issues/682#issuecomment-748944119
# https://docs.microsoft.com/en-us/azure/governance/policy/concepts/effects#deployifnotexists-evaluation

# Variables
$resourceGroupName = "rg-azurepolicy-demo"
$location = "westeurope"

# Login to Azure
Login-AzAccount

# *Explicitly* select your working context
Select-AzSubscription -Subscription AzureDev

# Show current context
Get-AzSubscription

# Aliases: https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure#aliases
# See aliases that support "modify"
Get-AzPolicyAlias | Select-Object -ExpandProperty "Aliases" | Where-Object { $_.DefaultMetadata.Attributes -eq "Modifiable" } | Format-Table

# Get aliases of "Microsoft.Web/sites"
(Get-AzPolicyAlias -NamespaceMatch "Microsoft.Web" -ResourceTypeMatch "sites").Aliases | Format-Table

# Create new resource group
$resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location -Force
$resourceGroup

# Note: You can trigger a policy compliance evaluation using this command
$job = Start-AzPolicyComplianceScan -ResourceGroupName $resourceGroup.ResourceGroupName -AsJob
$job
$job | Wait-Job

##############################################
# Azure Functions App and IP Restriction demo
##############################################
$funcAppIPRestrictions = "funcapp-ip-restrictions"

# Create policy definition
$funcAppIPRestrictionsDefinition = New-AzPolicyDefinition `
    -Name $funcAppIPRestrictions `
    -Policy .\policies\add_inbound_ip_filter_to_functionapp.json `
    -Verbose
$funcAppIPRestrictionsDefinition

# Create policy assignment to resource group
$funcAppIPRestrictionsAssignment = New-AzPolicyAssignment `
    -Name $funcAppIPRestrictions `
    -PolicyDefinition $funcAppIPRestrictionsDefinition `
    -Scope $resourceGroup.ResourceId -AssignIdentity -Location $location

# https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#website-contributor
# $funcAppIPRestrictionsDefinition.Properties.policyRule.then.details.roleDefinitionIds[0]
# Note: If this below fails:
# "New-AzRoleAssignment: Principal 07b0c7d2-2370-4299-a018-0c99d80dcafedoes not exist in the directory cb417fc7-167f-4c45-b909-b5aecd19421c."
#       then you need to wait a bit and re-try.
New-AzRoleAssignment -ResourceGroupName $resourceGroup.ResourceGroupName -RoleDefinitionName "Website Contributor" -ObjectId $funcAppIPRestrictionsAssignment.Identity.PrincipalId

# Create Azure Functions App
$funcStorage = "funcapps00000010"
$funcApp = "funcapps00000010"
New-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $funcStorage -SkuName Standard_LRS -Location $location
New-AzFunctionApp -Name $funcApp -ResourceGroupName $resourceGroup.ResourceGroupName -StorageAccount $funcStorage -Runtime DotNet -RuntimeVersion 3 -FunctionsVersion 3 -OSType Windows -DisableApplicationInsights -Location $location

# Delete Functions App (in case you want to re-run the deployments)
Remove-AzFunctionApp -Name $funcApp -ResourceGroupName $resourceGroup.ResourceGroupName -Force

# Wipe out the Functions related policy resources
Remove-AzPolicyAssignment -Name $funcAppIPRestrictions -Scope $resourceGroup.ResourceId
Remove-AzPolicyDefinition -Name $funcAppIPRestrictions -Force

# Wipe out Functions storage account
Remove-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $funcStorage -Force

#############################################
# Azure Storage Account and shared keys demo
#############################################
$storageDisableSharedKeys = "storage-disable-shared-keys"

# Create policy definition
$storageDisableSharedKeysDefinition = New-AzPolicyDefinition `
    -Name $storageDisableSharedKeys `
    -Policy .\policies\disable_shared_key_access_in_storage.json `
    -Verbose
$storageDisableSharedKeysDefinition

# Create policy assignment to resource group
$storageDisableShareKeysAssignment = New-AzPolicyAssignment `
    -Name $storageDisableSharedKeys `
    -PolicyDefinition $storageDisableSharedKeysDefinition `
    -Scope $resourceGroup.ResourceId -AssignIdentity -Location $location

# https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-account-contributor
# $storageDisableShareKeysAssignment.Properties.policyRule.then.details.roleDefinitionIds[0]
# Note: If this below fails:
# "New-AzRoleAssignment: Principal 07b0c7d2-2370-4299-a018-0c99d80dcafe does not exist in the directory cb417fc7-167f-4c45-b909-b5aecd19421c."
#       then you need to wait a bit and re-try.
New-AzRoleAssignment -ResourceGroupName $resourceGroup.ResourceGroupName -RoleDefinitionName "Storage Account Contributor" -ObjectId $storageDisableShareKeysAssignment.Identity.PrincipalId

# Create Azure Storage Account
$storage = "storageapps00000010"
New-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $storage -SkuName Standard_LRS -Location $location

# Validate storage account in portal by going into "Access keys". You should see this text:
# "Authorization with Shared Key is disabled for this account. Any requests that are authorized with Shared Key, including shared access signatures (SAS), will be denied."

# Wipe out storage account
Remove-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $storage -Force

# Wipe out the storage related policy resources
Remove-AzPolicyAssignment -Name $storageDisableSharedKeys -Scope $resourceGroup.ResourceId
Remove-AzPolicyDefinition -Name $storageDisableSharedKeys -Force

########################
# Deny by location demo
########################
$denyByLocation = "deny-by-location"

# Create policy definition
$denyByLocationDefinition = New-AzPolicyDefinition `
    -Name $denyByLocation `
    -Policy .\policies\deny_by_location.json `
    -Verbose
$denyByLocationDefinition

# Create policy assignment to resource group
$denyByLocationNonComplianceMessages = @(
    @{
        Message = "Policy to deny resource based on location. For more details see: https://bit.ly/AzurePolicyLink"; 
    })

New-AzPolicyAssignment `
    -Name $denyByLocation `
    -DisplayName $denyByLocation `
    -PolicyDefinition $denyByLocationDefinition `
    -Scope $resourceGroup.ResourceId `
    -NonComplianceMessage $denyByLocationNonComplianceMessages # <- notice we'll provide link for more information

# Create Azure Storage Account
$storageDenied = "storageapps00000011"
New-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $storageDenied -SkuName Standard_LRS -Location "eastasia" -Verbose

# You should receive following error message:
# "New-AzStorageAccount: Resource 'storageapps00000011' was disallowed by policy. Reasons: 'Policy to deny resource based on location. For more details see: https://bit.ly/AzurePolicyLink'. See error details for policy resource IDs."
# In portal:
# "Policy to deny resource based on location. For more details see: https://bit.ly/AzurePolicyLink"

# Wipe out storage account
Remove-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $storageDenied -Force

# Wipe out the storage related policy resources
Remove-AzPolicyAssignment -Name $denyByLocation -Scope $resourceGroup.ResourceId
Remove-AzPolicyDefinition -Name $denyByLocation -Force


#######################################
# Private DNS Zone integration at scale
#######################################
$denyPrivateDNSZoneCreation = "deny-creation-privatednszones"

# Create policy definition
$denyPrivateDNSZoneCreationDefinition = New-AzPolicyDefinition `
    -Name $denyPrivateDNSZoneCreation `
    -Policy .\private-link-and-dns-integration\deny-privatednszone-privatelink.json `
    -Verbose
$denyPrivateDNSZoneCreationDefinition

# Create policy assignment to resource group
$denyPrivateDNSZoneCreationAssignment = New-AzPolicyAssignment `
    -Name $denyPrivateDNSZoneCreation `
    -PolicyDefinition $denyPrivateDNSZoneCreationDefinition `
    -Scope $resourceGroup.ResourceId -Location $location

# Try to create new Private DNS Zone
$privateDNSZoneTable = "privatelink.table.core.windows.net"
$privateDNSZoneBlob = "privatelink.blob.core.windows.net"
New-AzPrivateDnsZone -ResourceGroupName $resourceGroup.ResourceGroupName -Name $privateDNSZoneTable
# -> New-AzPrivateDnsZone: Resource 'privatelink.table.core.windows.net' was disallowed by policy.
Remove-AzPrivateDnsZone -ResourceGroupName $resourceGroup.ResourceGroupName -Name $privateDNSZoneTable

# Centralized resource group for Private DNS Zones
$resourceGroupSharedName = "rg-azurepolicy-shared-demo"
$resourceGroupShared = New-AzResourceGroup -Name $resourceGroupSharedName -Location $location -Force
$resourceGroupShared

# Create Private DNS Zones to the centralized shared resource group
$tablePrivateDnsZone = New-AzPrivateDnsZone -ResourceGroupName $resourceGroupShared.ResourceGroupName -Name $privateDNSZoneTable
$tablePrivateDnsZone.ResourceId
$blobPrivateDnsZone = New-AzPrivateDnsZone -ResourceGroupName $resourceGroupShared.ResourceGroupName -Name $privateDNSZoneBlob
$blobPrivateDnsZone.ResourceId

# If we want to dynamically fill in the resource id of Private DNS Zone of 'table'
$json = ConvertFrom-Json (Get-Content -Path .\private-link-and-dns-integration\deploy-private-endpoint-to-privatednszone.parameters.json -Raw)

# Update map of "groupIds" to "Private DNS Zone"
$json.parameters.map.value.table = $tablePrivateDnsZone.ResourceId
$json.parameters.map.value.blob = $blobPrivateDnsZone.ResourceId

# Update out template file
ConvertTo-Json -Depth 100 -InputObject $json | Set-Content -Path .\private-link-and-dns-integration\deploy-private-endpoint-to-privatednszone.parameters.json

# Create and deploy policies
$deployPrivateEndpointToPrivateDNSZone = "deploy-private-endpoint-to-privatednszone"

# Create policy definition
$deployPrivateEndpointToPrivateDNSZoneDefinition = New-AzPolicyDefinition `
    -Name $deployPrivateEndpointToPrivateDNSZone `
    -Policy .\private-link-and-dns-integration\deploy-private-endpoint-to-privatednszone.json `
    -Parameter .\private-link-and-dns-integration\deploy-private-endpoint-to-privatednszone.parameters.json `
    -Verbose
$deployPrivateEndpointToPrivateDNSZoneDefinition

# Create policy assignment to resource group
$deployPrivateEndpointToPrivateDNSZoneAssignment = New-AzPolicyAssignment `
    -Name $deployPrivateEndpointToPrivateDNSZone `
    -PolicyDefinition $deployPrivateEndpointToPrivateDNSZoneDefinition `
    -Scope $resourceGroup.ResourceId -AssignIdentity -Location $location

# https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
# Note: If this below fails:
# "New-AzRoleAssignment: Principal 07b0c7d2-2370-4299-a018-0c99d80dcafe does not exist in the directory cb417fc7-167f-4c45-b909-b5aecd19421c."
#       then you need to wait a bit and re-try.
New-AzRoleAssignment -ResourceGroupName $resourceGroup.ResourceGroupName -RoleDefinitionName "Network Contributor" -ObjectId $deployPrivateEndpointToPrivateDNSZoneAssignment.Identity.PrincipalId
New-AzRoleAssignment -ResourceGroupName $resourceGroupShared.ResourceGroupName -RoleDefinitionName "Private DNS Zone Contributor" -ObjectId $deployPrivateEndpointToPrivateDNSZoneAssignment.Identity.PrincipalId

# Create virtual network
$subnet = New-AzVirtualNetworkSubnetConfig -Name "subnet1" -AddressPrefix "172.19.0.0/24" -PrivateEndpointNetworkPoliciesFlag "disabled" -PrivateLinkServiceNetworkPoliciesFlag "disabled"
$vnet = New-AzVirtualNetwork -Name "vnet" -ResourceGroupName $resourceGroup.ResourceGroupName -Location $location -AddressPrefix "172.19.0.0/16" -Subnet $subnet
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "subnet1" -VirtualNetwork $vnet

# Create storage account
$storageForPEs = "storpolicy00000010"
$storageAccountForPEs = New-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $storageForPEs -SkuName Standard_LRS -Location $location

# Create private endpoint for table
$connectionTable = New-AzPrivateLinkServiceConnection -Name "$tableStorage-connection" -PrivateLinkServiceId $storageAccountForPEs.Id -GroupId "table"
$peTable = New-AzPrivateEndpoint -Name "pe-table" -ResourceGroupName $resourceGroup.ResourceGroupName -Location $location -Subnet $subnet -PrivateLinkServiceConnection $connectionTable

# Create private endpoint for blob
$connectionBlob = New-AzPrivateLinkServiceConnection -Name "$tableStorage-connection" -PrivateLinkServiceId $storageAccountForPEs.Id -GroupId "blob"
$peBlob = New-AzPrivateEndpoint -Name "pe-blob" -ResourceGroupName $resourceGroup.ResourceGroupName -Location $location -Subnet $subnet -PrivateLinkServiceConnection $connectionBlob

# Remove private endpoint
Remove-AzPrivateEndpoint -Name "pe-table" -ResourceGroupName $resourceGroup.ResourceGroupName -Force
Remove-AzPrivateEndpoint -Name "pe-blob" -ResourceGroupName $resourceGroup.ResourceGroupName -Force

# Wipe out the Private DNS Zone related policy resources
Remove-AzPolicyAssignment -Name $deployPrivateEndpointToPrivateDNSZone -Scope $resourceGroup.ResourceId
Remove-AzPolicyDefinition -Name $deployPrivateEndpointToPrivateDNSZone -Force

Remove-AzPolicyAssignment -Name $denyPrivateDNSZoneCreation -Scope $resourceGroup.ResourceId
Remove-AzPolicyDefinition -Name $denyPrivateDNSZoneCreation -Force

# Wipe out storage account
Remove-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $tableStorage -Force

# Wipe out the resources
Remove-AzResourceGroup -Name $resourceGroup.ResourceGroupName -Force
