local M = {}

M.defaults = {
  auto_open = true,
  theme = "auto",
  python_path = "python3",
  server_host = "127.0.0.1",
  server_port = 0,
  save_debounce_ms = 1000,
  server_timeout_min = 15,
  browser_command = nil,
  log_level = "info",
  library_path = nil,
  assets_dir = "assets",
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
