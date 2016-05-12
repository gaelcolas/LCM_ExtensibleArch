# UserVoice Request for DSC LCM Extensible Architecture

## Context
I was chatting with Don Jones about the relevance of integrating DSC with a Message Queue (or broker) such as RabbitMQ, and how it could be best implemented.
We quickly came to the conclusion that most of the missing LCM features could be implemented and customized if the LCM would expose a plug-in architecture.

## The Idea
In summary the __LCM Extensible Architecture__ would do the following:

1. LCM loads a psm1 file(s) from a pre-defined directory (or defined in LCM metaconfiguration).
2. Every LCM events are [triggered](https://technet.microsoft.com/en-us/library/hh849954.aspx) in the extensions' session
3. $Global variables of the extension should be accesible from the Test/Set/Get methods of the DSC Resource
3. The author of the PSM1 extension [register-EngineEvent](https://technet.microsoft.com/en-us/library/hh849967.aspx) for required LCM Events
4. He defines Event Handlers Actions that can call psm1's exported functions


## Example
Have a look at [LCMExtension.psm1](LCMExtension.psm1) in this repo for more details

```powershell
#By defining Global, the variable should be accessible 
# directly from within the Resources Get/Set/Tests functions/methods
$Global:LCMData = [PSCustomObject]@{
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

 if($time -ge (& $Global:LCMData.MaintenanceWindow.WindowStart) -and $time -le (& $Global:LCMData.MaintenanceWindow.WindowEnd) ) {
  Return $true
 }
 else {
  Return $false
 }

}
Export-ModuleMember -function Test-WithinMaintenanceWindow
#...
```


This has been inspired by Don Jones' session at the summit ['Stupid DSC Tricks'](https://www.youtube.com/watch?v=CyADIv3E-ec&list=PLfeA8kIs7Coc1Jn5hC4e_XgbFUaS5jY2i&index=18).



