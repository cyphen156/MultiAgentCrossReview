@{
    # Point ToolRoot at your private MultiAgentWorkbenchStateVault: the self-contained
    # real instance (tool + real state data) you actually clone and use. The public
    # https://github.com/cyphen156/MultiAgentWorkbenchStateSync is only the example template.
    # This package is only a thin adapter: it delegates to Launchers\Start.ps1 /
    # Launchers\Finish.ps1 under ToolRoot and injects -WorktreeRoot (this workbench).
    # The state-repo target (VaultRoot) is configured in the tool's own config at ToolRoot.
    ToolRoot = 'C:\Project\MultiAgent\MultiAgentWorkbenchStateVault'

    # Optional explicit script paths (override ToolRoot\Launchers\Start.ps1 / ToolRoot\Launchers\Finish.ps1).
    StartScript = ''
    FinishScript = ''
}
