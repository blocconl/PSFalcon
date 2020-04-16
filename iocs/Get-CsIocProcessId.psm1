function Get-CsIocProcessId {
<#
    .SYNOPSIS
        Find processes on a Host associated with a custom IOC

    .PARAMETER TYPE
        Type of the indicator

    .PARAMETER VALUE
        String representation of the indicator

    .PARAMETER ID
        Target Host ID

    .PARAMETER LIMIT
        The maximum records to return [default: 100]

    .PARAMETER OFFSET
        The offset to start retrieving records from [default: 0]

    .PARAMETER ALL
        Repeat requests until all results are retrieved
#>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('domain', 'ipv4', 'ipv6', 'md5', 'sha256')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [ValidateLength(1,200)]
        [string]
        $Value,

        [Parameter(Mandatory = $true)]
        [ValidateLength(32,32)]
        [string]
        $Id,

        [ValidateRange(1,100)]
        [int]
        $Limit = 100,

        [int]
        $Offset = 0,

        [switch]
        $All
    )
    process{
        $Param = @{
            Uri = '/indicators/queries/devices/v1?limit=' + [string] $Limit + '&offset=' + [string] $Offset +
            '&type=' + $Type + '&value=' + $Value + '&device_id=' + $Id
            Method = 'get'
            Header = @{
                accept = 'application/json'
                'content-type' = 'application/json'
            }
        }
        switch ($PSBoundParameters.Keys) {
            'Debug' { $Param['Debug'] = $true }
            'Verbose' { $Param['Verbose'] = $true }
        }
        if ($All) {
            Join-CsResult -Activity $MyInvocation.MyCommand.Name -Param $Param
        }
        else {
            Invoke-CsAPI @Param
        }
    }
}