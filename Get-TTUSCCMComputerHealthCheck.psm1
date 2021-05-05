function Get-TTUSCCMComputerHealthCheck {
    <#
		.SYNOPSIS
			Create an excel spreadsheet with pivot table of a Support Area based on the minimum hardware spec of ITS.
    
		.DESCRIPTION
			Using SCCM's PowerShell module and ImportExcel library, this Get-TTUSCCMComputerHealthCheck creates an excel spreadsheet with a pivot table of the computers within a support area based on ITS's minimum hardware spec.  Note that the General Sheet is the only one without duplicates.  The duplicates are from additional storage entries.  To install ImportExcel, run the following: install-module ImportExcel
    
		.PARAMETER SupportArea
			This parameter is manatory and for picking the SA# to pull computers from to evaluate.

        .PARAMETER SaveFile
            This is the file name that you'd like to call the spreadsheet.  If path is not included, it will put the file in whatever directory you call the function in.

        .PARAMETER MinProcGen
            This is an integer to specify the Intel generation that you'd like to use as the minimum processor allowed. (Default: 6th gen)

        .PARAMETER MinMemSize
            This is an integer to specify the minimum amount of ram that a computer should have.  Measured in GB. (Default: 8GB)
			
		.EXAMPLE
			Get-TTUSCCMComputerHealthCheck -SupportArea SA4 - SaveFile .\2021_report.xlsx
    
		.NOTES
			5/4/2210
			-Created
	#>

    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("SA0","SA1","SA2","SA3","SA4","SA5","SA6")]
        [String]
        $SupportArea,
        [Parameter(Mandatory=$true)]
        [String]
        $SaveFile,
        [int]
        $MinProcGen = 6,
        [int]
        $MinMemSize = 8
    )

    function Get-HealthCheck {
        param (
            [Parameter(Mandatory=$true)]
            [String]
            $Processor,
            [Parameter(Mandatory=$true)]
            [int]
            $MemorySize
        )

        if ([math]::ceiling($MemorySize) -lt $MinMemSize)
        {
            return "Below Spec"
        }

        if ($Processor.ToLower().Contains("xeon"))
        {
            return "Maybe"
        }

        $Dash_Index = $Processor.IndexOf("-")

        if ($Dash_Index -eq -1)
        {
            return "Maybe"
        }
       
        
        $Proc_Index = $Processor.Substring($Dash_Index+1, 1)
        $Proc_Code = 0
        if ($Proc_Index -eq 1)
        {
            $Proc_Code = [int]$Processor.Substring($Dash_Index+1, 2)
        }
        else {
            $Proc_Code = [int]$Processor.Substring($Dash_Index+1, 1)
        }
        
        if ($Proc_Code -lt $MinProcGen)
        {
            return "Below Spec"
        }
        else
        {
            return "Good Standing"
        }
    }

    # check for SCCM PWSH Module
    if (Test-Path 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1' -PathType Leaf)
    {
        Import-Module 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1'
    }
    elseif (Test-Path 'C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1' -PathType Leaf)
    {
        Import-Module 'C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1'
    }
    else
    {
        throw "SCCM Admin Module not found"
    }

    # check for ImportExcel
    if (Get-Module -ListAvailable -Name ImportExcel)
    {
        Import-Module ImportExcel
    }
    else
    {
        throw "ImportExcel is not installed `nRun the following command to install it `nInstall-Module ImportExcel"
    }

    # SCCM Setup
    Set-Location "TT2:"

    try {
        # get SA ID
        $SA_ID = $(Get-CMCollection -name "$SupportArea - ALL Computers in OU").CollectionID
    }
    catch {
        Set-Location C:
        throw "Failed to get Support Area CollectionID"
    }

    try {
        $CollectionMembers = Get-CMCollectionMember -CollectionID $SA_ID | Select-Object Name
    }
    catch {
        Set-Location C:
        throw "Failed to get Collection Members"
    }
        
    try {
        # get all comps in SA
        #$QueryResults = Invoke-CMQuery -ID TT200163 -LimitToCollectionID $SA_ID
        $WQL = @"
select SMS_R_System.Name, SMS_R_System.LastLogonUserName, SMS_G_System_PROCESSOR.Name, SMS_G_System_X86_PC_MEMORY.TotalPhysicalMemory, SMS_G_System_DISK.Model, SMS_G_System_DISK.Size, SMS_G_System_OPERATING_SYSTEM.Caption, SMS_G_System_OPERATING_SYSTEM.BuildNumber, SMS_G_System_COMPUTER_SYSTEM.Manufacturer, SMS_G_System_COMPUTER_SYSTEM.Model, SMS_G_System_PC_BIOS.SerialNumber from  SMS_R_System inner join SMS_G_System_PROCESSOR on SMS_G_System_PROCESSOR.ResourceID = SMS_R_System.ResourceId inner join SMS_G_System_X86_PC_MEMORY on SMS_G_System_X86_PC_MEMORY.ResourceID = SMS_R_System.ResourceId inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceID = SMS_R_System.ResourceId inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceID = SMS_R_System.ResourceId inner join SMS_G_System_DISK on SMS_G_System_DISK.ResourceID = SMS_R_System.ResourceId inner join SMS_G_System_PC_BIOS on SMS_G_System_PC_BIOS.ResourceID = SMS_R_System.ResourceId
"@

        $QueryResults = Invoke-CMWmiQuery -Query $WQL -Option Fast
    }
    catch {
        Set-Location C:
        throw "Failed to get the results from WMI Query"
    }

    Set-Location C:

    # loop through them to filter out extra data
    $Results = @()
    Foreach ($Result in $QueryResults)
    {
        if ($CollectionMembers.Name.Contains($($Result.SMS_R_System.Name)))
        {
            $Obj = [PSCustomObject]@{
                'Hostname' = $($Result.SMS_R_System.Name);
                'Username' = $($Result.SMS_R_System.LastLogonUserName);
                'Processor' = $($Result.SMS_G_System_PROCESSOR.Name);
                'Memory' = $([math]::ceiling($([int]$Result.SMS_G_System_X86_PC_MEMORY.TotalPhysicalMemory / 1024 / 1024))); # converting KB to GB
                'Disk_Model' = $($Result.SMS_G_System_DISK.Model);
                'Disk_Size' = $([math]::ceiling($([int]$Result.SMS_G_System_DISK.Size / 1024))); # converting from MB to GB
                'Operating_System' = $($Result.SMS_G_System_OPERATING_SYSTEM.Caption);
                'OS_Build' = $($Result.SMS_G_System_OPERATING_SYSTEM.BuildNumber);
                'Manufacturer' = $($Result.SMS_G_System_COMPUTER_SYSTEM.Manufacturer);
                'Model' = $($Result.SMS_G_System_COMPUTER_SYSTEM.Model);
                'Serial_Number' = $($Result.SMS_G_System_PC_BIOS.SerialNumber);
                'Replacement_Status' = Get-HealthCheck -Processor $Result.SMS_G_System_PROCESSOR.Name -MemorySize $([int]$Result.SMS_G_System_X86_PC_MEMORY.TotalPhysicalMemory / 1024 / 1024)
            }

            $Results += $Obj
        }
    }

    # removing duplicates for pivot table
    $UniqueResults = @()
    foreach ($Result in $Results)
    {
        if ($UniqueResults.count -eq 0)
        {
            $UniqueResults += $Result
        }
        else
        {
            if (-not $UniqueResults.Hostname.Contains($Result.Hostname))
            {
                $UniqueResults += $Result
            }
        }
    }

    # generate report based on results
    $Good_Standing = @()
    $Maybe_Standing = @()
    $Below_Spec_Standing = @()

    foreach ($comp in $Results)
    {
        switch ($comp.Replacement_Status) {
            "Good Standing" { $Good_Standing += $comp }
            "Maybe" { $Maybe_Standing += $comp }
            "Below Spec" { $Below_Spec_Standing += $comp }
        }
    }

    Export-Excel -Path $SaveFile -InputObject $UniqueResults -WorksheetName "All" -AutoSize -AutoFilter -IncludePivotTable -PivotTableName "Summary View" -PivotRows "Replacement_Status" -PivotData "Hostname"
    Export-Excel -Path $SaveFile -InputObject $Good_Standing -WorksheetName "Good Standing" -AutoSize -AutoFilter -FreezeTopRow
    Export-Excel -Path $SaveFile -InputObject $Maybe_Standing -WorksheetName "Maybe" -AutoSize -AutoFilter -FreezeTopRow
    Export-Excel -Path $SaveFile -InputObject $Below_Spec_Standing -WorksheetName "Below Spec" -AutoSize -AutoFilter -FreezeTopRow -Show
}
Export-ModuleMember -function Get-TTUSCCMComputerHealthCheck

