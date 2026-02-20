# ReagentDisplay

A lightweight Turtle WoW (1.12) addon that displays reagent counts directly on your action bar buttons. Never get caught without reagents again — see at a glance how many you have left before your next raid, dungeon, or portal request.

## Features

- **Reagent count overlay** on every action bar button that uses a consumable reagent
- **Works on all action bars** — main bar, bonus bar, and all four multi-bars
- **Supports all classes** with consumable item reagents
- **Red warning** when count reaches zero
- **Auto-updates** on bag changes, action bar swaps, and page changes
- **Turtle WoW compatible** — auto-detects custom `Teleport:` and `Portal:` destinations via prefix matching
- **Minimal performance impact** — throttled scanning with event-driven updates
- Spells that consume class-generated resources (e.g. Soul Shards) are intentionally excluded — those already grey out the button when unavailable.

## Installation

In the Turtle WoW launcher addons tab, click "Add new addon" and paste in the link to this repository.

## Slash Commands

- `/rd` — Show help and available commands
- `/rd list` — Print all reagent counts currently in your bags
- `/rd debug` — Inspect all visible action bar buttons (spell names, textures, matched reagents)

## How It Works

ReagentDisplay scans your visible action bar buttons using two detection methods:

1. **Tooltip scanning** — reads the spell name from a hidden tooltip and matches it against a known spell-to-reagent table
2. **Texture fallback** — matches the action button's icon texture against known spell icons (covers edge cases where tooltip scanning may not work)

Custom Turtle WoW teleport/portal destinations are automatically detected via prefix matching — any spell starting with `Teleport:` or `Portal:` will show the appropriate rune count.

## License

This project is open source. Feel free to use, modify, and distribute.
