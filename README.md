# markdown-excalidraw.nvim

A Neovim plugin that opens [Excalidraw](https://excalidraw.com) diagrams in your
browser with automatic file synchronization.

![demo](https://github.com/user-attachments/assets/2b2f9083-83a8-40a6-9f16-ef3f9d486fce)

> This is a fork of
> [caioeverest/excalidraw.nvim](https://github.com/caioeverest/excalidraw.nvim)

## How It Works

```
Neovim --(starts)--> Python Server --(serves)--> Browser (Excalidraw)
                           ^                         ^
                           |   REST API (GET/POST)   |
                           +-------------------------+
                                      |
                                 Filesystem
```

When you open an `.excalidraw` file in Neovim, the plugin starts a lightweight
local Python server that serves the Excalidraw editor via esm.sh and opens it in
your browser. Changes in the browser are automatically synced back to disk via
REST API.

## Requirements

- Neovim >= 0.9
- Python 3 (stdlib only)
- A modern web browser with internet access

## Installation

### lazy.nvim with bindings

```lua
{
  "Cosipa/markdown-excalidraw.nvim",
  cmd = { "ExcalidrawOpen", "ExcalidrawCreate", "ExcalidrawStatus", "ExcalidrawStop" },
  keys = {
    { "<leader>xo", "<cmd>ExcalidrawOpen<cr>", desc = "Open excalidraw file in browser" },
    { "<leader>xn", "<cmd>ExcalidrawCreate<cr>", desc = "Create new excalidraw file" },
    { "<leader>xs", "<cmd>ExcalidrawStatus<cr>", desc = "Show server status" },
    { "<leader>xq", "<cmd>ExcalidrawStop<cr>", desc = "Stop server" },
  },
}
```

## Configuration

All options are optional:

```lua
require("markdown-excalidraw").setup({
  auto_open = true,              -- Open .excalidraw files automatically
  theme = "auto",                -- "light", "dark", or "auto" (follows vim.o.background)
  python_path = "python3",       -- Python interpreter
  server_host = "127.0.0.1",    -- Server bind address
  server_port = 0,               -- 0 = random free port
  save_debounce_ms = 1000,       -- Auto-save debounce interval
  server_timeout_min = 15,      -- Idle timeout (0 = disabled)
  browser_command = nil,         -- e.g., "firefox", "google-chrome"
  library_path = nil,            -- Path to .excalidrawlib file
  assets_dir = "assets",         -- Subdirectory for new files
  log_level = "info",            -- "debug", "info", "warn", "error"
})
```

## Commands

| Command             | Description                                                            |
| ------------------- | ---------------------------------------------------------------------- |
| `:ExcalidrawOpen`   | Open an `.excalidraw` file. Arg, link under cursor, or current buffer. |
| `:ExcalidrawCreate` | Create a new file in `assets/` and open it. Inserts markdown link.     |
| `:ExcalidrawStatus` | Show server status and port.                                           |
| `:ExcalidrawStop`   | Stop the background server.                                            |

## Features

- **Auto-sync** - Changes are debounced and saved to disk automatically
- **Library support** - Shared exalidraw shapes are stored in a `.excalidrawlib`
  file, that way you don't lose your shapes.
- **Last-chance save** - Uses `sendBeacon` on tab close to prevent data loss
- **Atomic writes** - Writes to temp file then renames
- **Theme sync** - Excalidraw matches your Neovim light/dark setting
- **Cross-platform** - Works on macOS, Linux, and WSL

## Markdown Integration

### Creating linked diagrams

`:ExcalidrawCreate` creates a new file and inserts a markdown link at the
cursor.

### Opening linked diagrams from markdown links

Place the cursor on a link: `[diagram](./my-diagram.excalidraw)` and run
`:ExcalidrawOpen`.

## License

MIT
