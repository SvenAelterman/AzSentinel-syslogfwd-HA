// Builds the pair of Linux VMs with the selected OS

@description('A value to indicate the deployment number.')
@minValue(0)
@maxValue(99)
param sequence int = 1
param location string

param virtualNetworkName string
param virtualNetworkResourceGroup string
param subnetName string
param lbiBackendAddressPoolId string
param lbeBackendAddressPoolId string

param workspaceId string
@secure()
param workspaceKey string

@secure()
param adminPasswordOrKey string

param adminUserName string = 'azureuser'
param vmSize string = 'Standard_D4s_v4'
param osDiskSize int = 128
param authenticationType string = 'password'
param osDetail object = {
  // TODO: Copy Ubuntu osDetail values here for default
}

param resourceNameFormat string = '{0}-syslogfwd-{1}'
param scriptsLocation string
param scriptsLocationAccessToken string = ''

// The Linux SSH configuration, which is used if authenticationType == ssh
var linuxSshConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUserName}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

var sequenceFormatted = format('{0:00}', sequence)
var setUpCEFScript = uri('${scriptsLocation}${osDetail.configScriptName}', '${scriptsLocationAccessToken}')

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup(virtualNetworkResourceGroup)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: '${vnet.name}/${subnetName}'
  scope: resourceGroup(virtualNetworkResourceGroup)
}

// LATER: Availability set

// Create a NIC for the new VM, attached to the existing subnet
resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: format(resourceNameFormat, 'nic', sequenceFormatted)
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
          // If a backend address pool ID for an internal load balancer is specified,
          // use it and the external load balancer address pool ID
          loadBalancerBackendAddressPools: empty(lbiBackendAddressPoolId) ? json('null') : [
            {
              id: lbiBackendAddressPoolId
            }
            {
              id: lbeBackendAddressPoolId
            }
          ]
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: format(resourceNameFormat, 'vm', sequenceFormatted)
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: osDetail.imageReference
      osDisk: {
        name: format(resourceNameFormat, 'osdisk', sequenceFormatted)
        osType: 'Linux'
        diskSizeGB: osDiskSize
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: format('vm-syslogfwd-{0}', sequenceFormatted)
      adminUsername: adminUserName
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxSshConfiguration)
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// TODO: Add AAD login?

resource configScript 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: '${vm.name}/CEF-syslog-ConfigScript'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    protectedSettings: {
      // LATER: Support for Azure Government
      commandToExecute: 'bash ${osDetail.configScriptName} -w ${workspaceId} -k ${workspaceKey}'
      fileUris: [
        setUpCEFScript
      ]
    }
  }
}

output scriptUrlUsed string = setUpCEFScript
output vmIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
