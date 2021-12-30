# Mandatory routes Azure Policy example

![Routing table policy view](https://user-images.githubusercontent.com/2357647/147681206-4fdafc63-81ed-4f55-9079-8a366f675cc6.png)

This example Azure Policy audits that mandatory routes are part of the route table.

Follow step-by-step deployment instructions from [deploy.ps1](deploy.ps1).

Implemented Azure Policy logic:

- Filter on type `RouteTables`
- Filter on specific route tables based on naming convention e.g., `*important-rt`
  - You want to apply this to specific `RouteTable` and not all
  - You can use `*` to provide `like` type of match e.g., `*name` matches `my-name`
- Validate that all defined rules are found
  - You define your mandatory `Routes` and check if some of the routes are missing. 
    E.g., You have 3 mandatory routes so if you find less than 3 mandatory routes
    in your route table then that is incorrectly managed route table

If all the above conditions are in-place, then policy causes `Audit` event.

Here is example of mandatory routes configuration:

```json
[
  {
    "addressPrefix": "0.0.0.0/0",
    "nextHopType": "VirtualAppliance",
    "nextHopIpAddress": "10.20.30.40"
  },
  {
    "addressPrefix": "1.2.0.0/21",
    "nextHopType": "VirtualAppliance",
    "nextHopIpAddress": "10.20.30.40"
  },
  {
    "addressPrefix": "11.22.33.0/25",
    "nextHopType": "VirtualAppliance",
    "nextHopIpAddress": "10.20.30.40"
  }
]
```

This example deploys 3 route tables:

![deployed route tables in Azure Portal](https://user-images.githubusercontent.com/2357647/147682356-6099fb5e-fea7-4542-8543-63ed26bb6d65.png)

- `App-Valid-important-rt` is evaluted by policy and is marked as `compliant`
- `App-Ignored-rt` is not evaluated since name does not match the naming convention
- `App-Invalid-important-rt` is evaluated but does not contain mandatory routes and is marked as `non-compliant`

Here is example resource which is `non-compliant`:

![non-compliant route table](https://user-images.githubusercontent.com/2357647/147681596-5be90feb-81de-4b75-b3c6-dd5240c38a06.png)

`Details` reveals the actual reason for beeing `non-compliant`:

![route table non-compliant error since missing mandatory routes](https://user-images.githubusercontent.com/2357647/147681974-77224779-db91-4f3d-8a07-d6350f4e411f.png)

## Links

[Azure Policy definition structure / Value count examples](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure#value-count-examples)
