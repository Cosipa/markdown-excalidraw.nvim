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

  -- Custom browser command (nil = system default)
  -- Examples: "firefox", "google-chrome", "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
  browser_command = nil,

  -- Log level: "debug", "info", "warn", "error"
  log_level = "info",
})
```

All options are optional. Defaults are shown above.

## Commands

| Command | Description |
|---|---|
| `:ExcalidrawOpen [file]` | Open an `.excalidraw` file in the browser. Uses the current buffer if no argument is given. |
| `:ExcalidrawCreate <name>` | Create a new `.excalidraw` file with an empty template and open it in the browser. Appends `.excalidraw` extension if missing. |
| `:ExcalidrawStatus` | Show whether the server is running and on which port. |
| `:ExcalidrawStop` | Stop the background server. |

## Default Keymaps

| Key | Action |
|---|---|
| `<leader>xo` | Open current file in Excalidraw |
| `<leader>xn` | Create a new Excalidraw file |
| `<leader>xs` | Show server status |
| `<leader>xq` | Stop the server |

## How It Works

1. When you open or create an `.excalidraw` file, the plugin starts a local Python HTTP server (if not already running).
2. The server serves a single-page Excalidraw editor loaded from [esm.sh](https://esm.sh) CDN.
3. Your default browser opens to `http://127.0.0.1:<port>/?file=<path>`.
4. As you draw, changes are automatically saved back to disk via the server's REST API (debounced, default 1s).
5. Closing the browser tab triggers a final save via `sendBeacon`.
6. The server is automatically stopped when Neovim exits.

## Features

- **Zero Python dependencies** - uses only the standard library (`http.server`, `json`, `socket`)
- **Automatic file sync** - changes in the browser are debounced and saved to disk
- **Last-chance save** - uses `navigator.sendBeacon` on tab close to avoid data loss
- **Atomic writes** - writes to a temp file then renames, preventing corruption
- **Security** - server binds to localhost only, and rejects requests for non-`.excalidraw` files
- **JSON syntax highlighting** - `.excalidraw` files get JSON treesitter highlighting in Neovim
- **Theme sync** - the Excalidraw editor follows your Neovim light/dark theme
- **Cross-platform** - macOS (`open`), Linux (`xdg-open`), and WSL (`wslview`)

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
│   └── utils.lua                # Helpers (browser, URL encoding, logging)
└── server/
    ├── excalidraw_server.py     # Python HTTP server (stdlib only)
    └── index.html               # Excalidraw web app (React from esm.sh CDN)
```

## License

MIT
