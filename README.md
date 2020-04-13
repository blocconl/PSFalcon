**WARNING**: The PSFalcon modules are an independent project and not supported by CrowdStrike.

# Installation

Requires **[PowerShell 5.1+](https://github.com/PowerShell/PowerShell#get-powershell)**.

```powershell
PS> Install-Module -Name PSFalcon
```

# Getting Started

Interacting with the CrowdStrike Falcon OAuth2 APIs requires an **[API Client ID and Secret](https://falcon.crowdstrike.com/support/api-clients-and-keys)** and a valid
OAuth2 token.

If you attempt to run a PSFalcon command without a valid token, you will be forced to make a token
request. You can make a manual request using the `Get-CsToken` command:

```powershell
PS> Get-CsToken
Client Id: <string>
Client Secret: <string>
PS> $Falcon

Name                           Value
----                           -----
expires                        1/1/2020 8:00:00 AM
token                          <string>
id                             <string>
secret                         System.Security.SecureString
host                           <string>
```

**WARNING**: Using the optional `-Id` and `-Secret` parameters with `Get-CsToken` will result in your API
credentials being displayed in plain text. This could expose them to a third party.

Once a valid OAuth2 token is received, it is cached under `$Falcon` with your credentials. Your cached
token will be checked and refreshed when needed while running PSFalcon commands.

If you need to choose a different cloud or use a proxy when making requests, you will need to issue a manual
`Get-CsToken` command with the appropriate parameters at the beginning of your PowerShell session.

### Choosing a Cloud

By default, token requests are sent to the US cloud. The `-Cloud` parameter can be used to choose a different
destination. Your choice is saved in `$Falcon` and all requests will be sent to the chosen cloud unless a new
`Get-CsToken` request is made.

### Using a Proxy

The `-Proxy` parameter can be added to a token request to define a proxy. Your choice is saved in `$Falcon`
and all requests will be directed to your proxy until a new `Get-CsToken` request is made.

# Examples

### Containing Hosts

To contain a host, you need the Host Id for the target device(s). If you don't have them, `Get-CsHostId`
can be used to find them with a filtered search:

```powershell
PS> Get-CsHostId -Filter "hostname:'Example-PC'" -OutVariable HostId

meta                                                                                    resources
----                                                                                    ---------
@{query_time=<int>; pagination=; powered_by=<string>; trace_id=<string>}                {<array>
```

Next, the Host Id can be used with the `Start-CsContain` command to isolate the device from its network. Because
the Host Id results are contained in the member `$HostId.resources`, you'll need to reference it directly. The
[Responses](#Responses) section further explains what you can expect inside the results of a command.

You can reference the resources member for the `Start-CsContain` command, too. However, it only makes sense to
do so if you expect a successful result and have no need to analyze the rest of the output:

```powershell
PS> (Start-CsContain -Id $HostId.resources).resources

id                               path
--                               ----
<string>                         <string>
```

Congratulations! Your network containment request has been submitted for this device. You can release the device
from containment by using `Stop-CsContain`:

```powershell
PS> (Stop-CsContain -Id $HostId.resources).resources

id                               path
--                               ----
<string>                         <string>
```

### Retrieving Large Sets of Devices

To obtain all of the Host Ids in your environment, you can use the command `Get-CsHostId`. Each individual
PSFalcon command is subject to the limits of the API it uses, so if there are more results than what are
returned with the first request, you'll have to make additional requests. PSFalcon uses the `-All` flag
to repeat requests and retrieve results when one command won't get everything:

```powershell
PS> $HostIds = (Get-CsHostId -All).resources
```

Once you have your Host Ids, you can gather the detail about each Host Id. PSFalcon will automatically break
these requests up into appropriately sized groups until all results are retrieved:

```powershell
PS> $HostInfo = (Get-CsHostInfo $AllHostIds).resources
```

However, if you're dealing with large amounts of devices, this could take a bit of time. It might make sense
to take a shortcut and import a CSV from your **[Host Management](https://falcon.crowdstrike.com/hosts/hosts)** page:

```powershell
PS> $AllHosts = Import-Csv .\164322_hosts_2020-01-01T08_00_00Z.csv
```

Now you've got similar data as `$HostInfo` stored in `$AllHosts`, and you can reference each column from the
CSV directly:

```powershell
PS> $AllHosts.'Host ID'
<array>
PS> $AllHosts | Select-Object 'Host ID', Hostname, 'Last Seen', 'Status'

Host ID                          Hostname        Last Seen            Status
-------                          --------        ---------            ------
<array>                          <array>         <array>              <array>
```

### Using Real-time Response

Similar to using Network Containment, with Real-time Response, you'll start with one or more Host Ids:

```powershell
PS> $HostId = (Get-CsHostId -Filter "hostname:'Example-PC'").resources
```

Whether you're dealing with one device, or a group of devices, you need to initiate a Real-time Response
batch session to begin sending commands:

```powershell
PS> Start-RtrBatch -Id $HostId -OutVariable Batch

meta                                                        batch_id
----                                                        --------
@{query_time=<int>; powered_by=; trace_id=<string>}         14bf2ab4-a1e1-471f-b9…
```

When at least one of your devices has been successfully initiated in the Real-time Response batch, you'll
receive a Batch Id in return:

```powershell
PS> $Batch.batch_id
<string>
```

To see the status of the individual devices in the batch, you can drill down into `$Batch.resources` and
view the devices themselves:

```powershell
PS> $Batch.resources.psobject.properties.value

session_id   : <string>
task_id      : <string>
complete     : <boolean>
stdout       : <string>
stderr       :
base_command : <string>
aid          : <string>
errors       : <array>
query_time   : <int>
```

Or, you can view the entire response as a string using `ConvertTo-Json`:

```powershell
PS> $Batch | ConvertTo-Json
{
  "meta": {
    "query_time": <int>,
    "powered_by": <string>,
    "trace_id": <string>
  },
  "batch_id": <string>,
  "resources": {
    <string>: {
      "session_id": <string>,
      "task_id": <string>,
      "complete": <boolean>,
      "stdout": <string>,
      "stderr": "",
      "base_command": <string>,
      "aid": <string>,
      "errors": "",
      "query_time": <int>
    }
  },
  "errors": []
}
```

With the Batch Id being generated, that provides the ability to start sending commands to the devices
contained in the batch. Using **[Real-time Response](https://falcon.crowdstrike.com/support/documentation/71/real-time-response-and-network-containment#real-time-response)** gives you the ability to do things like...

Put a file **[from the cloud](https://falcon.crowdstrike.com/configuration/real-time-response/tools/files)** onto your devices:

```powershell
PS> $Put = Send-RtrCommand -Id $Batch.batch_id -Command put -String Example.exe
PS> $Put.combined.resources.psobject.properties.value

session_id   : <string>
task_id      : <string>
complete     : <boolean>
stdout       : <string>
stderr       :
base_command : <string>
aid          : <string>
errors       : {}
query_time   : <int>
```

Or run a script **[from the cloud](https://falcon.crowdstrike.com/configuration/real-time-response/tools/scripts)** on your devices:

```powershell
PS> $Runscript = Send-RtrCommand -Id $Batch.batch_id -Command runscript -String "-CloudFile=`"Example`""
PS> $Runscript.combined.resources.psobject.properties.value

session_id   : <string>
task_id      : <string>
complete     : <boolean>
stdout       : <string>
stderr       :
base_command : <string>
aid          : <string>
errors       : {}
query_time   : <int>
```

# Commands

To display a list of the commands available with PSFalcon:

```powershell
PS> Get-Command -Module PSFalcon
```

You can also use `Get-Help` for information about each individual command:

```powershell
PS> Get-Help -Name <string> -Detailed
```

Additionally, each API includes a README file with references and generic examples:

### Authentication

**[CrowdStrike OAuth2 Token API](/oauth2)**

### Detections and Incidents

**[CrowdStrike Falcon Detections API](/detects)**

**[CrowdStrike CrowdScore Incident API](/incidents)**

### Falcon Discover

**[CrowdStrike Falcon Discover for AWS API](/cloud-connect-aws)**

### Hosts and Groups

**[CrowdStrike Falcon Host API](/hosts)**

**[CrowdStrike Falcon Host Group API](/host-group)**

### Installers

**[CrowdStrike Falcon Sensor Download API](/sensor-download)**

### Policies

**[CrowdStrike Falcon Device Control Policy API](/device-control-policies)**

**[CrowdStrike Falcon Firewall Management Policy API](/firewall-policies)**

**[CrowdStrike Falcon Prevention Policy API](/prevention-policies)**

**[CrowdStrike Falcon Sensor Update Policy API](/sensor-update-policies)**

### Real-time Response

**[CrowdStrike Falcon Real-time Response API](/real-time-response)**

### Sandbox

**[CrowdStrike Falcon X Sandbox API](/falconx-sandbox)**

### Threat Intelligence

**[CrowdStrike Threat Intelligence API](/intel)**

### User Management

**[CrowdStrike Falcon User Management API](/user-management)**

# Responses

PowerShell objects are generated in response to PSFalcon commands:

```powershell
PS> Get-CsHostId

meta                                                                        resources
----                                                                        ---------
@{query_time=<int>; pagination=; powered_by=<string>; trace_id=<string>}    @{...}
```

The members of the response object can be referenced to retrieve specific data. `$PSObject.meta`
contains information about the request itself:

```powershell
PS> $HostIds = Get-CsHostId
PS> $HostIds.meta

query_time  pagination                                  powered_by trace_id
----------  ----------                                  ---------- --------
<int>       @{offset=<int>; limit=<int>; total=<int>}   <string>   <string>
```

Results of a successful request are typically contained within `$PSObject.resources` but some request
types fall under fields like `$PSObject.combined`, `$PSObject.batch_id`, or even `$PSObject.meta.quota`.

You can return the results themselves by calling `$PSObject.resources` or related member:

```powershell
PS> $HostIds.resources
<array>
```

`$PSObject.errors` is populated when a request was received by the server and an error was returned:

```powershell
PS> $HostIds.errors

code    message
----    -------
<int>   <string>
```

### Rate Limiting

By default, PSFalcon checks the response header for the `X-RateLimit-RetryAfter` field and sleeps for the
appropriate amount of time.

### Debugging

Adding the `-Debug` flag to any command will output the entire response, response header and command
inputs to `.\<trace_id>.json` for troubleshooting purposes.