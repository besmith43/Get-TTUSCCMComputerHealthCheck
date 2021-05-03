function Get-TTUSCCMComputerHealthCheck {
    param (
        [Parameter(Mandatory=$True)]
        [ValidateSet("SA0","SA1","SA2","SA3","SA4","SA5","SA6")]
        [String]
        $SupportArea,
        [String]
        $ComputerName = ''
    )

    function Get-HealthCheck {
        param (
            [Parameter(Mandatory=$True)]
            [String]
            $ComputerName
        )
    
        Write-Host "Hello From Nested Function with Computer Name: $ComputerName"
        
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
        throw "ImportExcel is not installed"
    }

    # checking if Computer Name was supplied

    if ($ComputerName -ne '')
    {
        get-healthcheck $ComputerName
    }
    else
    {
        # get all comps in SA

        # loop through them by calling get-healthcheck

        # generate report based on results
    }
}
Export-ModuleMember -function Get-TTUSCCMComputerHealthCheck

