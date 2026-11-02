--!nonstrict
-- Owns the codeburn-rs process. Bar and panel only render noctalia.state "view".
-- Commands arrive on "cmd" as "<nonce>|<refresh|period>|<payload>".

local refreshing = false
local periodOverride = nil

local function configuredPeriod()
  local value = noctalia.getConfig("period")
  if value == "week" or value == "30days" or value == "month" or value == "all" or value == "today" then
    return value
  end
  return "today"
end

local function binary()
  local configured = noctalia.getConfig("binary")
  if type(configured) == "string" and configured ~= "" then
    return noctalia.expandPath(configured)
  end
  if noctalia.commandExists("codeburn-rs") then
    return "codeburn-rs"
  end
  local cargo = noctalia.expandPath("~/.cargo/bin/codeburn-rs")
  if noctalia.fileExists(cargo) then
    return cargo
  end
  return nil
end

local function publish(view)
  local encoded = noctalia.json.encode(view)
  if encoded ~= nil then
    noctalia.state.set("view", encoded)
  end
end

local function refresh()
  if refreshing then
    return
  end
  local bin = binary()
  if bin == nil then
    publish({ ok = false, error = "missing" })
    return
  end
  refreshing = true
  local period = periodOverride or configuredPeriod()
  local started = noctalia.runAsync({
    bin,
    "status",
    "--format",
    "menubar-json",
    "--period",
    period,
  }, function(result)
    refreshing = false
    if result.timedOut then
      publish({ ok = false, error = "timeout" })
      return
    end
    if result.exitCode ~= 0 then
      publish({
        ok = false,
        error = "exit",
        detail = noctalia.string.trim(result.stderr or ""),
      })
      return
    end
    local decoded = noctalia.json.decode(result.stdout)
    if type(decoded) ~= "table" or type(decoded.current) ~= "table" then
      publish({ ok = false, error = "json" })
      return
    end
    decoded.ok = true
    publish(decoded)
  end, 60000)
  if not started then
    refreshing = false
    publish({ ok = false, error = "spawn" })
  end
end

local function onCommand(value)
  if type(value) ~= "string" then
    return
  end
  local cmd, payload = string.match(value, "^%d+|([^|]+)|(.*)$")
  if cmd == "refresh" then
    refresh()
  elseif cmd == "period" then
    if payload == "today" or payload == "week" or payload == "30days" or payload == "month" or payload == "all" then
      periodOverride = payload
      refresh()
    end
  end
end

function update()
  refresh()
end

function onConfigChanged()
  local secs = tonumber(noctalia.getConfig("refresh_sec")) or 60
  noctalia.setUpdateInterval(math.max(15, secs) * 1000)
  periodOverride = nil
  refresh()
end

noctalia.state.watch("cmd", onCommand)

local secs = tonumber(noctalia.getConfig("refresh_sec")) or 60
noctalia.setUpdateInterval(math.max(15, secs) * 1000)
refresh()
