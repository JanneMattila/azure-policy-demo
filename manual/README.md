# Manual effect

[Secure DevOps Kit for Azure (AzSK)](https://github.com/azsk/DevOpsKit-docs)
(later replaced by [Azure Tenant Security Solution (AzTS)](https://github.com/azsk/AzTS-docs))
introduced process to [control Attestation](https://github.com/azsk/DevOpsKit-docs/blob/master/00c-Addressing-Control-Failures/Readme.md#control-attestation-1)
manually for different [Security Verification Tests (SVT)](https://github.com/azsk/DevOpsKit-docs/blob/master/02-Secure-Development/Readme.md#security-verification-tests-svt-1).
Using that functionality you could manage process to manually validate things and then
provide that manual approval including [expiration](https://github.com/azsk/DevOpsKit-docs/blob/master/00c-Addressing-Control-Failures/Readme.md#attestation-expiry)
to the system.

Similar process can be now managed with Azure Policies and [manual effect](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/effects#manual-preview).

See detailed walk-through in [deploy.ps1](./manual/deploy.ps1).

## Subscription example

**Example**: Minimize the number of admins/owners in the subscription level ([reference to original AzSK](https://github.com/azsk/DevOpsKit-docs/blob/master/02-Secure-Development/ControlCoverage/Feature/SubscriptionCore.md))

1. Create policy definition [minimize-number-of-admins.json](./manual/minimize-number-of-admins.json)
2. Assign it to Management Group or Subscription level
3. You should now see `Non-compliant` status in portal:
![Non-compliant status in the example policy](https://user-images.githubusercontent.com/2357647/210795845-90ef613f-12e5-49af-a3ca-7add5bcd4497.png)
4. You can attest by using attestations [Rest API](https://learn.microsoft.com/en-us/rest/api/policy/attestations)
  - Provide owner, comments, evidence and expiry information in the
  - See detailed example in [deploy.ps1](./manual/deploy.ps1)
5. You should now see `Compliant` status in portal:
![Compliant status in the example policy](https://user-images.githubusercontent.com/2357647/210875388-772af1dd-935d-4b02-aeed-80e8677181cf.png)
