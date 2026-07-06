@{
    # Point ToolRoot at your private AgentSessionVault: the self-contained real
    # instance (tool + real session JSONL) you actually clone and use. The public
    # https://github.com/cyphen156/AgentSessionSync is only the example template.
    # The wrapper expects Launchers\Start.ps1 and Launchers\Finish.ps1 under this
    # directory unless StartScript/FinishScript are set explicitly.
    ToolRoot = 'C:\Project\MultiAgent\AgentSessionVault'

    # Optional explicit script paths.
    StartScript = ''
    FinishScript = ''
}
