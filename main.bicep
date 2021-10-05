targetScope = 'subscription'

// Required parameters
param location string
param virtualNetworkName string
@description('Name of the virtual network subnet where the load balancers should be created. If not specified, will use the same subnet as the virtual machines.')
param lbSubnetName string = ''
@description('Name of the virtual network subnet where the virtual machines should be created.')
param vmSubnetName string

@description('The name of the Resource Group containing the Virtual Network.')
param vnetResourceGroup string

@description('Name of the Resource Group where the existing Log Analyics/Sentinel workspace resides.')
param workspaceResourceGroup string

@description('Name of the existing Log Analytics/Sentinel workspace.')
param workspaceName string

@secure()
param adminPassword string

////////////////////////////////////////////////////////////////////////////////
// Parameters with acceptable defaults
////////////////////////////////////////////////////////////////////////////////
param environment string = 'prod'
@description('Tags that will be added to the resource group.')
param tags object = {}

@description('A value to indicate the deployment number.')
@minValue(0)
@maxValue(99)
param sequence int = 1
@minValue(1)
@maxValue(4)
param vmCount int = 2

@description('The Linux distribution to use for the virtual machines.')
@allowed([
  'Ubuntu'
  'RHEL'
])
param os string = 'Ubuntu'
param vmSize string = 'Standard_D4s_v4'
param osDiskSize int = 256
param scriptsLocation string = 'https://raw.githubusercontent.com/SvenAelterman/AzSentinel-syslogfwd-HA/main/scripts/'
param deploymentTime string = utcNow()
param deploymentNamePrefix string = 'syslogfwd-HA-'
// Default naming convention from the Microsoft Cloud Adoption Framework
// See https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming
// {0} is a placeholder for the resource type abbreviation (e.g., "lbi")
// See https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations 
param resourceNameFormat string = '{0}-syslogfwd-${environment}-${location}-{1}'

////////////////////////////////////////////////////////////////////////////////
// VARIABLES
////////////////////////////////////////////////////////////////////////////////

var sequenceFormatted = format('{0:00}', sequence)

var osDetails = {
  Ubuntu: {
    imageReference: {
      publisher: 'canonical'
      offer: '0001-com-ubuntu-server-focal'
      sku: '20_04-lts'
      version: 'latest'
    }
    configScriptName: 'ubuntu.sh'
  }
  RHEL: {
    imageReference: {
      publisher: 'RedHat'
      offer: 'RHEL'
      sku: ''
      version: 'latest'
    }
    configScriptName: 'redhat.sh'
  }
}

var workspaceId = reference(logAnalytics.id, '2015-11-01-preview').customerId
var workspaceKey = listKeys(logAnalytics.id, '2015-11-01-preview').primarySharedKey

////////////////////////////////////////////////////////////////////////////////
// RESOURCES
////////////////////////////////////////////////////////////////////////////////

// For verification that it exists only
resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup(vnetResourceGroup)
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: workspaceName
  scope: resourceGroup(workspaceResourceGroup)
}

// Create resource group
resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: format(resourceNameFormat, 'rg', sequenceFormatted)
  location: location
  tags: tags
}

// Create an internal load balancer if more than 1 VM is to be created
module loadBalancerInternal 'lbi.bicep' = if (vmCount > 1) {
  name: '${deploymentNamePrefix}lbi-${deploymentTime}'
  scope: targetResourceGroup
  params: {
    location: location
    subnetName: empty(lbSubnetName) ? vmSubnetName : lbSubnetName
    resourceNameFormat: resourceNameFormat
    sequence: sequence
    virtualNetworkName: virtualNetworkName
    virtualNetworkResourceGroup: vnetResourceGroup
  }
}

// Create an external load balancer if more than 1 VM is to be created
module loadBalancerExternal 'lbe.bicep' = if (vmCount > 1) {
  name: '${deploymentNamePrefix}lbe-${deploymentTime}'
  scope: targetResourceGroup
  params: {
    location: location
    resourceNameFormat: resourceNameFormat
    sequence: sequence
  }
}

// Call VM module
module vm 'vm-syslogfwd.bicep' = [for i in range(sequence, vmCount): {
  name: '${deploymentNamePrefix}vm-${i}-${deploymentTime}'
  scope: targetResourceGroup
  params: {
    osDetail: osDetails[os]
    virtualNetworkName: virtualNetworkName
    virtualNetworkResourceGroup: vnetResourceGroup
    subnetName: vmSubnetName
    osDiskSize: osDiskSize
    sequence: i
    adminPasswordOrKey: adminPassword
    resourceNameFormat: resourceNameFormat
    location: location
    vmSize: vmSize
    workspaceId: workspaceId
    workspaceKey: workspaceKey
    scriptsLocation: scriptsLocation
    lbiBackendAddressPoolId: vmCount > 1 ? loadBalancerInternal.outputs.backendAddressPoolId : ''
    lbeBackendAddressPoolId: vmCount > 1 ? loadBalancerExternal.outputs.backendAddressPoolId : ''
  }
}]

// LATER: VM Backup!

output configScriptUrlUsed string = vm[0].outputs.scriptUrlUsed
output virtualMachineIPs array = [for i in range(0, vmCount): vm[i].outputs.vmIP]
output lbiIP string = vmCount > 1 ? loadBalancerInternal.outputs.frontendIP : 'N/A'
output publicIP string = vmCount > 1 ? loadBalancerExternal.outputs.publicIP : 'N/A'
