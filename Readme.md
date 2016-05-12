# DSC LCM Extensible Architecture - UserVoice Request Draft

_Not yet posted, feel free to add your feedback_.

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


## Example of Extension
Have a look at [LCMExtension.psm1](LCMExtension.psm1) in this repo for more details

```powershell
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
#...
```

## Use cases

Those are just thoughts that I see as valuable that could be enabled by such architecture.
There may well be other and better ways to achieve those.

### Passing Data between resources
The extension script file could serve as a central point for communication between resources.
Should you want one Resource to re-use data persisted by another resource, you could update
the $LCMData as suggested above, and ensure, if you need to, the second resource is evaluated
 after the first with the existing DependsOn.


### Maintenance window
Although one of the examples above, the Maintenance Window is probably the most useful one.
We believe that Maintenance Windows should still be part of the LCM (as per [Don's UserVoice](https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088780-add-maintenance-window-awareness-to-dsc-lcm)), so that when 
reboots are needed, the actual reboot can be triggered only when the node enters
its Maintenance window.

Another drawback to have it implemented solely on custom extensions, is the need for convention
for such common necessity.

### Integrating DSC with other system via MQ (or other)
Other possibilities would be for integrating with other independent system, 
potentially non-microsoft ones, that can subscribe or publish to the queues.

1. When the WebService is configured, send notification to the MQ.
Then, another system is subscribing to that queue and add an entry in a Bind DNS.

2. A Resource depending on all the other could send notification that the system 
is configured. Leveraging an MQ here would make the integration with a business workflow
much easier, and customizable.


### Logging via message Queue
One of the neat thing you could do by implementing notification message that 
are sent via a message queue such as rabbit MQ, is that routing
them based on their log level, and you having a system such as Logstash/ElasticSearch to
subscribe to them (ERROR level by default, but you can change to DEBUG 'on the fly'),
and then displaying with, say, Kibana.

 
Do you have other ideas that could leverage such hypothetical LCM Extensible Architecture?
Or do you think there are flaws in the idea making it impossible/impractical?

Please comment on the userVoice.

This has been inspired by Don Jones' session at the summit ['Stupid DSC Tricks'](https://www.youtube.com/watch?v=CyADIv3E-ec&list=PLfeA8kIs7Coc1Jn5hC4e_XgbFUaS5jY2i&index=18).



