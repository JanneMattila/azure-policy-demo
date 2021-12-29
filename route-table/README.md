# Mandatory route tables example

![Routing table policy view](https://user-images.githubusercontent.com/2357647/147681206-4fdafc63-81ed-4f55-9079-8a366f675cc6.png)

This example validates that mandatory routes are part of the route table.

Follow step-by-step instructions from [deploy.ps1](deploy.ps1).

Azure Policy logic:

- Filter on type `RouteTables`
- Filter on specific route tables based on naming convention e.g., `*important-rt`
  - You want to apply this to specific `RouteTable` and not all
- Validate that all defined rules are found
  - You define your mandatory `Routes` and check if some of the routes are missing

If all the above conditions are met, then policy causes `Audit` event.

Example deploys 3 route tables:

![deployed route tables in Azure Portal](https://user-images.githubusercontent.com/2357647/147682356-6099fb5e-fea7-4542-8543-63ed26bb6d65.png)

- `App-Valid-important-rt` is evaluted by policy and is `compliant`
- `App-Ignored-rt` is not evaluated since name does not match the required naming
- `App-Invalid-important-rt` is evaluated but does not contain mandatory routes and is `non-compliant`

Here is example resource which is `non-compliant`:

![non-compliant route table](https://user-images.githubusercontent.com/2357647/147681596-5be90feb-81de-4b75-b3c6-dd5240c38a06.png)

![route table non-compliant error since missing mandatory routes](https://user-images.githubusercontent.com/2357647/147681974-77224779-db91-4f3d-8a07-d6350f4e411f.png)

## Links

[Azure Policy definition structure / Value count examples](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure#value-count-examples)
