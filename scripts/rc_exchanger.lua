-- rc
local process = require("process")
local shell = require("shell")

local child

local function start()
  if child then return nil, "already running" end
  local pid, reason = process.spawn(function()
    shell.execute("/scripts/exchanger.lua")
  end, nil, "exchanger")
  if not pid then return nil, reason or "spawn failed" end
  child = pid
  return true
end

local function stop()
  if not child then return nil, "not running" end
  process.kill(child)
  process.waitForProcess(child)
  child = nil
  return true
end

local function restart()
  stop()
  return start()
end

local function status()
  return child and "running" or "stopped"
end

return {start = start, stop = stop, restart = restart, status = status}
