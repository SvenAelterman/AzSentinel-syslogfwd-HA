// Deploys the Internal Standard Load Balancer

param location string
//param backendIpAddresses array

param virtualNetworkName string
param virtualNetworkResourceGroup string
param subnetName string

param resourceNameFormat string = '{0}-syslogfwd-{1}'
@description('A value to indicate the deployment number.')
@minValue(0)
@maxValue(99)
param sequence int = 1

var sequenceFormatted = format('{0:00}', sequence)
var lbName = format(resourceNameFormat, 'lbi', sequenceFormatted)
var frontendName = 'syslog-internal-frontend'
var backendName = 'syslogfwd-backend'

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

output backendAddressPoolId string = loadBalancer.properties.backendAddressPools[0].id
output frontendIP string = loadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress
