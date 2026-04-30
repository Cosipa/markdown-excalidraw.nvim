-- Tests for lua/excalidraw/server.lua
-- Run with: nvim --headless -c "PlenaryBustedDirectory tests/lua"

local server = require("markdown-excalidraw.server")

describe("server", function()
  -- Reset server state before each test
  before_each(function()
    server.job_id = nil
    server.port = nil
    server.state = "STOPPED"
  end)

  describe("is_running", function()
    it("returns false when stopped", function()
      assert.is_false(server.is_running())
    end)

    it("returns false when starting", function()
      server.state = "STARTING"
      assert.is_false(server.is_running())
    end)

    it("returns false when running but no job_id", function()
      server.state = "RUNNING"
      server.job_id = nil
      assert.is_false(server.is_running())
    end)

    it("returns true when running with job_id", function()
      server.state = "RUNNING"
      server.job_id = 42
      assert.is_true(server.is_running())
    end)
  end)

  describe("status", function()
    it("returns STOPPED when stopped", function()
      assert.equal("STOPPED", server.status())
    end)

    it("returns STARTING when starting", function()
      server.state = "STARTING"
      assert.equal("STARTING", server.status())
    end)

    it("returns running with port when running", function()
      server.state = "RUNNING"
      server.port = 8080
      assert.equal("RUNNING on port 8080", server.status())
    end)

    it("returns running with ? when port is nil", function()
      server.state = "RUNNING"
      server.port = nil
      assert.equal("RUNNING on port ?", server.status())
    end)
  end)

  describe("stop", function()
    it("does nothing when no job_id", function()
      -- Should not error
      server.stop()
      assert.equal("STOPPED", server.state)
    end)

    it("does not clear state when job_id is nil", function()
      -- server.stop() is guarded by job_id; without it, state is unchanged
      server.state = "RUNNING"
      server.port = 9999
      server.job_id = nil
      server.stop()
      -- stop() requires job_id to act, so state remains
      assert.equal("RUNNING", server.state)
    end)
  end)

  describe("initial state", function()
    it("starts with STOPPED state", function()
      -- After the before_each reset
      assert.equal("STOPPED", server.state)
    end)

    it("starts with nil port", function()
      assert.is_nil(server.port)
    end)

    it("starts with nil job_id", function()
      assert.is_nil(server.job_id)
    end)
  end)
end)
