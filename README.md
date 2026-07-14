# Menu Bar Notes

A simple menu bar quick notes app that lets you add notes to a markdown folder of your choosing.

## Requirements

- macOS 13 or later
- Swift 5.9+ (Xcode Command Line Tools)

## Build & run

```bash
./build.sh
open ../MenuBarNotes.app
```

## Usage

| Action | What it does |
|--------|----------------|
| **Left-click** menu bar icon | Open the note editor (creates a note if none is active) |
| **Right-click → New Note** | Create a new `.md` note |
| **Right-click → Open Existing…** | Pick an existing note from the notes folder |
| **Right-click → Choose Notes Folder…** | Set where notes are saved |
| **Right-click → Reveal in Finder** | Show the current note (or folder) in Finder |
| **Right-click → Quit** | Save and quit |

Notes are plain Markdown files named like `yyyy-MM-dd_HHmmss_N.md`. The app autosaves about every 2 seconds while you type (similar to Obsidian).

## Notes folder

- **Default:** `~/Documents/MenuBarNotes` (created automatically if needed)
- **Change it:** right-click the menu bar icon → **Choose Notes Folder…**

That path is stored in your user preferences, so you can point the app at an Obsidian vault folder (or any other directory) without editing source code.

## License

MIT
