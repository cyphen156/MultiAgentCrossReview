@{
    # Root Start.ps1 / Finish.ps1 only run packages explicitly listed here.
    # ProjectSync is intentionally not listed; run Packages/ProjectSync/Start.ps1 manually.
    Packages = @(
        @{
            Name = 'WorkbenchStateSync'
            StartScript = 'Start.ps1'
            FinishScript = 'Finish.ps1'
            ConfigAny = @(
                'Packages\WorkbenchStateSync\workbenchstatesync.config.psd1'
                'WorkbenchStateSync.local.psd1'
            )
        }
        @{
            Name = 'AgentSessionSync'
            StartScript = 'Start.ps1'
            FinishScript = 'Finish.ps1'
            ConfigAny = @(
                'Packages\AgentSessionSync\agentsessionsync.config.psd1'
                'AgentSessionSync.local.psd1'
            )
        }
    )
}
