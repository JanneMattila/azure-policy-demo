# References:
# https://github.com/Azure/azure-policy/blob/eb9d3c4df457e61df4ceaa83fe537770bbec25f3/samples/Web/deploy-webapp-ip-restrictions/azurepolicy.json
# https://github.com/Azure/azure-policy/issues/682#issuecomment-748944119
# https://docs.microsoft.com/en-us/azure/governance/policy/concepts/effects#deployifnotexists-evaluation

# Variables
$resourceGroup = "rg-azurepolicy-demo"
$location = "westeurope"
$funcAppIPRestrictions = "funcapp-ip-restrictions"

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
$resourceGroup = New-AzResourceGroup -Name $resourceGroup -Location $location -Force
$resourceGroup

# Create policy definition
$funcAppIPRestrictionsDefinition = New-AzPolicyDefinition `
    -Name $funcAppIPRestrictions `
    -Policy .\policies\add_inbound_ip_filter_to_functionapp.json `
    -Verbose
$funcAppIPRestrictionsDefinition

# Create policy assignment to resource group
$assignment = New-AzPolicyAssignment `
    -Name ipRestrictions `
    -PolicyDefinition $funcAppIPRestrictionsDefinition `
    -Scope $resourceGroup.ResourceId -AssignIdentity -Location $location

# https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#website-contributor
# $funcAppIPRestrictionsDefinition.Properties.policyRule.then.details.roleDefinitionIds[0]
# Note: If this below fails:
# "New-AzRoleAssignment: Principal 07b0c7d2-2370-4299-a018-0c99d80dcafedoes not exist in the directory cb417fc7-167f-4c45-b909-b5aecd19421c."
#       then you need to wait a bit and re-try.
New-AzRoleAssignment -ResourceGroupName $resourceGroup.ResourceGroupName -RoleDefinitionName "Website Contributor" -ObjectId $assignment.Identity.PrincipalId

# Create Azure Functions App
$funcStorage = "funcapps00000010"
$funcApp = "funcapps00000010"
#New-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -Name $funcStorage -SkuName Standard_LRS -Location $location
New-AzFunctionApp -Name $funcApp -ResourceGroupName $resourceGroup.ResourceGroupName -StorageAccount $funcStorage -Runtime DotNet -RuntimeVersion 3 -FunctionsVersion 3 -OSType Windows -DisableApplicationInsights -Location $location

# Delete Functions App (in case you want to re-run the deployments)
Remove-AzFunctionApp -Name $funcApp -ResourceGroupName $resourceGroup.ResourceGroupName -Force

# Wipe out the resources
Remove-AzPolicyAssignment -Name ipRestrictions -Scope $resourceGroup.ResourceId
Remove-AzPolicyDefinition -Name $funcAppIPRestrictions -Force
Remove-AzResourceGroup -Name $resourceGroup.ResourceGroupName -Force
