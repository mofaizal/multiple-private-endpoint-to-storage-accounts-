# Define Resource Group
# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
  suffix  = ["pv"]
}

resource "azurerm_resource_group" "rg-vnet1" {
  name     = "rg-pv-vnet1"
  location = "southeastasia"
}

resource "azurerm_resource_group" "rg-vnet2" {
  name     = "rg-pv-vnet2"
  location = "southeastasia"
}

# Define Virtual Networks (vnet1 and vnet2)
resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg-vnet1.location
  resource_group_name = azurerm_resource_group.rg-vnet1.name
}

resource "azurerm_virtual_network" "vnet2" {
  name                = "vnet2"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg-vnet2.location
  resource_group_name = azurerm_resource_group.rg-vnet2.name
}

# Define Subnets for each VNet
resource "azurerm_subnet" "subnet_vnet1" {
  name                 = "subnet-vnet1"
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.1.0/24"]
  resource_group_name  = azurerm_resource_group.rg-vnet1.name
}

resource "azurerm_subnet" "subnet_vnet2" {
  name                 = "subnet-vnet2"
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.1.1.0/24"]
  resource_group_name  = azurerm_resource_group.rg-vnet2.name
}

# Define Private DNS Zones for each VNet
resource "azurerm_private_dns_zone" "dns_zone_vnet1" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg-vnet1.name
}

resource "azurerm_private_dns_zone" "dns_zone_vnet2" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg-vnet2.name
}

# Link DNS Zones to VNets
resource "azurerm_private_dns_zone_virtual_network_link" "vnet1_link" {
  name                  = "dns-zone-link-vnet1"
  resource_group_name   = azurerm_resource_group.rg-vnet1.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone_vnet1.name
  virtual_network_id    = azurerm_virtual_network.vnet1.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet2_link" {
  name                  = "dns-zone-link-vnet2"
  resource_group_name   = azurerm_resource_group.rg-vnet2.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone_vnet2.name
  virtual_network_id    = azurerm_virtual_network.vnet2.id
}

# Create Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = "multiplepvforblob21"
  resource_group_name      = azurerm_resource_group.rg-vnet1.name
  location                 = azurerm_resource_group.rg-vnet1.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create Private Endpoints for each VNet
