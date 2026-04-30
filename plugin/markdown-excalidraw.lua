if vim.g.loaded_excalidraw then
  return
end
vim.g.loaded_excalidraw = true

local commands = require("markdown-excalidraw.commands")
local config = require("markdown-excalidraw.config")
local server = require("markdown-excalidraw.server")
local utils = require("markdown-excalidraw.utils")

vim.api.nvim_create_user_command("ExcalidrawOpen", commands.open, {
  nargs = "?",
  complete = "file",
  desc = "Open an excalidraw file in the browser",
})

vim.api.nvim_create_user_command("ExcalidrawCreate", commands.create, {
  nargs = "?",
  complete = "file",
  desc = "Create a new excalidraw file and open it",
})

vim.api.nvim_create_user_command("ExcalidrawStatus", commands.status, {
  desc = "Show excalidraw server status",
})

vim.api.nvim_create_user_command("ExcalidrawStop", commands.stop, {
  desc = "Stop the excalidraw server",
})

-- Register .excalidraw files as JSON for syntax highlighting
vim.filetype.add({
  extension = {
    excalidraw = "json",
  },
  pattern = {
    [".*%.excalidraw%.json"] = "json",
  },
})

-- Auto-open .excalidraw files in browser
vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = { "*.excalidraw", "*.excalidraw.json" },
  callback = function(ev)
    if config.options.auto_open then
      -- Set buffer as readonly since editing happens in browser
      vim.bo[ev.buf].readonly = true
      vim.bo[ev.buf].modifiable = false

      commands.open({ fargs = { ev.file } })
    end
  end,
  group = vim.api.nvim_create_augroup("excalidraw_auto_open", { clear = true }),
})

-- Stop server on Neovim exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    server.stop()
  end,
  group = vim.api.nvim_create_augroup("excalidraw_cleanup", { clear = true }),
})
