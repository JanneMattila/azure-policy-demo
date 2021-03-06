$resourceGroupName = "rg-azurepolicy-routetable-demo"
$location = "westeurope"

# Login to Azure
Login-AzAccount

# *Explicitly* select your working context
Select-AzSubscription -Subscription AzureDev

# Create new resource group for application team
$resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location -Force
$resourceGroup

# Note: You can trigger a policy compliance evaluation using this command
$job = Start-AzPolicyComplianceScan -ResourceGroupName $resourceGroup.ResourceGroupName -AsJob
$job
$job | Wait-Job

# Policy definition name
$auditRouteTables = "RoutingTable Audit"

# Create policy for verifying that route tables contain mandatory routes
$auditRouteTablesDefinition = New-AzPolicyDefinition `
    -Name $auditRouteTables `
    -Policy .\route-table\audit-route-table.json `
    -Verbose
$auditRouteTablesDefinition

# Create policy assignment to resource group
$auditRouteTablesAssignment = New-AzPolicyAssignment `
    -Name $auditRouteTables `
    -PolicyDefinition $auditRouteTablesDefinition `
    -Scope $resourceGroup.ResourceId -Location $location

################
# Create routes
################
# Correct mandatory routes
$route1 = New-AzRouteConfig -Name "Route01" -AddressPrefix "0.0.0.0/0" -NextHopType "VirtualAppliance" -NextHopIpAddress "10.20.30.40"
$route2 = New-AzRouteConfig -Name "Route02" -AddressPrefix "1.2.0.0/21" -NextHopType "VirtualAppliance" -NextHopIpAddress "10.20.30.40"
$route3 = New-AzRouteConfig -Name "Route03" -AddressPrefix "11.22.33.0/25" -NextHopType "VirtualAppliance" -NextHopIpAddress "10.20.30.40"

# Incorrect route (but similar to route01)
$route1incorrect = New-AzRouteConfig -Name "Route01wrong" -AddressPrefix "0.0.0.0/0" -NextHopType "VirtualAppliance" -NextHopIpAddress "11.21.31.41"

# Additional route
$route4 = New-AzRouteConfig -Name "Route04" -AddressPrefix "100.200.230.0/25" -NextHopType "VirtualAppliance" -NextHopIpAddress "1.2.3.4"

# Notice that name contains "important-rt"
$routeTableValid = "App-Valid-important-rt"

# Create route table
New-AzRouteTable `
    -Name $routeTableValid `
    -ResourceGroupName $resourceGroupName `
    -Location $location -Route $route1, $route2, $route3, $route4

# Notice that name does not contain "important" and will be ignored
$routeTableIgnored = "App-Ignored-rt"

# Create route table without routes
New-AzRouteTable `
    -Name $routeTableIgnored `
    -ResourceGroupName $resourceGroupName `
    -Location $location -Route $route1, $route2, $route3, $route4

# Notice that name does contain "important"
$routeTableInvalid = "App-Invalid-important-rt"

# Create route table without routes
New-AzRouteTable `
    -Name $routeTableInvalid `
    -ResourceGroupName $resourceGroupName `
    -Location $location -Route $route1incorrect, $route2, $route3, $route4

###################################
#   ____ _     _____    _    _   _
#  / ___| |   | ____|  / \  | \ | |
# | |   | |   |  _|   / _ \ |  \| |
# | |___| |___| |___ / ___ \| |\  |
#  \____|_____|_____/_/   \_\_| \_|
# your resources
###################################

# Remove route tables
Remove-AzRouteTable -Name $routeTableValid -ResourceGroupName $resourceGroupName -Force
Remove-AzRouteTable -Name $routeTableIgnored -ResourceGroupName $resourceGroupName -Force
Remove-AzRouteTable -Name $routeTableInvalid -ResourceGroupName $resourceGroupName -Force

# Wipe out the policy resources
Remove-AzPolicyAssignment -Name $auditRouteTables -Scope $resourceGroup.ResourceId
Remove-AzPolicyDefinition -Name $auditRouteTables -Force

# Wipe out the resources
Remove-AzResourceGroup -Name $resourceGroup.ResourceGroupName -Force
