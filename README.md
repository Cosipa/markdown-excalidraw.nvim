# excalidraw.nvim

A Neovim plugin that opens [Excalidraw](https://excalidraw.com) diagrams in your system browser, with automatic file synchronization back to disk.

Since Neovim has no webview, this plugin runs a lightweight local Python server that serves the Excalidraw editor and handles reading/writing `.excalidraw` files via REST API.

```
Neovim  --(starts)--> Python Server --(serves)--> Browser (Excalidraw)
                           ^                           |
                           |      REST API (GET/POST)  |
                           +---------------------------+
                                      |
                                 Filesystem
```

## Requirements

- Neovim >= 0.9
- Python 3 (no external packages needed - uses stdlib only)
- A modern web browser

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "caioeverest/excalidraw.nvim",
  cmd = { "ExcalidrawOpen", "ExcalidrawCreate", "ExcalidrawStatus", "ExcalidrawStop" },
  event = { "BufReadPre *.excalidraw", "BufReadPre *.excalidraw.json" },
  keys = {
    { "<leader>xo", "<cmd>ExcalidrawOpen<cr>", desc = "Excalidraw: Open in browser" },
    { "<leader>xn", "<cmd>ExcalidrawCreate<cr>", desc = "Excalidraw: Create new file" },
    { "<leader>xs", "<cmd>ExcalidrawStatus<cr>", desc = "Excalidraw: Server status" },
    { "<leader>xq", "<cmd>ExcalidrawStop<cr>", desc = "Excalidraw: Stop server" },
  },
  opts = {},
}
```

## Configuration

Pass options via `opts` in lazy.nvim or call `setup()` directly:

```lua
require("excalidraw").setup({
  -- Automatically open .excalidraw files in the browser when opened in Neovim
  auto_open = true,

  -- Theme for the Excalidraw editor: "light", "dark", or "auto"
  -- "auto" follows vim.o.background
  theme = "auto",

  -- Path to the Python 3 interpreter
  python_path = "python3",

  -- Server bind address (localhost only for security)
  server_host = "127.0.0.1",

  -- Server port (0 = random free port assigned by OS)
  server_port = 0,

  -- Debounce interval (ms) before auto-saving changes from the browser
  save_debounce_ms = 1000,

  -- Idle timeout in minutes before server auto-stops (0 = disabled)
  server_timeout_min = 15,

  -- Custom browser command (nil = system default)
  -- Examples: "firefox", "google-chrome", "app.zen_browser.zen"
  browser_command = nil,

  -- Path to an .excalidrawlib library file for shared shapes/stencils
  -- Default: ~/.excalidraw/library.excalidrawlib
  library_path = nil,

  -- Subdirectory name for created excalidraw files (used by :ExcalidrawCreate)
  assets_dir = "assets",

  -- Log level: "debug", "info", "warn", "error"
  log_level = "info",
})
```

All options are optional. Defaults are shown above.

## Commands

| Command | Description |
|---|---|
| `:ExcalidrawOpen [file]` | Open an `.excalidraw` file in the browser. If no argument, tries to detect a link under the cursor, then falls back to the current buffer. |
| `:ExcalidrawCreate <name>` | Create a new `.excalidraw` file in the `assets/` subdirectory and open it. Prompts for a name if none given. Inserts a markdown link at the cursor position. |
| `:ExcalidrawStatus` | Show whether the server is running and on which port. |
| `:ExcalidrawStop` | Stop the background server. |

## Default Keymaps

| Key | Action |
|---|---|
| `<leader>xo` | Open current file (or link under cursor) in Excalidraw |
| `<leader>xn` | Create a new Excalidraw file |
| `<leader>xs` | Show server status |
| `<leader>xq` | Stop the server |

## How It Works

1. When you open or create an `.excalidraw` file, the plugin starts a local Python HTTP server (if not already running).
2. The server serves a single-page Excalidraw editor loaded from [esm.sh](https://esm.sh) CDN.
3. Your default browser opens to `http://127.0.0.1:<port>/?file=<path>&library=<path>`.
4. As you draw, changes are automatically saved back to disk via the server's REST API (debounced, default 1s).
5. Library items are synced separately - changes to the library are saved to the configured `.excalidrawlib` file.
6. Closing the browser tab triggers a final save via `sendBeacon`.
7. The server automatically stops after the configured idle timeout (default 15 min) or when Neovim exits.

## Library Support

The plugin supports a shared library of reusable shapes and stencils. Library items are stored in an `.excalidrawlib` file.

### Configuration

Set `library_path` to point to your library file. If not set, defaults to `~/.excalidraw/library.excalidrawlib`.

```lua
require("excalidraw").setup({
  library_path = "~/.excalidraw/library.excalidrawlib",
})
```

### How It Works

- On page load, the library is fetched from the server and loaded into Excalidraw via the `updateLibrary` API, bypassing browser localStorage.
- When you add or remove library items, changes are debounced and saved to disk automatically.
- A status indicator in the bottom-right corner shows "Library saving..." / "Library saved" feedback.
- The library is also saved on tab close via `sendBeacon` as a last-chance save.

## Markdown Integration

### Opening diagrams from markdown links

Place your cursor on a markdown link like `[diagram](./my-diagram.excalidraw)` and run `:ExcalidrawOpen` to open that file directly.

### Creating linked diagrams

Run `:ExcalidrawCreate` to create a new diagram. A markdown link is automatically inserted at your cursor position, making it easy to embed diagrams in your notes.

## Features

- **Zero Python dependencies** - uses only the standard library (`http.server`, `json`, `socket`)
- **Automatic file sync** - changes in the browser are debounced and saved to disk
- **Library support** - shared shapes/stencils synced to `.excalidrawlib` files
- **Last-chance save** - uses `navigator.sendBeacon` on tab close to avoid data loss
- **Atomic writes** - writes to a temp file then renames, preventing corruption
- **Server idle timeout** - server auto-stops after inactivity to free resources
- **Security** - server binds to localhost only, CORS restricted to localhost origins, path validation limits file access to the directory of the first opened file
- **No browser caching** - `Cache-Control: no-store` headers ensure fresh data on every open
- **JSON syntax highlighting** - `.excalidraw` files get JSON treesitter highlighting in Neovim
- **Theme sync** - the Excalidraw editor follows your Neovim light/dark theme
- **Cross-platform** - macOS (`open`), Linux (`xdg-open`), and WSL (`wslview`)

## Limitations

- **Internet required** - The Excalidraw editor is loaded from a CDN (esm.sh). Offline mode requires bundling the assets locally, which is not yet implemented. More work needed.

## File Structure

```
excalidraw.nvim/
├── plugin/
│   └── excalidraw.lua           # Entry point: commands, autocmds, filetype detection
├── lua/excalidraw/
│   ├── init.lua                 # setup() function
│   ├── config.lua               # Default config and merge logic
│   ├── server.lua               # Python server lifecycle (jobstart/jobstop)
│   ├── commands.lua             # Command implementations
│   └── utils.lua                # Helpers (browser, URL encoding, logging, path utils)
└── server/
    ├── excalidraw_server.py     # Python HTTP server (stdlib only)
    └── index.html               # Excalidraw web app (React from esm.sh CDN)
```

## AI Assistance

This plugin was developed with the assistance of AI tools. The code has been reviewed and tested.

## License

MIT
