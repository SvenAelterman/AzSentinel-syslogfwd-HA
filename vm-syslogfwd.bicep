// Builds the pair of Linux VMs with the selected OS

////////////////////////////////////////////////////////////////////////////////
// Required parameters
////////////////////////////////////////////////////////////////////////////////
param location string

@description('Name of the Azure virtual network where the virtual machines needs to be deployed.')
param virtualNetworkName string

@description('The name of the Resource Group containing the Virtual Network.')
param virtualNetworkResourceGroup string

@description('Name of the virtual network subnet where the virtual machines should be created.')
param subnetName string

@description('The Azure resource ID of the backend pool of the internal load balancer.')
param lbiBackendAddressPoolId string

@description('The Azure resource ID of the backend pool of the external load balancer.')
param lbeBackendAddressPoolId string

@description('The GUID of the workspace where the syslog forwarders will forward to.')
param workspaceId string

@description('An access key for the log analytics workspace.')
@secure()
param workspaceKey string

@description('The password for the local user account.')
@secure()
param adminPasswordOrKey string

param avsetId string = ''

////////////////////////////////////////////////////////////////////////////////
// Parameters with acceptable defaults
////////////////////////////////////////////////////////////////////////////////
@description('A value to indicate the deployment number.')
@minValue(0)
@maxValue(99)
param sequence int = 1

param adminUserName string = 'azureuser'
param vmSize string = 'Standard_D4s_v4'
param osDiskSize int = 256

@allowed([
  'ssh'
  'password'
])
param authenticationType string = 'password'
@description('The image reference and name of the OS configuration script.')
param osDetail object = {
  imageReference: {
    publisher: 'canonical'
    offer: '0001-com-ubuntu-server-focal'
    sku: '20_04-lts'
    version: 'latest'
  }
  configScriptName: 'ubuntu.sh'
}

@description('Format string of the resource names.')
param resourceNameFormat string = '{0}-syslogfwd-{1}'
@description('The URL of the configuration scripts.')
param scriptsLocation string
param scriptsLocationAccessToken string = ''

////////////////////////////////////////////////////////////////////////////////
// VARIABLES
////////////////////////////////////////////////////////////////////////////////

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

// Create a NIC for the new VM, attached to the existing subnet,
// and optionally associated with the backend pool of the internal and external load balancers
resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: format(resourceNameFormat, 'nic', sequenceFormatted)
  location: location
  properties: {
    enableAcceleratedNetworking: true
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
    // Associate the VM with an availability set, if specified
    availabilitySet: empty(avsetId) ? json('null') : {
      id: avsetId
    }
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

////////////////////////////////////////////////////////////////////////////////
// OUTPUTS
////////////////////////////////////////////////////////////////////////////////

output scriptUrlUsed string = setUpCEFScript
output vmIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
