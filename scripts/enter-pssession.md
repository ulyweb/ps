## Powershell Remotely

# Login remotely

#### Getting the network adapter physical
````
get-netadapter
get-netadapter -Physical
````

#### Getting just | Select-Object MacAddress, Name, InterfaceDescription, Status
````
Get-NetAdapter -Physical | Select-Object MacAddress, Name, InterfaceDescription, Status
````


````
Get-NetConnectionProfile
````
