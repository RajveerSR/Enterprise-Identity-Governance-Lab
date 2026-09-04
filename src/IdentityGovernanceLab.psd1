@{
    RootModule = 'IdentityGovernanceLab.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'eb829dca-d68f-491e-b778-b62f62614d61'
    Author = 'Enterprise Identity Governance Lab'
    Description = 'Plan-first lifecycle reconciliation for a scoped Microsoft Entra lab.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Import-LabData',
        'New-LabAccessPlan',
        'Get-LabPlanHash',
        'Test-LabPlanIntegrity',
        'Invoke-LabPlan',
        'Invoke-LabGraphOperation',
        'Test-LabAccessState'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}

