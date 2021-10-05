# High-Availability Deployment of Azure Sentinel Syslog/Common Event Format (CEF) Forwarder

Azure ARM (bicep) template for deploying a high availability syslog/CEF forwarder setup using Azure VMs.

## Prereqs

- An existing Virtual Network with
  - an existing subnet for the internal load balancer
  - an existing subnet for the VMs
  
  If desired, both subnets can be the same.
  This existing Virtual Network must be in the same region as specified in the `location` parameter.

- An existing Log Analytics workspace

## Parameters

For an example on specifying many parameter values, check deploy.ps1.

The following parameters must be specified:

- location
- virtualNetworkName
- vnetResourceGroup
- lbSubnetName
- vmSubnetName
- workspaceResourceGroup
- workspaceName

The following parameters have default values that you can override if desired:

- resourceNameFormat = '{0}-syslogfwd-${environment}-${location}-{1}'

  This format follows the Microsoft Cloud Adoption Framework suggested naming convention.
  If you customize the format, specify `{0}` for the abbrevation of the resource type and `{1}` for the sequence value.

- environment = 'prod'
- sequence = 1

  This value will be used as the resource name suffix, e.g., "01", "02", etc.

- tags = {}
- vmCount = 2
- scriptsLocation = 'https://raw.githubusercontent.com/SvenAelterman/AzSentinel-syslogfwd-HA/main/scripts/'
- deploymentTime = utcNow()
- deploymentNamePrefix = 'syslogfwd-HA-'
- os = 'Ubuntu'
  
  This script has only been tested on Ubuntu and RHEL. It might work on other Linux distributions, but you will need to modify the `osDetails` variable to specify the necessary distribution attributes.
  At this time, custom images are not supported.

- vmSize = 'Standard_D4s_v4'

  Following guidelines, the default size has 4 cores. For smaller environments or for test deployments, you can reduce the size. You should specify a size that supports accelerated networking.

## Azure Resources

The following Azure resources will be created or updated when the deployment is successful:

- A Resource Group
- {vmCount} Azure Virtual Machines of the specified size using the specified Linux distribution
- If {vmCount} > 1, two standard Load Balancers
  - Internal load balancer forwarding TCP/UPD 514 to the virtual machines
  - External load balancer with outbound rules for the virtual machines

## Credits

The VM deployment is based on a template from Rogier Dijkman, @SecureHats. See https://github.com/SecureHats/Sentinel-playground/tree/main/ARM-Templates/logforwarder.

The load balancer templates are based on https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.compute/2-vms-internal-load-balancer.