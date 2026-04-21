-- Tests for lua/excalidraw/utils.lua
-- Run with: nvim --headless -c "PlenaryBustedDirectory tests/lua"

local utils = require("excalidraw.utils")

describe("utils", function()
  describe("url_encode", function()
    it("leaves alphanumeric characters unchanged", function()
      assert.equal("hello123", utils.url_encode("hello123"))
    end)

    it("encodes spaces", function()
      assert.equal("%20", utils.url_encode(" "))
      assert.equal("hello%20world", utils.url_encode("hello world"))
    end)

    it("preserves slashes", function()
      assert.equal("/home/user/file", utils.url_encode("/home/user/file"))
    end)

    it("preserves hyphens, dots, underscores, tildes", function()
      assert.equal("a-b.c_d~e", utils.url_encode("a-b.c_d~e"))
    end)

    it("encodes special characters", function()
      assert.equal("%40", utils.url_encode("@"))
      assert.equal("%23", utils.url_encode("#"))
      assert.equal("%3F", utils.url_encode("?"))
      assert.equal("%3D", utils.url_encode("="))
      assert.equal("%26", utils.url_encode("&"))
    end)

    it("encodes a full file path with spaces", function()
      local input = "/home/user/my drawings/file.excalidraw"
      local expected = "/home/user/my%20drawings/file.excalidraw"
      assert.equal(expected, utils.url_encode(input))
    end)

    it("handles empty string", function()
      assert.equal("", utils.url_encode(""))
    end)

    it("encodes colons", function()
      assert.equal("C%3A/Users", utils.url_encode("C:/Users"))
    end)
  end)

  describe("is_excalidraw_file", function()
    it("accepts .excalidraw extension", function()
      assert.truthy(utils.is_excalidraw_file("drawing.excalidraw"))
    end)

    it("accepts .excalidraw.json extension", function()
      assert.truthy(utils.is_excalidraw_file("drawing.excalidraw.json"))
    end)

    it("accepts full path with .excalidraw", function()
      assert.truthy(utils.is_excalidraw_file("/home/user/drawing.excalidraw"))
    end)

    it("accepts full path with .excalidraw.json", function()
      assert.truthy(utils.is_excalidraw_file("/home/user/drawing.excalidraw.json"))
    end)

    it("rejects plain .json", function()
      assert.is_falsy(utils.is_excalidraw_file("data.json"))
    end)

    it("rejects .txt", function()
      assert.is_falsy(utils.is_excalidraw_file("notes.txt"))
    end)

    it("rejects no extension", function()
      assert.is_falsy(utils.is_excalidraw_file("drawing"))
    end)

    it("rejects partial extension", function()
      assert.is_falsy(utils.is_excalidraw_file("file.excalidra"))
    end)

    it("rejects .excalidraw in directory name only", function()
      assert.is_falsy(utils.is_excalidraw_file("/home/.excalidraw/config.txt"))
    end)
  end)

  describe("get_theme", function()
    local config = require("excalidraw.config")
    local original_options

    before_each(function()
      config.setup({})
      original_options = vim.deepcopy(config.get())
    end)

    after_each(function()
      config.setup(original_options)
    end)

    it("returns 'dark' when theme is auto and background is dark", function()
      config.setup({ theme = "auto" })
      vim.o.background = "dark"
      assert.equal("dark", utils.get_theme())
    end)

    it("returns 'light' when theme is auto and background is light", function()
      config.setup({ theme = "auto" })
      vim.o.background = "light"
      assert.equal("light", utils.get_theme())
    end)

    it("returns explicit theme when set to 'dark'", function()
      config.setup({ theme = "dark" })
      assert.equal("dark", utils.get_theme())
    end)

    it("returns explicit theme when set to 'light'", function()
      config.setup({ theme = "light" })
      assert.equal("light", utils.get_theme())
    end)
  end)

  describe("log", function()
    local config = require("excalidraw.config")
    local notifications

    before_each(function()
      config.setup({})
      notifications = {}
      -- Stub vim.notify to capture calls
      _G._original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end
    end)

    after_each(function()
      vim.notify = _G._original_notify
    end)

    it("shows error messages at info log level", function()
      config.setup({ log_level = "info" })
      utils.log("error", "something broke")
      assert.equal(1, #notifications)
      assert.equal(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("shows info messages at info log level", function()
      config.setup({ log_level = "info" })
      utils.log("info", "all good")
      assert.equal(1, #notifications)
    end)

    it("suppresses debug messages at info log level", function()
      config.setup({ log_level = "info" })
      utils.log("debug", "verbose stuff")
      assert.equal(0, #notifications)
    end)

    it("shows debug messages at debug log level", function()
      config.setup({ log_level = "debug" })
      utils.log("debug", "verbose stuff")
      assert.equal(1, #notifications)
      assert.equal(vim.log.levels.DEBUG, notifications[1].level)
    end)

    it("suppresses info messages at error log level", function()
      config.setup({ log_level = "error" })
      utils.log("info", "just info")
      assert.equal(0, #notifications)
    end)

    it("prefixes messages with [excalidraw]", function()
      config.setup({ log_level = "info" })
      utils.log("info", "test message")
      assert.truthy(notifications[1].msg:find("%[excalidraw%]"))
    end)
  end)

  describe("plugin_root", function()
    it("returns a path ending with the project directory", function()
      local root = utils.plugin_root()
      assert.truthy(root)
      assert.is_string(root)
      -- Should contain the server directory
      local server_dir = root .. "/server"
      assert.equal(1, vim.fn.isdirectory(server_dir))
    end)
  end)

  describe("expand_path", function()
    it("returns path unchanged if no tilde", function()
      assert.equal("/home/user/file", utils.expand_path("/home/user/file"))
    end)

    it("returns empty string for empty input", function()
      assert.equal("", utils.expand_path(""))
    end)

    it("expands tilde to home directory", function()
      local ok, home = pcall(vim.fn.stdpath, "home")
      if ok and home then
        local result = utils.expand_path("~/test")
        assert.equal(home .. "/test", result)
      end
    end)
  end)

  describe("get_library_path", function()
    local config = require("excalidraw.config")

    before_each(function()
      config.setup({})
    end)

    it("returns nil when library_path is nil and no home", function()
      config.setup({ library_path = nil })
      local result = utils.get_library_path()
      if not vim.env.HOME then
        assert.is_nil(result)
      end
    end)

    it("returns configured library_path", function()
      config.setup({ library_path = "~/my-lib.excalidrawlib" })
      local result = utils.get_library_path()
      local ok, home = pcall(vim.fn.stdpath, "home")
      if ok and home then
        assert.equal(home .. "/my-lib.excalidrawlib", result)
      end
    end)
  end)
end)
