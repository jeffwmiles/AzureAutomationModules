
# Function to Import DSC modules if not already imported
# Original source of function: https://github.com/Microsoft/AzureAutomation-Account-Modules-Update/blob/master/Update-AutomationAzureModulesForAccount.ps1
function Import-AutomationModule {
    param(
        [Parameter(Mandatory = $true)]
        [String] $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [String] $AutomationAccountName,

        [Parameter(Mandatory = $true)]
        [String] $ModuleName,

        # if not specified latest version will be imported
        [Parameter(Mandatory = $false)]
        [String] $ModuleVersion
    )

    $Url = "https://www.powershellgallery.com/api/v2/Search()?`$filter=IsLatestVersion&searchTerm=%27$ModuleName $ModuleVersion%27&targetFramework=%27%27&includePrerelease=false&`$skip=0&`$top=40"

    # Assuming exact match of module name so take first result
    $SearchResult = Invoke-RestMethod -Method Get -Uri $Url | Select-Object -first 1

    if (!$SearchResult) {
        Write-Error "Could not find module '$ModuleName' on PowerShell Gallery."
    }

    else {
        $PackageDetails = Invoke-RestMethod -Method Get -Uri $SearchResult.id
        $ModuleExist = Get-AzureRmAutomationModule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $ModuleName -ErrorAction Ignore

        # If the module exists in the account, compare existing version and if it matches gallery version, stop
        if ($ModuleExist) {
            if ($ModuleExist.Version -eq $PackageDetails.entry.properties.version) {
                $Stop = $true
                Write-host "Module - $ModuleName exists and is at latest version"
            }
        }

        else {
            # else if the module exists or is older version, proceed, which means nothing here
            $Stop = $false
        }

        $ModuleContentUrl = "https://www.powershellgallery.com/api/v2/package/$ModuleName/$ModuleVersion"

        if (!$Stop) {

            $ActualUrl = $ModuleContentUrl

            Write-Host "Module - $ModuleName is importing to latest version" -ForegroundColor Green

            New-AzureRmAutomationModule `
                -ResourceGroupName $ResourceGroupName `
                -AutomationAccountName $AutomationAccountName `
                -Name $ModuleName `
                -ContentLink $ActualUrl

            #Return a true/false if rest of script needs to wait for modules to finish importing
            # This would be true if any module was new, inside this "if" block
            Return $true
        }
    }
}

#This list contains all modules to import into the AzureAutomationAccount
$DSCModuleList = "PSDscResources,xWebAdministration,ComputerManagementDSC,xRemoteDesktopAdmin,xDSCDomainJoin,StorageDSC,cCDROMdriveletter,NetworkingDSC,cMoveAzureTempDrive,xActiveDirectory,xPendingReboot,cChoco,xSmbShare".Split(',')

$ImportedModule = $false
#For every module in the listed array, check it and import it if necessary
foreach ($module in $DSCModuleList) {
    $ImportedModule = Import-AutomationModule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ModuleName $module
}

if (!$Stop) {
    if ($ImportedModule) {
        Write-host "Wait 120 seconds since there were modules imported"
        Start-Sleep -s 120
    }

    # Do other stuff like import DSC configurations and compile them.

}