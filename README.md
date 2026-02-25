# Turtle Reagent Display

A lightweight Turtle WoW (1.12) addon that displays reagent counts directly on your action bar buttons. Never get caught without reagents again — see at a glance how many you have left before your next raid, dungeon, or portal request.

<img width="375" height="127" alt="image" src="https://github.com/user-attachments/assets/65b20a6d-65aa-4e33-b363-d9040cd735d9" />

## Features

- **Reagent count overlay** on every action bar button that uses a consumable reagent
- **Works on all action bars** — main bar, bonus bar, and all four multi-bars
- **Supports all classes** with consumable item reagents
- **Red warning** when count reaches zero
- **Auto-updates** on bag changes, action bar swaps, and page changes
- **Turtle WoW compatible** — auto-detects custom `Teleport:` and `Portal:` destinations via prefix matching
- **Minimal performance impact** — throttled scanning with event-driven updates
- Spells that consume class-generated resources (e.g. Soul Shards) are intentionally excluded — those already grey out the button when unavailable.
