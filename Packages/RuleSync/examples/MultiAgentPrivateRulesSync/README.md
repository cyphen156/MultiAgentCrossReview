# MultiAgentPrivateRulesSync

This is a public MIT example layout for a private markdown rule vault.

Create your own private repository from this shape. Do not commit real personal settings or project-private rules to the public MultiAgentCrossReview repository.

## Layout

```text
MultiAgentPrivateRulesSync/
├─ README.md
├─ .gitignore
├─ UserSettings/
│  ├─ preferences.md
│  ├─ session.md
│  └─ machines/
│     └─ EXAMPLE-HOST.md
└─ Projects/
   └─ ExampleProject/
      └─ RULES.md
```

## Use With RuleSync

Local ignored config in the public workbench:

```powershell
Copy-Item .\Packages\RuleSync\rulesync.config.example.psd1 .\Packages\RuleSync\rulesync.config.psd1
```

Example config:

```powershell
@{
    VaultRoot = 'D:\Private\MultiAgentPrivateRulesSync'
    WorktreeRoot = ''
}
```

Pull from the private vault into the workbench:

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Pull
```

Push from the workbench into the private vault:

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Push
```

## SSOT

The private vault is the SSOT for private markdown rules.
The public workbench only carries the engine, templates, and examples.

