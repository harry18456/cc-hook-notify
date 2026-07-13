English | [繁體中文](README.zh-TW.md)

# hook-notify

Pops a **native Windows toast notification + system sound** when Claude Code finishes responding or is waiting for your input.
When several projects run in parallel, the notification title carries the project name and a short session code, and the body shows the full working directory — so you can tell at a glance which window is calling you.

- Zero dependencies: built entirely on Windows built-in APIs (WinRT Toast + SoundPlayer)
- No file writes, no network, no admin rights
- Hooks two events: `Stop` (response finished) and `Notification` (waiting for input / permission)

> ⚠️ **Windows only**. On Mac / Linux the hook will try to call `powershell` and fail.

## Installation

```
/plugin marketplace add harry18456/cc
/plugin install hook-notify@harry18456
```

Restart Claude Code to take effect.

### ⚠️ Before installing: remove old manual hooks

If you previously set up this notification script by editing `settings.json` by hand, remove those `Stop` / `Notification` hooks first — otherwise each event will **fire twice**.

## Testing

After installing, run in cmd (should "play a sound + show a toast"):

```
echo {"cwd":"C:\\test\\demo","session_id":"demo1234"} | powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/hook-notify.ps1" -HookEvent Stop
```

## Notes

- **Encoding**: `scripts/hook-notify.ps1` must stay UTF-8 with BOM (it contains Chinese text). This repo protects it via `.gitattributes` (`*.ps1 -text`), so clones won't break.
- **Blocked files**: scripts downloaded from Teams / the web may get flagged as blocked; the command already passes `-ExecutionPolicy Bypass` and usually runs — if it still fails, run `Unblock-File <path>`.
- **Corporate GPO**: if MachinePolicy enforces the ExecutionPolicy, Bypass gets overridden — talk to IT.
- **Missing sounds** degrade gracefully: the toast still shows, just silently.
- **Notifications aren't clickable**: clicking only dismisses them (click-to-focus is planned for v2).
- **Privacy**: the notification body shows the full working-directory path; others can see it while screen-sharing / recording.

## What else this plugin could ship

hook-notify currently uses **hooks** only. The plugin container can also carry the components below — this repo already has the matching **empty directory skeletons**, so future extensions just drop files in (most components are **auto-discovered** by Claude Code, no plugin.json declaration needed):

| Component | Location | What goes there |
|-----------|----------|-----------------|
| **Slash commands** | `commands/` | `*.md`, each becomes a `/hook-notify:<name>` command |
| **Subagents** | `agents/` | `*.md` (subagent definitions with frontmatter) |
| **Skills** | `skills/<name>/` | `SKILL.md` + resources (progressive-disclosure capability packs) |
| **Output styles** | `output-styles/` | `*.md`, changes Claude's output style |
| **Executables** | `bin/` | executables, added to Bash's `$PATH` when the plugin is enabled |
| **Hooks** | `hooks/hooks.json` | event hooks (← currently used) |
| **MCP servers** | `.mcp.json` | binds external tools / data sources |
| **LSP servers** | `.lsp.json` | language servers (completion / diagnostics) |
| **Themes** (experimental) | `themes/` | `*.json` color schemes, shown in `/theme`; requires plugin.json `experimental.themes` |
| **Monitors** (experimental) | `monitors/monitors.json` | background monitoring; requires plugin.json `experimental.monitors` |

> ⚠️ `commands/`, `agents/`, `skills/`, `output-styles/`, `bin/` are **auto-discovered** — no plugin.json declaration needed.
> In particular: do **NOT** point the `hooks` field in plugin.json at the standard `hooks/hooks.json` again (it auto-loads; declaring it twice causes `duplicate load failed`) — only hook files at "extra paths" need declaring.
