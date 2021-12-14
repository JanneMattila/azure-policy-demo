#######################################
# Private DNS Zone integration at scale
#######################################
# Application team's resource group
$resourceGroupName = "rg-azurepolicy-app-demo"
# Centralized platform resource group for Private DNS Zones
$resourceGroupSharedName = "rg-azurepolicy-platform-demo"
$location = "westeurope"

# This examples now uses 'table' and 'blob' privatelinks
$privateDNSZoneTable = "privatelink.table.core.windows.net"
$privateDNSZoneBlob = "privatelink.blob.core.windows.net"

# Login to Azure
Login-AzAccount

# *Explicitly* select your working context
Select-AzSubscription -Subscription AzureDev

# Show current context
Get-AzSubscription

# Create new resource group for application team
$resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location -Force
$resourceGroup

# Centralized platform resource group for Private DNS Zones
$resourceGroupShared = New-AzResourceGroup -Name $resourceGroupSharedName -Location $location -Force
$resourceGroupShared

# Note: You can trigger a policy compliance evaluation using this command
$job = Start-AzPolicyComplianceScan -ResourceGroupName $resourceGroup.ResourceGroupName -AsJob
$job
$job | Wait-Job

###################################################
#  ____  _        _  _____ _____ ___  ____  __  __
# |  _ \| |      / \|_   _|  ___/ _ \|  _ \|  \/  |
# | |_) | |     / _ \ | | | |_ | | | | |_) | |\/| |
# |  __/| |___ / ___ \| | |  _|| |_| |  _ <| |  | |
# |_|   |_____/_/   \_\_| |_|   \___/|_| \_\_|  |_|
# team does preparations first
###################################################
$denyPrivateDNSZoneCreation = "deny-creation-privatednszones"

# 1. Create policy for preventing application teams to create Private DNS Zones
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

# 2. Create Private DNS Zones to the centralized shared resource group
$tablePrivateDnsZone = New-AzPrivateDnsZone -ResourceGroupName $resourceGroupShared.ResourceGroupName -Name $privateDNSZoneTable
$tablePrivateDnsZone.ResourceId
$blobPrivateDnsZone = New-AzPrivateDnsZone -ResourceGroupName $resourceGroupShared.ResourceGroupName -Name $privateDNSZoneBlob
$blobPrivateDnsZone.ResourceId

# If we want to dynamically fill in the resource id of Private DNS Zone of 'table' and 'blob'
$json = ConvertFrom-Json (Get-Content -Path .\private-link-and-dns-integration\deploy-private-endpoint-to-privatednszone.parameters.json -Raw)

# Update map of "groupIds" to "Private DNS Zone"
$json.map.defaultValue.table = $tablePrivateDnsZone.ResourceId
$json.map.defaultValue.blob = $blobPrivateDnsZone.ResourceId

# Update our template file
ConvertTo-Json -Depth 100 -InputObject $json | Set-Content -Path .\private-link-and-dns-integration\deploy-private-endpoint-to-privatednszone.parameters.json
Get-Content .\private-link-and-dns-integration\deploy-private-endpoint-to-privatednszone.parameters.json

# Create and deploy policies to automatically update 
# centralized platform Private DNS Zones when private endpoints are created
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

# 3. Application teams can now continue working.

########################################
#     _    ____  ____
#    / \  |  _ \|  _ \
#   / _ \ | |_) | |_) |
#  / ___ \|  __/|  __/
# /_/   \_\_|   |_|
# team starts using their resource group
########################################
# Try to create new Private DNS Zone
New-AzPrivateDnsZone -ResourceGroupName $resourceGroup.ResourceGroupName -Name $privateDNSZoneTable
# -> New-AzPrivateDnsZone: Resource 'privatelink.table.core.windows.net' was disallowed by policy.
# Note: You have small time window after above 'deny' policy is created and when it becomes active.
Remove-AzPrivateDnsZone -ResourceGroupName $resourceGroup.ResourceGroupName -Name $privateDNSZoneTable

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
$peTable

# Create private endpoint for blob
$connectionBlob = New-AzPrivateLinkServiceConnection -Name "$tableStorage-connection" -PrivateLinkServiceId $storageAccountForPEs.Id -GroupId "blob"
$peBlob = New-AzPrivateEndpoint -Name "pe-blob" -ResourceGroupName $resourceGroup.ResourceGroupName -Location $location -Subnet $subnet -PrivateLinkServiceConnection $connectionBlob
$peBlob

# Create a remediation for a specific assignment
$remediation = Start-AzPolicyRemediation -Name "pe-remediation" -PolicyAssignmentId $deployPrivateEndpointToPrivateDNSZoneAssignment.ResourceId -Scope $resourceGroup.ResourceId
$remediation

###################################
#   ____ _     _____    _    _   _
#  / ___| |   | ____|  / \  | \ | |
# | |   | |   |  _|   / _ \ |  \| |
# | |___| |___| |___ / ___ \| |\  |
#  \____|_____|_____/_/   \_\_| \_|
# your resources
###################################

# Remove private endpoint
Remove-AzPrivateEndpoint -Name "pe-table" -ResourceGroupName $resourceGroup.ResourceGroupName -Force
Remove-AzPrivateEndpoint -Name "pe-blob" -ResourceGroupName $resourceGroup.ResourceGroupName -Force
# Note: Matching Private DNS Zones will be reflected automatically.

# Wipe out the Private DNS Zone related policy resources
Remove-AzPolicyAssignment -Name $deployPrivateEndpointToPrivateDNSZone -Scope $resourceGroup.ResourceId
Remove-AzPolicyDefinition -Name $deployPrivateEndpointToPrivateDNSZone -Force

Remove-AzPolicyAssignment -Name $denyPrivateDNSZoneCreation -Scope $resourceGroup.ResourceId
Remove-AzPolicyDefinition -Name $denyPrivateDNSZoneCreation -Force

# Wipe out storage account
Remove-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $tableStorage -Force

# Wipe out the resources
Remove-AzResourceGroup -Name $resourceGroup.ResourceGroupName -Force
Remove-AzResourceGroup -Name $resourceGroupSharedName.ResourceGroupName -Force
