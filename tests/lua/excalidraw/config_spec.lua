-- Tests for lua/excalidraw/config.lua
-- Run with: nvim --headless -c "PlenaryBustedDirectory tests/lua"

local config = require("excalidraw.config")

describe("config", function()
  -- Reset config to defaults before each test
  before_each(function()
    config.setup({})
  end)

  describe("defaults", function()
    it("has auto_open enabled by default", function()
      assert.is_true(config.defaults.auto_open)
    end)

    it("has auto theme by default", function()
      assert.equal("auto", config.defaults.theme)
    end)

    it("has python3 as default python path", function()
      assert.equal("python3", config.defaults.python_path)
    end)

    it("has localhost as default host", function()
      assert.equal("127.0.0.1", config.defaults.server_host)
    end)

    it("has port 0 (random) by default", function()
      assert.equal(0, config.defaults.server_port)
    end)

    it("has 1000ms debounce by default", function()
      assert.equal(1000, config.defaults.save_debounce_ms)
    end)

    it("has nil browser_command by default", function()
      assert.is_nil(config.defaults.browser_command)
    end)

    it("has info log level by default", function()
      assert.equal("info", config.defaults.log_level)
    end)
  end)

  describe("setup", function()
    it("uses defaults when called with empty table", function()
      config.setup({})
      assert.equal("auto", config.options.theme)
      assert.is_true(config.options.auto_open)
    end)

    it("uses defaults when called with nil", function()
      config.setup(nil)
      assert.equal("auto", config.options.theme)
    end)

    it("overrides single option", function()
      config.setup({ theme = "dark" })
      assert.equal("dark", config.options.theme)
      -- Other defaults should remain
      assert.is_true(config.options.auto_open)
    end)

    it("overrides multiple options", function()
      config.setup({
        theme = "light",
        auto_open = false,
        log_level = "debug",
      })
      assert.equal("light", config.options.theme)
      assert.is_false(config.options.auto_open)
      assert.equal("debug", config.options.log_level)
    end)

    it("does not mutate defaults table", function()
      config.setup({ theme = "dark", auto_open = false })
      assert.equal("auto", config.defaults.theme)
      assert.is_true(config.defaults.auto_open)
    end)

    it("can override server port", function()
      config.setup({ server_port = 8080 })
      assert.equal(8080, config.options.server_port)
    end)

    it("can set browser command", function()
      config.setup({ browser_command = "firefox" })
      assert.equal("firefox", config.options.browser_command)
    end)

    it("has nil library_path by default", function()
      assert.is_nil(config.defaults.library_path)
    end)

    it("can set library_path", function()
      config.setup({ library_path = "~/my-library.excalidrawlib" })
      assert.equal("~/my-library.excalidrawlib", config.options.library_path)
    end)

    it("resets properly on re-setup", function()
      config.setup({ theme = "dark" })
      assert.equal("dark", config.options.theme)

      config.setup({})
      assert.equal("auto", config.options.theme)
    end)
  end)
end)
