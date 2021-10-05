# PowerShell script to deploy the template with generic parameter values
[string]$Location = "eastus"
[string]$Environment = "test"

[securestring]$VmPassword = (Get-Credential -UserName 'azureuser').Password

$TemplateParameters = @{
	location               = $Location
	environment            = $Environment
	virtualNetworkName     = "vnet-syslogfwd-demo-eastus-01"
	vnetResourceGroup      = "rg-syslogfwd-demo-eastus-01"
	lbSubNetName           = 'loadbalancer'
	vmSubNetName           = 'default'
	# Reference to the existing Sentinel workspace
	workspaceResourceGroup = 'rg-sentinel_ip2geo-demo-eastus-01'
	workspaceName          = 'sentinel-ip2geo-demo-eastus-01'
	sequence               = 5
	vmCount                = 2
	adminPassword          = $VmPassword
	tags                   = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'short'
	}
}

New-AzDeployment -Location $Location -Name "syslogfwd-HA-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile .\main.bicep -TemplateParameterObject $TemplateParameters