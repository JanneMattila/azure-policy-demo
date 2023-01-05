############################
#  ____        _
# / ___| _   _| |__  ___
# \___ \| | | | '_ \/ __|
#  ___) | |_| | |_) \__ \
# |____/ \__,_|_.__/|___/ 
# Subcription level example
############################
$context = Get-AzContext
$manual_minimize_number_of_admins = "manual-minimize-number-of-admins"

# Create policy definition
$manual_minimize_number_of_admins_definition = New-AzPolicyDefinition `
    -DisplayName "Minimize number of admins" `
    -Name $manual_minimize_number_of_admins `
    -Policy .\manual\minimize-number-of-admins.json `
    -Verbose
$manual_minimize_number_of_admins_definition

# Create policy assignment to subscription level
$subscription_scope = "/subscriptions/$($context.Subscription.Id)"
$nonComplianceMessages = @(
    @{
        Message = "You need to provide attestation for this policy. For more details see: https://bit.ly/AzurePolicyLink"; 
    })
$manual_minimize_number_of_admins_assignment = New-AzPolicyAssignment `
    -DisplayName "Minimize number of admins" `
    -Name $manual_minimize_number_of_admins `
    -PolicyDefinition $manual_minimize_number_of_admins_definition `
    -Scope $subscription_scope `
    -NonComplianceMessage $nonComplianceMessages
$manual_minimize_number_of_admins_assignment

# Manage attestation of the policy assignment
$attestation_id = [System.Guid]::NewGuid().ToString("D")
$my_object_id = $context.Account.ExtendedProperties.HomeAccountId.Split('.')[0]
$body = ConvertTo-Json @{
    "properties" = @{
        "policyAssignmentId"          = "$($manual_minimize_number_of_admins_assignment.PolicyAssignmentId)"
        "policyDefinitionReferenceId" = "$($manual_minimize_number_of_admins_definition.PolicyDefinitionId)"
        "complianceState"             = "Compliant"
        "assessmentDate"              = [System.DateTime]::UtcNow
        "expiresOn"                   = [System.DateTime]::UtcNow.AddDays(60)
        "owner"                       = "$my_object_id"
        "comments"                    = "Validated and can confirm that number of admins are checked"
        "evidence"                    = @(
            @{
                "description" = "Link to the team documentation"
                "sourceUri"   = "https://bit.ly/AzurePolicyLink"
            })
        "metadata"                    = @{
            "WBS"     = "ABC123"
            "Support" = "app-dev-team@contoso.com"
        }
    }
} -Depth 50
$body

$url = $subscription_scope + "/providers/Microsoft.PolicyInsights/attestations/$attestation_id" + "?api-version=2022-09-01"
$url

$result_create = Invoke-AzRestMethod `
    -Method "PUT" `
    -Payload $body `
    -Path $url
$result_create

# Wipe out policy assignment and policy definition
Remove-AzPolicyAssignment -Name $manual_minimize_number_of_admins -Scope $subscription_scope
Remove-AzPolicyDefinition -Name $manual_minimize_number_of_admins -Force
