--!nonstrict
-- Display Control — headless service. Polls Niri's JSON IPC for connected
-- outputs (on and off) and publishes a normalized snapshot for the bar
-- widget and panel. Adapted from the community niri-displays plugin's
-- service, trimmed to just what position/power control needs.

local STATE_KEY = "display_snapshot"
local FALLBACK_INTERVAL_S = 30
local FOCUS_CHECK_INTERVAL_MS = 100
local COMMAND_TIMEOUT_MS = 5000

local fetching = false
local refreshQueued = false
local generation = 0
local lastFullRefreshAt = 0

local function initialSnapshot(status, message)
  return { status = status, error_message = message, focused_output = nil, displays = {} }
end

local function displayLabel(output, connector)
  local make = noctalia.string.trim(output.make or "")
  local model = noctalia.string.trim(output.model or "")
  if make ~= "" and model ~= "" then
    return make .. " " .. model
  elseif model ~= "" then
    return model
  elseif make ~= "" then
    return make
  end
  return connector
end

local function normalizeOutputs(rawOutputs, focusedName)
  local displays = {}
  for connector, raw in pairs(rawOutputs) do
    if type(raw) == "table" then
      local logical = type(raw.logical) == "table" and raw.logical or nil
      local modes = raw.modes or {}
      local currentIndex = tonumber(raw.current_mode)
      local currentMode = currentIndex ~= nil and modes[currentIndex + 1] or nil
      local width = currentMode and tonumber(currentMode.width) or 0
      local height = currentMode and tonumber(currentMode.height) or 0
      local scale = logical and (tonumber(logical.scale) or 1) or 1
      table.insert(displays, {
        name = displayLabel(raw, connector),
        port = connector,
        focused = connector == focusedName,
        enabled = logical ~= nil,
        x = logical and (tonumber(logical.x) or 0) or 0,
        y = logical and (tonumber(logical.y) or 0) or 0,
        scale = scale,
        logicalWidth = scale > 0 and (width / scale) or width,
        logicalHeight = scale > 0 and (height / scale) or height,
      })
    end
  end

  table.sort(displays, function(a, b)
    if a.enabled ~= b.enabled then
      return a.enabled
    end
    return a.port < b.port
  end)

  return {
    status = "ok",
    error_message = "",
    focused_output = focusedName,
    displays = displays,
    updated_at = noctalia.formatTime("%H:%M:%S"),
  }
end

local function commandError(result, fallback)
  if result.timedOut then
    return "Command timed out."
  end
  local message = noctalia.string.trim(result.stderr or ""):match("^[^\r\n]*") or ""
  return message ~= "" and message or fallback
end

local startRefresh
startRefresh = function()
  if fetching then
    refreshQueued = true
    return
  end
  if not noctalia.commandExists("niri") then
    noctalia.state.set(STATE_KEY, initialSnapshot("error", "niri is not on PATH."))
    return
  end

  fetching = true
  lastFullRefreshAt = tonumber(noctalia.formatTime("%s")) or 0
  generation += 1
  local thisGeneration = generation
  local pending = 2
  local rawOutputs, focusedName, outputsError = nil, nil, ""

  local function completeOne()
    if thisGeneration ~= generation then
      return
    end
    pending -= 1
    if pending > 0 then
      return
    end

    fetching = false
    if rawOutputs == nil then
      noctalia.state.set(STATE_KEY, initialSnapshot("error", outputsError ~= "" and outputsError or "Could not list outputs."))
    else
      noctalia.state.set(STATE_KEY, normalizeOutputs(rawOutputs, focusedName))
    end

    if refreshQueued then
      refreshQueued = false
      startRefresh()
    end
  end

  local outputsStarted = noctalia.runAsync("niri msg --json outputs", function(result)
    if thisGeneration ~= generation then
      return
    end
    if result.exitCode == 0 and not result.stdoutTruncated then
      local decoded = noctalia.json.decode(result.stdout or "")
      if type(decoded) == "table" then
        rawOutputs = decoded
      else
        outputsError = "Could not parse niri output list."
      end
    else
      outputsError = commandError(result, "Could not list outputs.")
    end
    completeOne()
  end, COMMAND_TIMEOUT_MS)
  if not outputsStarted then
    outputsError = "Could not list outputs."
    completeOne()
  end

  local focusStarted = noctalia.runAsync("niri msg --json focused-output", function(result)
    if thisGeneration ~= generation then
      return
    end
    if result.exitCode == 0 and not result.stdoutTruncated then
      local decoded = noctalia.json.decode(result.stdout or "")
      if type(decoded) == "table" and type(decoded.name) == "string" then
        focusedName = decoded.name
      end
    end
    completeOne()
  end, COMMAND_TIMEOUT_MS)
  if not focusStarted then
    completeOne()
  end
end

noctalia.setUpdateInterval(FOCUS_CHECK_INTERVAL_MS)
noctalia.state.set(STATE_KEY, initialSnapshot("loading", ""))
startRefresh()

function update()
  if (tonumber(noctalia.formatTime("%s")) or 0) - lastFullRefreshAt >= FALLBACK_INTERVAL_S then
    startRefresh()
  end
end

-- Native Noctalia hook: Niri hotplug/mode/scale changes propagate through
-- wl_output and arrive here without waiting for the fallback poll.
function onOutputsChanged()
  startRefresh()
end

noctalia.state.watch("refresh_requested", function()
  startRefresh()
end)
