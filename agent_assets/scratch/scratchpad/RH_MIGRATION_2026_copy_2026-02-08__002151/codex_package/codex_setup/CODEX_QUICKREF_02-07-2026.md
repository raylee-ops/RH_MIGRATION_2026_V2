# CODEX QUICK REFERENCE — RH Migration Project
**Print this or keep it open while working**

---

## Starting Codex

```powershell
# Navigate to project root first
cd C:\RH

# Start Codex (uses migration profile by default)
codex

# Or specify a profile
codex --profile migration    # Normal work (default)
codex --profile deep         # Complex analysis, high reasoning
codex --profile fast         # Quick operations, low reasoning
```

---

## Slash Commands (Type in Codex TUI)

| Command | What it does |
|---------|--------------|
| `/status` | Show current config, model, directory |
| `/skills` | List available skills |
| `/review` | Open code review menu |
| `/plan` | Create a multi-step plan |
| `/compact` | Compress conversation history |
| `/clear` | Clear conversation |
| `/help` | Show all commands |

---

## Invoking Skills

```
# Type $ followed by skill name
$rh-migration
$powershell-safety
$skill-installer
```

---

## File Mentions

```
# Type @ to search files, then Tab/Enter to insert
@AGENTS.md
@config.toml
```

---

## Quick Shell Commands

```
# Prefix with ! to run shell commands directly
!ls
!Get-ChildItem
!git status
```

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Enter` | Send message / Inject into current turn |
| `Tab` | Queue follow-up for next turn |
| `Ctrl+C` | Cancel current operation |
| `Ctrl+D` | Exit Codex |

---

## Profiles Cheat Sheet

| Profile | Reasoning | Best For |
|---------|-----------|----------|
| `migration` | Medium | Daily migration work |
| `deep` | High | Complex analysis, debugging |
| `fast` | Low | Quick counts, simple moves |

---

## Safety Reminders

1. **Dry-run first:** Always say "show me what would happen"
2. **Count before/after:** "Count files before and after moving"
3. **Quarantine, don't delete:** "Move to _ARCHIVE instead of deleting"
4. **Check git status:** "Check if there are uncommitted changes first"

---

## Common Prompts

### Phase Status
```
Show me the current status of the RH migration plan phases
```

### Inventory Scan
```
Run an inventory scan of C:\RH and save to the runs folder
```

### Find Duplicates
```
Find duplicate files by name and size in C:\RH
```

### Safe Move
```
Move the contents of [source] to [dest], verify counts before and after
```

### Create Dated Report
```
Create a phase status report with today's date in the filename
```

---

## File Locations

| File | Path |
|------|------|
| Global config | `C:\Users\Raylee\.codex\config.toml` |
| Global instructions | `C:\Users\Raylee\.codex\AGENTS.md` |
| Project instructions | `C:\RH\AGENTS.md` |
| User skills | `C:\Users\Raylee\.codex\skills\` |
| Project skills | `C:\RH\.agents\skills\` |
| Run outputs | `C:\RH\OPS\SYSTEM\DATA\runs\` |
| Migration ledger | `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\` |

---

## Troubleshooting

### Codex not reading AGENTS.md?
```powershell
# Check if project is trusted
codex
/status
# Look for "Project: trusted" or "Project: untrusted"
```

### Skills not showing?
```powershell
# Restart Codex after installing skills
codex
/skills
```

### Config not applying?
```powershell
# Verify config syntax
codex --help
# Check for TOML errors in config.toml
```

---

**Date format reminder:** `name_MM-DD-YYYY.ext`
