// Deploys the External Standard Load Balancer and associated public IP address

////////////////////////////////////////////////////////////////////////////////
// Required parameters
////////////////////////////////////////////////////////////////////////////////
param location string

////////////////////////////////////////////////////////////////////////////////
// Parameters with acceptable defaults
////////////////////////////////////////////////////////////////////////////////
param resourceNameFormat string = '{0}-syslogfwd-{1}'
@description('A value to indicate the deployment number.')
@minValue(0)
@maxValue(99)
param sequence int = 1

////////////////////////////////////////////////////////////////////////////////
// VARIABLES
////////////////////////////////////////////////////////////////////////////////

var sequenceFormatted = format('{0:00}', sequence)
var lbName = format(resourceNameFormat, 'lbe', sequenceFormatted)
var frontendName = 'syslog-external-frontend'
var backendName = 'syslogfwd-backend'

////////////////////////////////////////////////////////////////////////////////
// RESOURCES
////////////////////////////////////////////////////////////////////////////////

resource publicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: format(resourceNameFormat, 'pip', sequenceFormatted)
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
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
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendName
      }
    ]
    outboundRules: [
      {
        name: 'syslogfwd-out'
        properties: {
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, backendName)
          }
          protocol: 'All'
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, frontendName)
            }
          ]
        }
      }
    ]
  }
}

////////////////////////////////////////////////////////////////////////////////
// OUTPUTS
////////////////////////////////////////////////////////////////////////////////

output backendAddressPoolId string = loadBalancer.properties.backendAddressPools[0].id
output publicIP string = publicIP.properties.ipAddress
