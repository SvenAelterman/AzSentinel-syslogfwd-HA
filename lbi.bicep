// Deploys the Internal Standard Load Balancer

////////////////////////////////////////////////////////////////////////////////
// Required parameters
////////////////////////////////////////////////////////////////////////////////
param location string

@description('Name of the Azure virtual network where the load balancer needs to be deployed.')
param virtualNetworkName string
@description('Name of the resource group where the virtual network is created.')
param virtualNetworkResourceGroup string
@description('Name of the subnet in the virtual network where the load balancer needs to be deployed.')
param subnetName string

////////////////////////////////////////////////////////////////////////////////
// Parameters with acceptable defaults
////////////////////////////////////////////////////////////////////////////////
@description('Format string of the resource names.')
param resourceNameFormat string = '{0}-syslogfwd-{1}'

@description('A value to indicate the deployment number.')
@minValue(0)
@maxValue(99)
param sequence int = 1

////////////////////////////////////////////////////////////////////////////////
// VARIABLES
////////////////////////////////////////////////////////////////////////////////

var sequenceFormatted = format('{0:00}', sequence)
var lbName = format(resourceNameFormat, 'lbi', sequenceFormatted)
var frontendName = 'syslog-internal-frontend'
var backendName = 'syslogfwd-backend'

////////////////////////////////////////////////////////////////////////////////
// RESOURCES
////////////////////////////////////////////////////////////////////////////////

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup(virtualNetworkResourceGroup)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: '${vnet.name}/${subnetName}'
  scope: resourceGroup(virtualNetworkResourceGroup)
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-02-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: frontendName
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendName
      }
    ]
    loadBalancingRules: [
      {
        name: 'syslog-rule-tcp'
        properties: {
          protocol: 'Tcp'
          frontendPort: 514
          backendPort: 514
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, frontendName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, backendName)
          }
          enableFloatingIP: false
          enableTcpReset: true
        }
      }
      {
        name: 'syslog-rule-udp'
        properties: {
          protocol: 'Udp'
          frontendPort: 514
          backendPort: 514
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, frontendName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, backendName)
          }
          enableFloatingIP: false
          enableTcpReset: true
        }
      }
    ]
  }
}

////////////////////////////////////////////////////////////////////////////////
// OUTPUTS
////////////////////////////////////////////////////////////////////////////////

output backendAddressPoolId string = loadBalancer.properties.backendAddressPools[0].id
output frontendIP string = loadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress
