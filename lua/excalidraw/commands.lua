local M = {}

local config = require("excalidraw.config")
local server = require("excalidraw.server")
local utils = require("excalidraw.utils")

local EMPTY_TEMPLATE = {
  type = "excalidraw",
  version = 2,
  source = "excalidraw.nvim",
  elements = {},
  appState = {
    viewBackgroundColor = "#ffffff",
  },
  files = {},
}

function M.open(opts)
  local path = opts and opts.fargs and opts.fargs[1]

  if not path then
    path = vim.api.nvim_buf_get_name(0)
  end

  if path == "" then
    utils.log("error", "No file specified and current buffer has no file")
    return
  end

  path = vim.fn.fnamemodify(path, ":p")

  if not utils.is_excalidraw_file(path) then
    utils.log("error", "Not an excalidraw file: " .. path)
    return
  end

  if vim.fn.filereadable(path) ~= 1 then
    utils.log("error", "File not found: " .. path)
    return
  end

  server.ensure_running(function()
    local theme = utils.get_theme()
    local debounce = config.options.save_debounce_ms
    local url = string.format(
      "http://%s:%d/?file=%s&theme=%s&debounce=%d",
      config.options.server_host,
      server.port,
      utils.url_encode(path),
      theme,
      debounce
    )
    utils.open_browser(url)
    utils.log("info", "Opened " .. vim.fn.fnamemodify(path, ":t") .. " in browser")
  end)
end

function M.create(opts)
  local path = opts and opts.fargs and opts.fargs[1]

  if not path then
    utils.log("error", "Usage: :ExcalidrawCreate <filename>")
    return
  end

  -- Ensure .excalidraw extension
  if not utils.is_excalidraw_file(path) then
    path = path .. ".excalidraw"
  end

  path = vim.fn.fnamemodify(path, ":p")

  if vim.fn.filereadable(path) == 1 then
    utils.log("warn", "File already exists: " .. path .. ". Opening it instead.")
    M.open({ fargs = { path } })
    return
  end

  -- Write template
  local json = vim.fn.json_encode(EMPTY_TEMPLATE)
  local f = io.open(path, "w")
  if not f then
    utils.log("error", "Cannot create file: " .. path)
    return
  end
  f:write(json)
  f:write("\n")
  f:close()

  utils.log("info", "Created " .. vim.fn.fnamemodify(path, ":t"))

  -- Open in browser
  M.open({ fargs = { path } })
end

function M.status()
  local s = server.status()
  utils.log("info", "Server: " .. s)
end

function M.stop()
  server.stop()
end

return M
