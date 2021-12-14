# Private Link and DNS integration at scale

Here is small example how to deploy
[Private Link and DNS integration at scale](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale).

Use `deploy.ps1` to execute the commands and mimic the `platform` and `application` teams.

Demo uses only `table` and `blob` services as examples. Remember to implemented
all required services including `table_secondary` and `blob_secondary`. 
Full list available at
[Azure Private Endpoint DNS configuration](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration)

## Links

[Azure Policy Field expressions](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure#fields)