resource "azurerm_private_endpoint" "private_endpoint_vnet1" {
  name                = "private-endpoint-vnet1"
  location            = azurerm_resource_group.rg-vnet1.location
  resource_group_name = azurerm_resource_group.rg-vnet1.name
  subnet_id           = azurerm_subnet.subnet_vnet1.id

  private_service_connection {
    name                           = "blob-connection-vnet1"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "private_endpoint_vnet2" {
  name                = "private-endpoint-vnet2"
  location            = azurerm_resource_group.rg-vnet2.location
  resource_group_name = azurerm_resource_group.rg-vnet2.name
  subnet_id           = azurerm_subnet.subnet_vnet2.id

  private_service_connection {
    name                           = "blob-connection-vnet2"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

# Create DNS A Records for each VNet in their respective DNS zones
resource "azurerm_private_dns_a_record" "dns_record_vnet1" {
  name                = azurerm_storage_account.storage.name
  zone_name           = azurerm_private_dns_zone.dns_zone_vnet1.name
  resource_group_name = azurerm_resource_group.rg-vnet1.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.private_endpoint_vnet1.private_service_connection[0].private_ip_address]
}

resource "azurerm_private_dns_a_record" "dns_record_vnet2" {
  name                = "multiplepvforblob21"
  zone_name           = azurerm_private_dns_zone.dns_zone_vnet2.name
  resource_group_name = azurerm_resource_group.rg-vnet2.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.private_endpoint_vnet2.private_service_connection[0].private_ip_address]
}

# Optional # 

# Creat bastion host to check the private endpoint
resource "azurerm_subnet" "bastion_vnet1" {
  address_prefixes     = ["10.0.2.0/24"] # Adjust the IP address prefix as needed
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg-vnet1.name
  virtual_network_name = azurerm_virtual_network.vnet1.name

}

# Required for Frontend Private IP endpoint testing 
resource "azurerm_subnet" "private_ip_test_vnet1" {
  address_prefixes     = ["10.0.3.0/24"]
  name                 = "private_ip_test_vnet1"
  resource_group_name  = azurerm_resource_group.rg-vnet1.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
}

resource "azurerm_subnet" "bastion_vnet2" {
  address_prefixes     = ["10.1.2.0/24"] # Adjust the IP address prefix as needed
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg-vnet2.name
  virtual_network_name = azurerm_virtual_network.vnet2.name

}

# Required for Frontend Private IP endpoint testing 
resource "azurerm_subnet" "private_ip_test_vnet2" {
  address_prefixes     = ["10.1.3.0/24"]
  name                 = "private_ip_test_vnet2"
  resource_group_name  = azurerm_resource_group.rg-vnet2.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
}


#-----------------------------------------------------------------
#  Enable these to deeploy sample application to VMSS 
#  Enable these code to test private IP endpoint via bastion host  
#-----------------------------------------------------------------

resource "azurerm_windows_virtual_machine" "bastion_vnet1" {
  admin_password        = "YourPasswordHere123!" # Replace with your actual password
  admin_username        = "adminuser"
  location              = azurerm_resource_group.rg-vnet1.location
  name                  = module.naming.windows_virtual_machine.name_unique
  network_interface_ids = [azurerm_network_interface.bastion_win_vm_nic.id]
  resource_group_name   = azurerm_resource_group.rg-vnet1.name
  size                  = "Standard_DS1_v2"

  os_disk {
    # name              = "bastion-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "Windows-11"
    publisher = "MicrosoftWindowsDesktop"
    sku       = "win11-22h2-pro"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "bastion_win_vm_nic" {
  location            = azurerm_resource_group.rg-vnet1.location
  name                = module.naming.network_interface.name_unique
  resource_group_name = azurerm_resource_group.rg-vnet1.name

  ip_configuration {
    name                          = module.naming.network_interface.name_unique
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.private_ip_test_vnet1.id
  }
}

resource "azurerm_public_ip" "bastion_public_ip" {
  allocation_method   = "Static" # You can choose Dynamic if preferred
  location            = azurerm_resource_group.rg-vnet1.location
  name                = module.naming.public_ip.name_unique
  resource_group_name = azurerm_resource_group.rg-vnet1.name
  sku                 = "Standard"
}

# Create Azure Bastion Host
resource "azurerm_bastion_host" "bastion_host" {
  location            = azurerm_resource_group.rg-vnet1.location
  name                = module.naming.bastion_host.name_unique
  resource_group_name = azurerm_resource_group.rg-vnet1.name
  scale_units         = 2

  ip_configuration {
    name                 = "bastion-Ip-configuration"
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
    subnet_id            = azurerm_subnet.bastion_vnet1.id
  }
}


#-----------------------------------------------------------------
#  Enable these to deeploy sample application to VMSS 
#  Enable these code to test private IP endpoint via bastion host  
#-----------------------------------------------------------------

resource "azurerm_windows_virtual_machine" "bastion_vnet2" {
  admin_password        = "YourPasswordHere123!" # Replace with your actual password
  admin_username        = "adminuser"
  location              = azurerm_resource_group.rg-vnet2.location
  name                  = "vnet2-win-vm"
  network_interface_ids = [azurerm_network_interface.bastion_win_vm_nic_vnet2.id]
  resource_group_name   = azurerm_resource_group.rg-vnet2.name
  size                  = "Standard_DS1_v2"

  os_disk {
    # name              = "bastion-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "Windows-11"
    publisher = "MicrosoftWindowsDesktop"
    sku       = "win11-22h2-pro"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "bastion_win_vm_nic_vnet2" {
  location            = azurerm_resource_group.rg-vnet2.location
  name                = "bastion-win-vm-nic-vnet2"
  resource_group_name = azurerm_resource_group.rg-vnet2.name

  ip_configuration {
    name                          = "bastion-win-vm-nic-ip-vnet2"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.private_ip_test_vnet2.id
  }
}

resource "azurerm_public_ip" "bastion_public_ip_vnet2" {
  allocation_method   = "Static" # You can choose Dynamic if preferred
  location            = azurerm_resource_group.rg-vnet2.location
  name                = "bastion-public-ip-vnet2"
  resource_group_name = azurerm_resource_group.rg-vnet2.name
  sku                 = "Standard"
}

# Create Azure Bastion Host
resource "azurerm_bastion_host" "bastion_host_vnet2" {
  location            = azurerm_resource_group.rg-vnet2.location
  name                = "vnet2-bastion-host"
  resource_group_name = azurerm_resource_group.rg-vnet2.name
  scale_units         = 2

  ip_configuration {
    name                 = "bastion-Ip-configuration"
    public_ip_address_id = azurerm_public_ip.bastion_public_ip_vnet2.id
    subnet_id            = azurerm_subnet.bastion_vnet2.id
  }
}
