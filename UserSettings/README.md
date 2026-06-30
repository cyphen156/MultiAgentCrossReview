# UserSettings

This directory is the local private settings area for a user of this workbench.

Only this README is intended to be tracked. All other files and subdirectories under
`UserSettings/` are ignored by git.

Use this area for personal, non-public settings such as:

- tone and language preferences;
- no-yes-man / critique behavior preferences;
- private workflow notes;
- machine-specific user context;
- local session or handoff hints that should not enter the public MIT repository.

Suggested local files:

```text
UserSettings/preferences.md       # tone, critique style, stable personal workflow
UserSettings/session.md           # current local handoff notes
UserSettings/machines/<name>.md   # machine-specific notes
```

`preferences.md` is the default always-on private user layer. If it exists, agents
should load it before project-specific rules. Do not gate it behind tone/style
keywords.

Do not put public workbench rules here. Put public rules in `Common/SHARED_RULES.md`
or `Reviews/README.md`.

Do not put project-specific code style or architecture rules here. Put those in
`Projects/<name>/RULES.md`.
