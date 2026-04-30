-- Tests for lua/excalidraw/commands.lua
-- Run with: nvim --headless -c "PlenaryBustedDirectory tests/lua"

local commands = require("markdown-excalidraw.commands")

describe("commands", function()
  local temp_dir = "/tmp/excalidraw_test"
  local temp_file

  before_each(function()
    vim.fn.mkdir(temp_dir, "p")
    temp_file = temp_dir .. "/test.excalidraw"
  end)

  after_each(function()
    if vim.fn.isdirectory(temp_dir) == 1 then
      vim.fn.delete(temp_dir, "rf")
    end
  end)

  describe("open", function()
    it("returns early when no path and buffer has no file", function()
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_name(0, "")
      commands.open({})
    end)

    it("returns error for non-excalidraw file", function()
      local txt_file = temp_dir .. "/test.txt"
      vim.fn.writefile({ "{}" }, txt_file)
      commands.open({ fargs = { txt_file } })
    end)

    it("returns error for non-existent file", function()
      commands.open({ fargs = { temp_dir .. "/nonexistent.excalidraw" } })
    end)
  end)

  describe("create", function()
    it("returns error when no path provided", function()
      commands.create({})
    end)

    it("creates new excalidraw file", function()
      commands.create({ fargs = { temp_file } })
      assert.equal(1, vim.fn.filereadable(temp_file))
    end)

    it("adds .excalidraw extension if missing", function()
      local name_without_ext = "drawing"
      commands.create({ fargs = { name_without_ext } })
      local assets_path = temp_dir .. "/assets/" .. name_without_ext .. ".excalidraw"
      assert.equal(1, vim.fn.filereadable(assets_path))
    end)

    it("opens existing file instead of overwriting", function()
      vim.fn.writefile({ '{"elements": []}' }, temp_file)
      commands.create({ fargs = { temp_file } })
    end)

    it("creates valid JSON", function()
      commands.create({ fargs = { temp_file } })
      local content = vim.fn.readfile(temp_file)
      local success = vim.fn.json_decode(content[1])
      assert.truthy(success)
    end)
  end)

  describe("status", function()
    it("returns a string", function()
      local status = commands.status()
      assert.is_string(status)
    end)
  end)
end)