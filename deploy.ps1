# PowerShell script to deploy the template with generic parameter values
[string]$Location = "eastus"
[string]$Environment = "test"

[securestring]$VmPassword = (Get-Credential -UserName 'azureuser' -Message "Enter the password for the local VM user account.").Password

$TemplateParameters = @{
	location                    = $Location
	environment                 = $Environment
	virtualNetworkName          = "vnet-syslogfwd-demo-eastus-01"
	virtualNetworkResourceGroup = "rg-syslogfwd-demo-eastus-01"
	lbSubNetName                = 'loadbalancer'
	vmSubNetName                = 'default'
	# Reference to the existing Sentinel workspace
	workspaceResourceGroup      = 'rg-sentinel_ip2geo-demo-eastus-01'
	workspaceName               = 'sentinel-ip2geo-demo-eastus-01'
	sequence                    = 2
	vmCount                     = 3
	os                          = 'RHEL'
	# If using 'ssh', send the public key in base64 format instead
	adminPassword               = $VmPassword
	# Choose between 'password' or 'ssh'
	authenticationType          = 'password'
	tags                        = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'short'
	}
}

New-AzDeployment -Location $Location -Name "syslogfwd-HA-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile .\main.bicep -TemplateParameterObject $TemplateParameters