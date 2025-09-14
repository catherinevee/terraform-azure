# Public IP for Application Gateway
resource "azurerm_public_ip" "app_gateway" {
  name                = "pip-${var.name_prefix}-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                = "Standard"
  domain_name_label  = "${var.name_prefix}-app"
  tags               = var.tags
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = "agw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags               = var.tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.gateway_subnet_id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  backend_address_pool {
    name = "backend-pool"
  }

  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity = "Enabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name           = "health-probe"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name            = "http-port"
    protocol                      = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "backend-http-settings"
  }

  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }

  autoscale_configuration {
    min_capacity = 2
    max_capacity = 10
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
}

# Virtual Machine Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "app" {
  name                = "vmss-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                = var.vm_sku
  instances          = var.vm_instances.default
  admin_username     = "azureuser"
  tags               = var.tags

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                         = "ipconfig"
      primary                                      = true
      subnet_id                                    = var.subnet_id
      application_gateway_backend_address_pool_ids = [azurerm_application_gateway.main.backend_address_pool[0].id]
    }
  }

  boot_diagnostics {
    storage_account_uri = null
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    db_connection_string_secret_id = var.database_connection_string
    key_vault_uri                  = var.key_vault_uri
  }))
}

# SSH Key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store SSH private key in Key Vault
resource "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "vmss-ssh-private-key"
  value        = tls_private_key.ssh.private_key_pem
  key_vault_id = var.key_vault_id
}

# Autoscale settings
resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "autoscale-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.app.id

  profile {
    name = "default"

    capacity {
      default = var.vm_instances.default
      minimum = var.vm_instances.min
      maximum = var.vm_instances.max
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
        time_window        = "PT5M"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
        time_window        = "PT5M"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}