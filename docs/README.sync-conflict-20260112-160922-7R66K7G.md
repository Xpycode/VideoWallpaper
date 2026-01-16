# Directions

**A systematic approach to AI-assisted software development.**

For people who direct AI to build software but don't code themselves.

---

## What This Is

Directions is a documentation system that helps you:

1. **Start projects right** - Discovery interview extracts what you want to build
2. **Map to architecture** - Translates your answers into technical decisions
3. **Stay on track** - Session logging, decision tracking, phase management
4. **Avoid common bugs** - Gotcha guides for SwiftUI, web, coordinates, etc.
5. **Ship with confidence** - Production checklists and quality guides

---

## Quick Start

### For New Projects

1. Copy this folder to your project as `/docs`
2. Add to your `CLAUDE.md`:
   ```markdown
   ## Context
   Read docs/00_base.md at the start of every session.
   Check docs/PROJECT_STATE.md for current focus.
   ```
3. Start a Claude session - it will run the discovery interview
4. Build your project phase by phase

### File Structure

```
docs/
├── 00_base.md                    ← Start here (bootstrap)
├── 01_quick-reference.md         ← Daily cheatsheet
├── 02_mental-model.md            ← Philosophy
├── 03_workflow-phases.md         ← The process
├── 04_architecture-decisions.md  ← Interview → tech mapping
│
├── PROJECT_STATE.md              ← Current project status
├── decisions.md                  ← Why we chose X over Y
├── sessions/                     ← Session history
│
├── 10-19: Setup docs
├── 20-29: Technical gotchas
├── 30-39: Quality & debugging
├── 40-49: Terminology reference
└── 50-59: Advanced patterns
```

---

## Core Workflow

```
Discovery Interview → Architecture Mapping → Phase-by-Phase Building
         ↓                    ↓                      ↓
   "What do you              Maps to            30-min testable
    want to build?"       tech decisions          increments
```

---

## Key Files

| File | Purpose |
|------|---------|
| `00_base.md` | Bootstrap - read this first every session |
| `04_architecture-decisions.md` | Maps your needs to technical choices |
| `PROJECT_STATE.md` | Tracks current phase and focus |
| `decisions.md` | Records why you chose X over Y |
| `sessions/_index.md` | Session history and handoff notes |

---

## Document Categories

### Core (00-09)
Essential files for every session.

### Setup (10-19)
New project checklists and templates.

### Technical (20-29)
Platform-specific gotchas and patterns:
- SwiftUI issues
- Coordinate systems (image/video)
- macOS platform specifics
- Web development

### Quality (30-39)
Production readiness and debugging.

### Terminology (40-49)
Reference for UI elements, typography, data structures.

### Advanced (50-59)
Large project management, planning patterns.

---

## Integration with Claude Code

Directions works alongside Claude Code's features:

- **planning-with-files skill**: Use for task execution
- **Directions**: Use for project knowledge and decisions

They complement each other:
- planning-with-files = "What am I doing right now?"
- Directions = "What is this project and why these choices?"

---

## Origin

Synthesized from 229 documentation files across 15+ shipped macOS/iOS projects.

---

## Slash Commands

The `commands/` folder contains slash commands for Claude Code:

| Command | Purpose |
|---------|---------|
| `/setup` | Detect project state, offer setup/migration |
| `/status` | Quick project status check |
| `/log` | Create/update session log |
| `/decide` | Record a decision |
| `/interview` | Run discovery interview |
| `/learned` | Add a term to your personal glossary |
| `/update-directions` | Pull latest from GitHub |

To use globally, copy to `~/.claude/commands/`:
```bash
cp -r commands/* ~/.claude/commands/
```

---

## Global CLAUDE.md

See `CLAUDE-GLOBAL-TEMPLATE.md` for a template to put in `~/.claude/CLAUDE.md`.

This enables automatic project detection and setup when starting Claude in any folder.

---

## License

MIT - Use freely, modify as needed.
