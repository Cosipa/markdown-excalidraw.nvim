-- Minimal init for running tests with plenary.nvim
-- This file sets up the runtime path so tests can find the plugin modules.

local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 0 then
  -- Try common plugin manager locations
  local alternatives = {
    vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim",
    vim.fn.stdpath("data") .. "/site/pack/test/start/plenary.nvim",
    vim.fn.stdpath("data") .. "/plugged/plenary.nvim",
  }
  for _, path in ipairs(alternatives) do
    if vim.fn.isdirectory(path) == 1 then
      plenary_path = path
      break
    end
  end
end

vim.opt.rtp:append(plenary_path)
vim.opt.rtp:append(".")

vim.cmd("runtime plugin/plenary.vim")
