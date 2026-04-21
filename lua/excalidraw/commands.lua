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
  local path

  if opts and opts.fargs and opts.fargs[1] then
    path = opts.fargs[1]
  else
    path = utils.get_excalidraw_link_at_cursor()
    if not path then
      path = vim.api.nvim_buf_get_name(0)
    end
  end

  if not path then
    utils.log("error", "No excalidraw file specified and not on a link")
    return
  end

  if not utils.is_excalidraw_file(path) then
    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file ~= "" then
      local dir = vim.fn.fnamemodify(current_file, ":h")
      path = dir .. "/" .. path
    end
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

  server.ensure_running(function(success)
    if not success then
      utils.log("error", "Could not start server")
      return
    end
    local theme = utils.get_theme()
    local debounce = config.get().save_debounce_ms
    local lib_path = utils.get_library_path()
    local library_param = lib_path and "&library=" .. utils.url_encode(lib_path) or ""
    local url = string.format(
      "http://%s:%d/?file=%s&theme=%s&debounce=%d%s",
      config.get().server_host,
      server.port,
      utils.url_encode(path),
      theme,
      debounce,
      library_param
    )
    utils.open_browser(url)
    utils.log("info", "Opened " .. vim.fn.fnamemodify(path, ":t") .. " in browser")
  end)
end

function M.create(opts)
  local name = opts and opts.fargs and opts.fargs[1]

  if not name or name == "" then
    vim.ui.input({ prompt = "Excalidraw file name: " }, function(input)
      if not input or input == "" then return end
      M._do_create(input)
    end)
  else
    M._do_create(name)
  end
end

function M._do_create(name)
  if not utils.is_excalidraw_file(name) then
    name = name .. ".excalidraw"
  end

  local path, err = utils.get_assets_path(name)
  if not path then
    utils.log("error", err)
    return
  end

  path = vim.fn.fnamemodify(path, ":p")

  if vim.fn.filereadable(path) == 1 then
    utils.log("warn", "File already exists: " .. path .. ". Opening it instead.")
    M._insert_link_and_open(path, name)
    return
  end

  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local json = vim.fn.json_encode(EMPTY_TEMPLATE)
  local lines = { json, "" }
  local result = vim.fn.writefile(lines, path)
  if result == -1 then
    utils.log("error", "Cannot create file: " .. path)
    return
  end

  utils.log("info", "Created " .. vim.fn.fnamemodify(path, ":t"))

  M._insert_link_and_open(path, name)
end

function M._insert_link_and_open(path, name)
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file ~= "" then
    local dir = vim.fn.fnamemodify(current_file, ":h")
    local rel = vim.fn.fnamemodify(path, ":~:.")
    local display_name = name:gsub("%.excalidraw$", "")
    local link = string.format("[%s](%s)", display_name, rel)
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
    local new_line = line:sub(1, col) .. link .. line:sub(col + 1)
    vim.api.nvim_buf_set_lines(0, row, row + 1, false, { new_line })
    vim.api.nvim_win_set_cursor(0, { row + 1, col + #link })
  end

  M.open({ fargs = { path } })
end

function M.status()
  local s = server.status()
  utils.log("info", "Server: " .. s)
  return s
end

function M.stop()
  server.stop()
end

return M
