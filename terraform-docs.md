<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.85.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 3.85.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_compute"></a> [compute](#module\_compute) | ./modules/compute | n/a |
| <a name="module_database"></a> [database](#module\_database) | ./modules/database | n/a |
| <a name="module_monitoring"></a> [monitoring](#module\_monitoring) | ./modules/monitoring | n/a |
| <a name="module_networking"></a> [networking](#module\_networking) | ./modules/networking | n/a |
| <a name="module_security"></a> [security](#module\_security) | ./modules/security | n/a |
| <a name="module_vwan"></a> [vwan](#module\_vwan) | ./modules/vwan | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_resource_group.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_resource_group.secondary](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | Admin email for notifications | `string` | n/a | yes |
| <a name="input_allowed_ip_ranges"></a> [allowed\_ip\_ranges](#input\_allowed\_ip\_ranges) | IP ranges allowed to access resources | `list(string)` | `[]` | no |
| <a name="input_branch_sites"></a> [branch\_sites](#input\_branch\_sites) | Branch site configurations for S2S VPN | <pre>map(object({<br/>    address_space = list(string)<br/>    vpn_gateway_address = string<br/>    pre_shared_key = string<br/>    bandwidth_mbps = number<br/>  }))</pre> | `{}` | no |
| <a name="input_database_sku"></a> [database\_sku](#input\_database\_sku) | SKU for PostgreSQL database | `string` | `"GP_Standard_D2s_v3"` | no |
| <a name="input_enable_vwan_firewall"></a> [enable\_vwan\_firewall](#input\_enable\_vwan\_firewall) | Enable Azure Firewall in vWAN hub | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod) | `string` | n/a | yes |
| <a name="input_express_route_circuits"></a> [express\_route\_circuits](#input\_express\_route\_circuits) | ExpressRoute circuit configurations | <pre>map(object({<br/>    service_provider = string<br/>    peering_location = string<br/>    bandwidth_mbps = number<br/>    sku_tier = string<br/>    sku_family = string<br/>  }))</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for resources | `string` | `"eastus2"` | no |
| <a name="input_location_short"></a> [location\_short](#input\_location\_short) | Short form of Azure region for naming | `string` | `"eus2"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name used for resource naming | `string` | n/a | yes |
| <a name="input_secondary_location"></a> [secondary\_location](#input\_secondary\_location) | Secondary Azure region for vWAN and DR | `string` | `"westus2"` | no |
| <a name="input_secondary_location_short"></a> [secondary\_location\_short](#input\_secondary\_location\_short) | Short form of secondary Azure region | `string` | `"wus2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags for all resources | `map(string)` | `{}` | no |
| <a name="input_vm_instances"></a> [vm\_instances](#input\_vm\_instances) | Number of VM instances in scale set | <pre>object({<br/>    min     = number<br/>    max     = number<br/>    default = number<br/>  })</pre> | <pre>{<br/>  "default": 3,<br/>  "max": 10,<br/>  "min": 2<br/>}</pre> | no |
| <a name="input_vm_sku"></a> [vm\_sku](#input\_vm\_sku) | SKU for virtual machine scale set instances | `string` | `"Standard_B2ms"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_gateway_fqdn"></a> [app\_gateway\_fqdn](#output\_app\_gateway\_fqdn) | FQDN of the Application Gateway |
| <a name="output_app_gateway_public_ip"></a> [app\_gateway\_public\_ip](#output\_app\_gateway\_public\_ip) | Public IP of the Application Gateway |
| <a name="output_database_server_name"></a> [database\_server\_name](#output\_database\_server\_name) | Name of the PostgreSQL server |
| <a name="output_key_vault_uri"></a> [key\_vault\_uri](#output\_key\_vault\_uri) | URI of the Key Vault |
| <a name="output_monitoring_workspace_id"></a> [monitoring\_workspace\_id](#output\_monitoring\_workspace\_id) | ID of the Log Analytics workspace |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Name of the resource group |
| <a name="output_vpn_gateway_connections"></a> [vpn\_gateway\_connections](#output\_vpn\_gateway\_connections) | VPN Gateway connection details |
| <a name="output_vwan_firewall_ips"></a> [vwan\_firewall\_ips](#output\_vwan\_firewall\_ips) | Public IPs of Azure Firewalls in vWAN hubs |
| <a name="output_vwan_hub_ids"></a> [vwan\_hub\_ids](#output\_vwan\_hub\_ids) | IDs of the vWAN hubs |
| <a name="output_vwan_id"></a> [vwan\_id](#output\_vwan\_id) | ID of the Virtual WAN |
<!-- END_TF_DOCS -->