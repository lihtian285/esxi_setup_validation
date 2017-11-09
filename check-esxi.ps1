#patch 1 #
###author : lihtian@gmail.com###
###check-esxi.ps1###
###Created date : 28 July 2017###
###Version 1.0###
### Capture only Empty Cluster as error output in error log
### Store validation output in a log file
###Check the following items:
###Item to check :
###1.	ESXi hostname
###2.	ESXi build number
###3.	ESXi Cluster and HA status
###4.	ESXi NTP setup
###5.	ESXi Syslog setup
###6.	ESXi Domain setup
###7.	ESXi vDS network
###8.	ESXi Permission (Current script custom made to get Nucleus Least privileges permission only)
###9.	ESXi Datastore
###10.	ESXi cluster HA Heartbeat datastore (Nucleus specific only)
### How to execute it? 

####   >./check-esxi.ps1
#### File required : ESXi_host.csv
$currentpath = (get-item -path ".\" -Verbose).fullname
$logtime = Get-date -format "MM-dd-yyyy_hh-mm-ss"
$outputfile = "check_esxi_$logtime.csv"
$errorlogfile ="check_esxi_error_log_$logtime.log"


Function Connect-vCenter
{

		if ($defaultVIServer.count -gt 0){

		Disconnect-VIServer -server $defaultVIServer -Confirm:$false
		$vcenter = Read-host 'Enter Vcenter name: '
		$passwd = Get-Credential
		Connect-VIServer -server $vcenter -Credential $passwd
		}


		Else{

		$vcenter = Read-host 'Enter Vcenter name: '
		$passwd = Get-Credential
		Connect-VIServer -server $vcenter -Credential $passwd

		}
}

###Reading input from csv file
$esxifile = $currentpath+"\ESXi_host.csv"
$csvData = import-CSV $esxifile

###call connect-vCenter function
Connect-vCenter

Write-host -foregroundcolor green "Reading data......"

Foreach ($entry in $csvData){

#Reading csv file column 1 only
$esxihostname = $entry.esxiHostName
[String]$esxifullhostname = $esxihostname+".mgt.dbn.hpe.com"

###################################Variables###################################
$vmhost = get-vmhost -name $esxifullhostname
#Get syslog IP
$datacenter = get-datacenter | select-object -expandproperty name
$4char = $datacenter.substring(0,4)
$syslogserver = "yoursyslogserver"
$syslogip = (nslookup $syslogserver | select-string Address | where-object LineNumber -eq 5).tostring().split(' ')[-1]

#Getting vmhost ID for get-view purpose
$vmhostid = $vmhost.id
$getvmhostview = get-view $vmhostid	#Store a get-view result
$vmhostcluster = get-view $getvmhostview.Parent | select-object -expandproperty name

#Draw a line and space
$drawline = "=============================================================================================================================================="
$drawpace = ""
###################################Variables###################################


################################
#  Add item under this section #
################################
###################################Item to be validate###################################

#select-object with parameter "-expandproperty" will return only Value
$vmhostbuildnumber = get-vmhost -name $vmhost | select-object -expandproperty Build
$vmhostntp = get-vmhostntpserver -vmhost $vmhost | out-string
$vmhostds = get-datastore -vmhost $vmhost
$vmhostsyslogip = get-vmhostsyslogserver -vmhost $vmhost | select-object -expandproperty host
$vmhostsyslogds = get-advancedsetting -entity(get-vmhost -name $vmhost) -name syslog.global.logdir | select-object -expandproperty value
$vmhostdomain = get-vmhostauthentication -vmhost $vmhost | select-object -expandproperty Domain
$vmhostnw = get-view $getvmhostview.network | select name | where-object {$_.name -like "D*"} | select-object -expandproperty name
$vmhostleastpriv = get-vipermission -entity ($vmhost) | select Role, Principal | where-object {$_.Principal -like "*-A"}

#Check if Cluster value is null
if($vmhostcluster -ne $null)
			{
				$vmhostclusterraw = get-cluster -name $vmhostcluster
				$vmhostHAstatus = get-cluster -name $vmhostcluster | get-vmhost -name $vmhost | select Name, @{N='State';E={$_.ExtensionData.Runtime.DasHostState.state}} | select-object -expandproperty State
                #Get HA heartbeat datastore ID
				$heartbeatds = $vmhostclusterraw.ExtensionData.Configuration.DasConfig.HeartbeatDatastore.value | ForEach-Object { $id = $_ -replace "datastore-"; $vmhostds | where {$_.id -replace "datastore-" -match $id } | foreach{$_.Name} } #Foreach can also replace by symbol "%"

			}
Else
			{
				Write-output "$vmhost has not join Cluster" | out-file -append $errorlogfile
				Write-host -foregroundcolor yellow "Error log $errorlogfile"
			}


###################################Item to be validate###################################



###################################Creating report###################################
$report = @()
$report += $drawline
$report += "ESXi name ="
$report += $vmhost | select-object -expandproperty name
$report += $drawpace
$report += "ESXi Build Number ="
$report += $vmhostbuildnumber
$report += $drawpace
$report += "Cluster ="
$report += $vmhostcluster
$report += "HA status ="
$report += $vmhostHAstatus
$report += $drawpace
$report += "ESXi NTP Setup ="
$report += $vmhostntp
$report += "Desire syslog IP ="
$report += $syslogip
$report += "Current ESXi syslog setup = "
$report += $vmhostsyslogip
$report += $vmhostsyslogds
$report += $drawpace
$report += "ESXi Domain setup ="
$report += $vmhostdomain
$report += $drawpace
$report += "ESXi Network ="
$report += $vmhostnw
$report += $drawpace
$report += "Least Privileges ="
$report += $vmhostleastpriv | format-table -autosize
#No need to draw a space, the object will return two newline
$report += "ESXi Datastore ="
$report += $vmhostds | select Name, CapacityGB | format-table -autosize
#No need to draw a space, the object will return two newline
$report += "Cluster Heartbeat datastore ="
$report += $heartbeatds
$report += $drawline
$report += $drawpace
$report >> $outputfile
###################################Creating report###################################

}
Write-host -foregroundcolor green "Output file name : $outputfile"

#END#
