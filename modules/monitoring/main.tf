# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Action Group for alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  short_name          = "alerts"
  tags                = var.tags

  email_receiver {
    name          = "admin"
    email_address = var.admin_email
  }
}

# CPU Alert for VMSS
resource "azurerm_monitor_metric_alert" "vmss_cpu" {
  name                = "alert-${var.name_prefix}-vmss-cpu"
  resource_group_name = var.resource_group_name
  scopes              = [var.vmss_id]
  description         = "Alert when CPU exceeds 90%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Database Alert
resource "azurerm_monitor_metric_alert" "database_cpu" {
  name                = "alert-${var.name_prefix}-db-cpu"
  resource_group_name = var.resource_group_name
  scopes              = [var.database_id]
  description         = "Alert when database CPU exceeds 80%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Application Gateway Alert
resource "azurerm_monitor_metric_alert" "app_gateway_unhealthy" {
  name                = "alert-${var.name_prefix}-agw-unhealthy"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_gateway_id]
  description         = "Alert when backend hosts are unhealthy"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# vWAN Hub Health Alert
resource "azurerm_monitor_metric_alert" "vwan_hub_health" {
  for_each            = toset(var.vwan_hub_ids)
  name                = "alert-${var.name_prefix}-vwan-hub-${substr(each.key, -8, -1)}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert for vWAN hub health issues"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/virtualHubs"
    metric_name      = "VirtualHubHealthStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# VPN Gateway Connection Alert
resource "azurerm_monitor_metric_alert" "vpn_connection" {
  count               = var.vpn_gateway_id != null ? 1 : 0
  name                = "alert-${var.name_prefix}-vpn-connection"
  resource_group_name = var.resource_group_name
  scopes              = [var.vpn_gateway_id]
  description         = "Alert when VPN connections drop"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/vpnGateways"
    metric_name      = "TunnelConnectionStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Diagnostic Settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "app_gateway" {
  name                       = "diag-${var.name_prefix}-agw"
  target_resource_id         = var.app_gateway_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for vWAN
resource "azurerm_monitor_diagnostic_setting" "vwan" {
  name                       = "diag-${var.name_prefix}-vwan"
  target_resource_id         = var.vwan_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "RouteTables"
  }

  metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for vWAN Hubs
resource "azurerm_monitor_diagnostic_setting" "vwan_hubs" {
  for_each                   = toset(var.vwan_hub_ids)
  name                       = "diag-${var.name_prefix}-hub-${substr(each.key, -8, -1)}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "RouteTables"
  }

  enabled_log {
    category = "BGPLogs"
  }

  metric {
    category = "AllMetrics"
  }
}