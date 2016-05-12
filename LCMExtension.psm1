#Requires -Modules PSRabbitMQ

#By defining variable in Global scope, the variable should be accessible 
# directly from within the Resources Get/Set/Tests functions/methods
$Global:LCMData = [PSCustomObject]@{
  'Name' = 'LCMExtensionSample'
  'Version' = [version]'0.0.1.2'
  'MaintenanceWindow' = [PSCustomObject]@{
                            'WindowStart' = {[datetime]'19:00:00'}
                            'WindowEnd' = {([datetime]'6:00:00').AddDays(1)}
                         }
}

#assuming LCMStartSet is the Event triggered when the LCM enters a resource's Set method 
Register-EngineEvent -SourceIdentifier LCMStartSet -Action { 
                    if(Test-WithinMaintenanceWindow) { 
                       New-Event -SourceIdentifier AllowDSCSet 
                     } 
                   }
#This allows the DSC resource SET function/method to have a Get-Event or 
#  Wait-EngineEvent -SourceIdentifier AllowDSCSet -Timeout x
function Test-WithinMaintenanceWindow {
 [cmdletBinding()]
 [outputType([bool])]
 param(
  [datetime]
  $time = (Get-Date)
 )

 if($time -ge (& $Global:LCMData.MaintenanceWindow.WindowStart) `
     -and $time -le (& $Global:LCMData.MaintenanceWindow.WindowEnd) ) 
 {
  Return $true
 }
 else {
  Return $false
 }
}
Export-ModuleMember -function Test-WithinMaintenanceWindow




Register-EngineEvent -SourceIdentifier LCMStartTest -Action { 
        Push-MQMessage -resource $event.MessageData.resource `
        -ConfigurationID $event.MessageData.ConfigurationID  }
#This could allow Realtime Asynchronous notifications to other systems
function Push-MQMessage{
 [cmdletBinding()]
 Param(
  $resource,
  $ConfigurationID
  
 )
 $MQMsgParams = @{
  'Exchange' = 'myDSCTopicExchange'
  'Key' = "$ConfigurationID.$resource" 
     #the key is for routing from Exchange to Queues based on subscription
     # see http://www.rabbitmq.com/tutorials/tutorial-four-dotnet.html
  'InputObject' = ([PSCustomObject]@{
                       'EventTime'= (Get-Date -Format 'yyyy.MM.dd hh:mm:ss.fff')
                       'ComputerName'=$env:COMPUTERNAME
                       'LCMData'=$script:LCMData
                    } | ConvertTo-Json -Depth ([int]::MaxValue)
  )
 }
 Send-RabbitMqMessage @MQMsgParams
 
}

Export-ModuleMember -function Push-MQMessage