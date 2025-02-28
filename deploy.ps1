# References:
# https://github.com/Azure/azure-policy/blob/eb9d3c4df457e61df4ceaa83fe537770bbec25f3/samples/Web/deploy-webapp-ip-restrictions/azurepolicy.json
# https://github.com/Azure/azure-policy/issues/682#issuecomment-748944119
# https://docs.microsoft.com/en-us/azure/governance/policy/concepts/effects#deployifnotexists-evaluation

# Variables
$resourceGroupName = "rg-azurepolicy-demo"
$location = "swedencentral"

# Login to Azure
Login-AzAccount

# *Explicitly* select your working context
Select-AzSubscription -Subscription "sandbox"

# Show current context
Get-AzContext

# Aliases: https://learn.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure-basics#aliases
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
$policyParameters = @{"allowedIPAddresses" = @(
        @{
            action    = "Allow";
            ipAddress = "11.22.33.44/32";
            name      = "Allowed app";
            priority  = 100;
        }
    ) 
}
$funcAppIPRestrictionsAssignment = New-AzPolicyAssignment `
    -Name $funcAppIPRestrictions `
    -PolicyDefinition $funcAppIPRestrictionsDefinition `
    -PolicyParameterObject $policyParameters `
    -Scope $resourceGroup.ResourceId -IdentityType SystemAssigned -Location $location

# https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#website-contributor
# $funcAppIPRestrictionsDefinition.Properties.policyRule.then.details.roleDefinitionIds[0]
# Note: If this below fails:
# "New-AzRoleAssignment: Principal 07b0c7d2-2370-4299-a018-0c99d80dcafedoes not exist in the directory cb417fc7-167f-4c45-b909-b5aecd19421c."
#       then you need to wait a bit and re-try.
New-AzRoleAssignment -ResourceGroupName $resourceGroup.ResourceGroupName -RoleDefinitionName "Website Contributor" -ObjectId $funcAppIPRestrictionsAssignment.IdentityPrincipalId

# Create Azure Functions App
$funcStorage = "funcapps00000010"
$funcApp = "funcapps00000010"
New-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $funcStorage -SkuName Standard_LRS -Location $location
New-AzFunctionApp -Name $funcApp -ResourceGroupName $resourceGroup.ResourceGroupName -StorageAccount $funcStorage -Runtime DotNet -RuntimeVersion 8 -FunctionsVersion 4 -OSType Windows -DisableApplicationInsights -Location $location

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
    -Scope $resourceGroup.ResourceId -IdentityType SystemAssigned -Location $location

# https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-account-contributor
# $storageDisableShareKeysAssignment.Properties.policyRule.then.details.roleDefinitionIds[0]
# Note: If this below fails:
# "New-AzRoleAssignment: Principal 07b0c7d2-2370-4299-a018-0c99d80dcafe does not exist in the directory cb417fc7-167f-4c45-b909-b5aecd19421c."
#       then you need to wait a bit and re-try.
New-AzRoleAssignment -ResourceGroupName $resourceGroup.ResourceGroupName -RoleDefinitionName "Storage Account Contributor" -ObjectId $storageDisableShareKeysAssignment.IdentityPrincipalId

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

# Wipe out the resources
Remove-AzResourceGroup -Name $resourceGroup.ResourceGroupName -Force
