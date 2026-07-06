@{
    # Local clone/path of https://github.com/cyphen156/MultiAgentWorkbenchStateSync.
    # This package is only a thin adapter: it delegates to Launchers\Start.ps1 /
    # Launchers\Finish.ps1 under ToolRoot and injects -WorktreeRoot (this workbench).
    # The actual state-repo target (VaultRoot) is configured in the external tool's
    # own config at ToolRoot, not here.
    ToolRoot = 'D:\Tools\MultiAgentWorkbenchStateSync'

    # Optional explicit script paths (override ToolRoot\Launchers\Start.ps1 / ToolRoot\Launchers\Finish.ps1).
    StartScript = ''
    FinishScript = ''
}
