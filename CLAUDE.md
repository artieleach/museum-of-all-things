# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Museum of All Things is a Godot 4.6 game that procedurally generates an interactive 3D museum from Wikipedia content. Players explore exhibits filled with Wikipedia article text and Wikimedia Commons images, with each exhibit's doors leading to linked articles.

Platforms: Desktop, Web, Mobile, VR (Meta Quest, WebXR)

## Running the Project

```bash
# Run in Godot editor
godot --path .

# Or open project.godot in Godot 4.6
```

## Architecture

### Entry Point
- `scenes/Main.tscn` / `Main.gd` - Game lifecycle, player spawning, menu navigation, multiplayer coordination

### Core Systems

**Museum Generation Pipeline:**
1. `ExhibitFetcher` (autoload) - Fetches Wikipedia articles and Wikimedia Commons images via threaded HTTP
2. `ItemProcessor` (autoload) - Converts fetched data into game items
3. `TiledExhibitGenerator.gd` - Procedurally generates room layouts
4. `Museum.gd` - Manages exhibits, hall linking, and player transitions

**Player Systems:**
- `Player.gd` - Desktop/controller player with physics movement
- `NetworkPlayer.tscn` - Remote player representation with interpolated movement
- `XRRoot.tscn` - VR player using godot-xr-tools addon

**Networking (recently added):**
- `NetworkManager.gd` (autoload) - ENet peer-to-peer multiplayer, max 8 players
- Server authority model with RPC-based position sync (20 updates/sec)

### Key Autoloads

All in `scenes/util/`:
- `DataManager` - Persistence
- `Util` - XR detection, HTML parsing, grid conversion
- `ExhibitFetcher` - Wikipedia API
- `WorkQueue` - Thread-safe task queue with frame pacing
- `NetworkManager` - Multiplayer
- `SettingsManager` - User preferences
- `LanguageManager` - Localization (8 languages)
- `CacheControl` - Disk caching with SHA256 hashing

### Memory Management
- Max 2 exhibits loaded simultaneously (`max_exhibits_loaded` in Museum.gd)
- Unused exhibits auto-freed based on player distance
- Mobile: max 200 items/exhibit, Desktop: 2500

## Platform Detection

Use `Util.gd` helpers:
```gdscript
Util.is_xr()      # OpenXR or WebXR
Util.is_openxr()  # Meta Quest, PCVR
Util.is_webxr()   # Browser VR
Util.is_mobile()  # Mobile platforms
```

## Physics Layers

Key layers defined in project.godot:
- Layer 1: Static World
- Layer 2: Dynamic World
- Layer 3: Pickable Objects
- Layer 20: Player Body
- Layer 23: UI Objects

## Localization

Translation files in `assets/translations/` (.po format). Lobby exhibit lists in `assets/resources/lobby_data_<lang>.tres`. See `docs/translation-guide.md` for adding languages.

## Node Groups

- `render_distance` - Nodes affected by render distance culling
- `managed_light` - Lights toggled dynamically for performance
- `Environment` - Environment nodes
