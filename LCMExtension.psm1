#Requires -Modules PSRabbitMQ

$script:LCMData = [PSCustomObject]@{
  'Name' = 'LCMExtensionSample'
  'Version' = [version]'0.0.1.2'
  'MaintenanceWindow' = [PSCustomObject]@{
                            'WindowStart' = {[datetime]'19:00:00'}
                            'WindowEnd' = {([datetime]'6:00:00').AddDays(1)}
                         }
}


Register-EngineEvent -SourceIdentifier LCMStartSet -Action { if(Test-WithinMaintenanceWindow) { New-Event -SourceIdentifier AllowDSCSet } }
#This allows the DSC resource SET function/method to have a Get-Event or Wait-EngineEvent -SourceIdentifier AllowDSCSet -Timeout x
function Test-WithinMaintenanceWindow {
 [cmdletBinding()]
 [outputType([bool])]
 param(
  [datetime]
  $time = (Get-Date)
 )

 if($time -ge (& $script:LCMData.MaintenanceWindow.WindowStart) -and $time -le (& $script:LCMData.MaintenanceWindow.WindowEnd) ) {
  Return $true
 }
 else {
  Return $false
 }

}


Register-EngineEvent -SourceIdentifier LCMStartTest -Action { Push-MQMessage -resource $event.MessageData.resource -ConfigurationID $event.MessageData.ConfigurationID }
#This could allow Realtime Asynchronous notifications to other systems
function Push-MQMessage{
 [cmdletBinding()]
 Param(
  $resource,
  $ConfigurationID
  
 )
 $RabbitMQMsgParams = @{
  'Exchange' = 'myDSCTopicExchange'
  'Key' = "$ConfigurationID.$resource"
  'InputObject' = ([PSCustomObject]@{
                       'EventTime'= (Get-Date -Format 'yyyy.MM.dd hh:mm:ss.fff')
                       'ComputerName'=$env:COMPUTERNAME
                       'LCMData'=$script:LCMData
                    } | ConvertTo-Json -Depth ([int]::MaxValue)
  )
 }
 Send-RabbitMqMessage @RabbitMQMsgParams
 
}

