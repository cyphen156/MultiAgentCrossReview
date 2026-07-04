@{
    # Local clone/path of https://github.com/cyphen156/MultiAgentWorkbenchStateSync.
    # This package is only a thin adapter: it delegates to Start.ps1 / Finish.ps1
    # under ToolRoot and injects -WorktreeRoot (this workbench).
    # The actual state-repo target (VaultRoot) is configured in the external tool's
    # own config at ToolRoot, not here.
    ToolRoot = 'D:\Tools\MultiAgentWorkbenchStateSync'

    # Optional explicit script paths (override ToolRoot\Start.ps1 / ToolRoot\Finish.ps1).
    StartScript = ''
    FinishScript = ''
}
