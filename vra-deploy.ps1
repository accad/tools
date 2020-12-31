##
## Script to deploy one or several instances from VRA
## 
## Nick Accad 
## <naccad@gmail.com>
## 2019
##
## Parameters
## server: VRA server name
## username: your username, user@domain.dqdn.com
## vmlist: comman separated list of VM names
## reasons: free form, could be the RITM# or some information about the request
## vfolder: the folder in VC
## blueprint: name of the blueprint in VRA
##
## Inital release
## Features that will be added later
## - CPU and memory size
## - Adding additional disks
##

param(
	[string]$server,
	[string]$username,
	[string[]]$vmlist,
	[string]$reasons,
	[string]$vfolder,
	[string]$blueprint,
	[string]$cpu,
	[string]$memory,
	[bool]$wait=$true
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

connect-vraserver -server $server -username $username
$rawjson = Get-vRACatalogItemRequestTemplate -name $blueprint	
$psdata = convertfrom-json $rawjson

foreach ($vmname in $vmlist) {
  $psdata.description = $vmname
  $psdata.reasons = $reasons
  $psdata.data.vSphere_Machine_1.data.hostname = $vmname
  $psdata.data.vSphere_Machine_1.data.cpu = $cpu
  $psdata.data.vSphere_Machine_1.data.memory = $memory
  $psdata.data.vSphere_Machine_1.data.'VMware.VirtualCenter.Folder' = $vfolder
  $jdata = convertto-json -depth 10 $psdata
  $vmname

  if ( $wait -eq $true ) {
    Request-vRACatalogItem -JSON $jdata -confirm:$false -Wait
  }
  else { 
    Request-vRACatalogItem -JSON $jdata -confirm:$false 
  }  
  
}
