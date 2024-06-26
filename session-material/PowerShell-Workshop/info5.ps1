﻿#requires -version 5.1

<#
this version includes a timeout parameter,
a command alias,
comment-based help, splatting, and [PSCustomObject]
#>

Function Get-ServerInfo {

<#
.Synopsis
Get help desk server information

.Description
Use this command to get basic server information.

.Parameter Computername
The name of the computer to query. You must have admin rights.

.Parameter Timeout
Enter the number of seconds between 1 and 10 to wait for a WMI connection.

.Example
PS C:\> Get-ServerInfo SRV1

OperatingSystem    : Microsoft Windows Server 2016 Standard Evaluation
Version            : 10.0.14393
Uptime             : 1.05:39:22.5945412
MemoryGB           : 4
PhysicalProcessors : 2
LogicalProcessors  : 4
ComputerName       : SRV1

Get server configuration data from SRV1.

.Example
PS C:\> Get-ServerInfo SRV1,SRV2 | Export-CSV -path c:\reports\data.csv -append

Get server info and append to a CSV file.

.Link
Get-CimInstance

.Notes
Last Updated June 10, 2023
version 1.2

.Inputs
String

#>

    [cmdletbinding()]
    [alias("gsvi")]
    Param (
        [Parameter(
            Position = 0,
            HelpMessage = "Enter the name of a Windows computer.",
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias("server", "cn")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Computername = $env:computername,

        [ValidateRange(1, 10)]
        [int32]$Timeout
    )

    Begin {
        Write-Verbose "[$((Get-Date).TimeOfDay) BEGIN  ] Starting $($MyInvocation.MyCommand)"

        #define a hashtable of parameter values to splat to Get-CimInstance
        $CimParams = @{
            ClassName    = "win32_OperatingSystem"
            ErrorAction  = "Stop"
            Computername = ""
        }

        if ($timeout) {
            Write-Verbose "[$((Get-Date).TimeOfDay) BEGIN  ] Adding timeout value of $timeout"
            $CimParams.add("OperationTimeOutSec", $Timeout)
        }
    } #begin

    Process {

        foreach ($computer in $computername) {

            Write-Verbose "[$((Get-Date).TimeOfDay) PROCESS] Processing computer: $($computer.toUpper())"

            $CimParams.computername = $computer

            Try {
                $os = Get-CimInstance @CimParams

                #moved this to the Try block so if there
                #is an error querying win32_ComputerSystem, the same
                #catch block will be used
                if ($os) {
                    Write-Verbose "[$((Get-Date).TimeOfDay) PROCESS] Getting ComputerSystem info"

                    $csParams = @{
                        ClassName    = "win32_ComputerSystem"
                        computername = $os.CSName
                        Property     = 'NumberOfProcessors', 'NumberOfLogicalProcessors'
                        ErrorAction  = 'Stop'
                    }

                    if ($timeout) {
                        $csParams.add("OperationTimeOutSec", $Timeout)
                    }

                    $cs = Get-CimInstance @csParams

                    Write-Verbose "[$((Get-Date).TimeOfDay) PROCESS] Creating output object"
                    [PSCustomObject]@{
                        OperatingSystem    = $os.caption
                        Version            = $os.version
                        Uptime             = (Get-Date) - $os.LastBootUptime
                        MemoryGB           = $os.TotalVisibleMemorySize / 1MB -as [int32]
                        PhysicalProcessors = $cs.NumberOfProcessors
                        LogicalProcessors  = $cs.NumberOfLogicalProcessors
                        ComputerName       = $os.CSName
                    }

                } #if
            }
            Catch {
                #variation on warning message
                $msg = "Failed to contact $($computer.ToUpper()). $($_.exception.message)"

                Write-Warning $msg

            }

        } #foreach
    } #process
    End {
        Write-Verbose "[$((Get-Date).TimeOfDay) END    ] Exiting $($MyInvocation.MyCommand)"
    }

} #end Get-ServerInfo

