--!nonstrict
-- Display Control panel — a Windows-style 4-mode quick switcher (Extend /
-- Duplicate / Laptop only / Screen only) on top of the per-display picker
-- below it, which still lets you extend a specific display in a direction
-- or turn it on/off individually. Niri's `msg output` API has no mirror
-- action and its per-output workspace model rules out faking one with
-- overlapping positions (confirmed against niri's own docs/discussions) —
-- so Duplicate shells out to wl-mirror (a screen-capture app, optional
-- dependency) instead. See modeDuplicate() below for the caveats.

local COMMAND_TIMEOUT_MS = 8000

local snapshot = noctalia.state.get("display_snapshot") or { status = "loading", error_message = "", displays = {} }
local isOpen = false
local selectedPort = nil
local actionPending = false
local actionError = ""
-- Tracks the Duplicate mirror across panel opens/closes (reset only when
-- another mode kills it or the plugin itself reloads).
local mirrorActive = false
local mirrorFrozen = false
-- Keyboard cursor over the list (Up/Down/Return); mouse clicks ignore it.
local cursorIndex = 0
-- Armed by the first tap on the external chip's power badge; a second tap
-- while armed actually disables. Only ever tracks the one draggable display,
-- so a plain boolean is enough.
local confirmingDisable = false

local render

local function quoteShellArgument(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function findDisplay(port)
  for _, d in ipairs(snapshot.displays) do
    if d.port == port then
      return d
    end
  end
  return nil
end

-- The other enabled display to extend against: prefer the focused one.
local function referenceDisplay(excludePort)
  local fallback = nil
  for _, d in ipairs(snapshot.displays) do
    if d.port ~= excludePort and d.enabled then
      if d.focused then
        return d
      end
      fallback = fallback or d
    end
  end
  return fallback
end

local function runNiri(command)
  if actionPending then
    return
  end
  actionPending = true
  actionError = ""
  render()

  local started = noctalia.runAsync(command, function(result)
    actionPending = false
    if result.exitCode ~= 0 then
      local message = noctalia.string.trim(result.stderr or ""):match("^[^\r\n]*") or ""
      actionError = message ~= "" and message or "Command failed."
    else
      noctalia.state.set("refresh_requested", (noctalia.state.get("refresh_requested") or 0) + 1)
    end
    render()
  end, COMMAND_TIMEOUT_MS)
  if not started then
    actionPending = false
    actionError = "Could not run niri msg."
    render()
  end
end

local function extendTargetFrom(target, ref, direction)
  if target == nil or ref == nil then
    actionError = "No other display to extend from."
    render()
    return
  end

  local x, y = ref.x, ref.y
  if direction == "right" then
    x = ref.x + ref.logicalWidth
  elseif direction == "left" then
    x = ref.x - target.logicalWidth
  elseif direction == "below" then
    y = ref.y + ref.logicalHeight
  elseif direction == "above" then
    y = ref.y - target.logicalHeight
  end

  local command = "niri msg output " .. quoteShellArgument(target.port)
    -- clap (niri's CLI parser) reads a leading '-' as a flag, not a negative
    -- number, so a negative X/Y (extending left/above) needs `--` first.
    .. " position set -- " .. tostring(math.floor(x)) .. " " .. tostring(math.floor(y))
  if not target.enabled then
    command = "niri msg output " .. quoteShellArgument(target.port) .. " on && " .. command
  end
  runNiri(command)
end

local function extend(direction)
  extendTargetFrom(findDisplay(selectedPort), referenceDisplay(selectedPort), direction)
end

local function setPowerFor(target, enabled)
  if target == nil then
    return
  end
  runNiri("niri msg output " .. quoteShellArgument(target.port) .. " " .. (enabled and "on" or "off"))
end

local function setPower(enabled)
  setPowerFor(findDisplay(selectedPort), enabled)
end

-- Laptop panel connector prefixes per the DRM/KMS naming convention.
local function isInternalPort(port)
  return port:match("^eDP") ~= nil or port:match("^LVDS") ~= nil or port:match("^DSI") ~= nil
end

local function internalDisplay()
  for _, d in ipairs(snapshot.displays) do
    if isInternalPort(d.port) then
      return d
    end
  end
  return nil
end

-- The external display a quick mode should act on: prefer the focused one.
local function externalDisplay(excludePort)
  local fallback = nil
  for _, d in ipairs(snapshot.displays) do
    if d.port ~= excludePort and not isInternalPort(d.port) then
      if d.focused then
        return d
      end
      fallback = fallback or d
    end
  end
  return fallback
end

-- Which side of the laptop the external display currently sits on, from its
-- real logical position — drives both the canvas layout order and (indirectly,
-- since the layout mirrors reality) what "drag it onto an edge" looks like.
local function relation(internal, external)
  if external.x >= internal.x + internal.logicalWidth then
    return "right"
  elseif external.x + external.logicalWidth <= internal.x then
    return "left"
  elseif external.y >= internal.y + internal.logicalHeight then
    return "below"
  elseif external.y + external.logicalHeight <= internal.y then
    return "above"
  end
  return "right"
end

-- Fit a display's aspect ratio into a small fixed-size chip, independently of
-- the other display's chip — good enough for a 2-display canvas without
-- needing DMS-style joint bounds/scale-factor math.
local function chipSize(display)
  local w = display.logicalWidth > 0 and display.logicalWidth or 1600
  local h = display.logicalHeight > 0 and display.logicalHeight or 900
  local scale = 130 / math.max(w, h)
  return math.max(56, math.floor(w * scale)), math.max(40, math.floor(h * scale))
end

-- The power control for the draggable chip only (per-scope: the laptop panel
-- chip stays plain, nothing asked for a toggle on it). A drag_source has no
-- onClick of its own — the framework gives it a dedicated press/motion/
-- release path straight to the drag controller instead (see chip() below) —
-- so this lives as a small sibling node next to the drag handle, not nested
-- inside it. Tap arms "disable" (shown on the chip itself); tap again to
-- confirm. Turning back on needs no confirmation.
local function powerBadge(display)
  local armed = confirmingDisable
  -- The standard power-button glyph (not the monitor icon the drag handle
  -- already shows right next to it) so the badge actually reads as a power
  -- toggle rather than a second, redundant display icon.
  local glyphName = armed and "alert-triangle" or "power"
  return ui.column({
    width = 28,
    height = 28,
    align = "center",
    justify = "center",
    fill = armed and "on_primary/0.9" or "on_primary/0.18",
    radius = 7,
    onClick = function()
      -- "column" has no enabled prop to gray this out with, so guard here.
      if actionPending then
        return
      end
      if not display.enabled then
        confirmingDisable = false
        setPowerFor(display, true)
        return
      end
      if confirmingDisable then
        confirmingDisable = false
        setPowerFor(display, false)
      else
        confirmingDisable = true
        render()
      end
    end,
  }, { ui.glyph({
    name = glyphName,
    size = 16,
    color = armed and "error" or (display.enabled and "on_primary" or "on_primary/0.55"),
  }) })
end

local function chip(display, draggable, showBadge)
  local w, h = chipSize(display)
  local isInternal = isInternalPort(display.port)
  local showArmed = showBadge and confirmingDisable
  local labelText = showArmed and "Disable?" or (isInternal and "Laptop" or display.port)
  local content = {
    ui.glyph({ name = "device-desktop", size = 22, color = "on_primary" }),
    ui.label({ text = labelText, fontSize = 12, color = "on_primary", maxLines = 1 }),
  }

  if not draggable then
    return ui.column({
      width = w,
      height = h,
      align = "center",
      justify = "center",
      gap = 4,
      fill = display.enabled and "primary/0.8" or "surface_variant/0.5",
      radius = 8,
    }, content)
  end

  -- Both chips drag; whichever one you drop onto an edge zone becomes the
  -- target, positioned relative to whichever chip you didn't drag (see
  -- onCanvasDrop below) — dragging isn't limited to one fixed display.
  local handle = ui.dragSource({
    flexGrow = 1,
    align = "center",
    justify = "center",
    gap = 4,
    dragType = "display",
    payload = display.port,
    tooltip = "Drag onto an edge to reposition",
    enabled = not actionPending,
  }, content)

  if not showBadge then
    return ui.row({
      width = w,
      height = h,
      align = "center",
      justify = "center",
      padding = 6,
      fill = display.enabled and "primary/0.8" or "surface_variant/0.5",
      radius = 8,
    }, { handle })
  end

  return ui.row({
    width = w,
    height = h,
    align = "center",
    justify = "center",
    gap = 6,
    padding = 6,
    fill = showArmed and "error/0.85" or (display.enabled and "primary/0.8" or "surface_variant/0.5"),
    radius = 8,
  }, { handle, powerBadge(display) })
end

-- Shared onDrop for all four edge zones: the zone's own `value` IS the
-- direction, and either chip's payload can be the one dropped — whichever
-- display it is becomes the target, positioned relative to the other one.
local function onCanvasDrop(payload, direction)
  local internal = internalDisplay()
  if internal == nil then
    return
  end
  local external = externalDisplay(internal.port)
  if external == nil then
    return
  end

  local target, ref
  if payload == internal.port then
    target, ref = internal, external
  elseif payload == external.port then
    target, ref = external, internal
  else
    return
  end

  confirmingDisable = false
  extendTargetFrom(target, ref, direction)
end

local function edgeZone(direction, thickness, isVertical)
  local props = {
    accepts = { "display" },
    value = direction,
    onDrop = onCanvasDrop,
    enabled = not actionPending,
    fill = "surface_variant/0.12",
    border = "outline/0.3",
    borderWidth = 1,
    radius = 6,
    -- Without this the framework falls back to pixel-exact hit-testing (0
    -- tolerance) instead of its "closest zone wins" proximity search — with
    -- these zones only as wide/tall as the chip row, a straight drag across
    -- the whole canvas would need to land inside a ~28px strip the entire
    -- way. A generous slop makes whichever edge is nearest the cursor win.
    hitSlop = 72,
  }
  if isVertical then
    props.width = thickness
  else
    props.height = thickness
  end
  return ui.dropZone(props, {})
end

-- To-scale 2-display canvas: laptop chip fixed, external chip draggable onto
-- one of the four edge zones around it. Only meaningful with exactly an
-- internal + external pair, same precondition every quick mode already uses.
local function arrangementCanvas()
  local internal = internalDisplay()
  if internal == nil then
    return nil
  end
  local external = externalDisplay(internal.port)
  if external == nil then
    return nil
  end

  local internalChip = chip(internal, true, false)
  local externalChip = chip(external, true, true)
  local rel = relation(internal, external)
  local pair
  if rel == "left" then
    pair = ui.row({ gap = 12, align = "center", justify = "center" }, { externalChip, internalChip })
  elseif rel == "above" then
    pair = ui.column({ gap = 12, align = "center", justify = "center" }, { externalChip, internalChip })
  elseif rel == "below" then
    pair = ui.column({ gap = 12, align = "center", justify = "center" }, { internalChip, externalChip })
  else
    pair = ui.row({ gap = 12, align = "center", justify = "center" }, { internalChip, externalChip })
  end

  local middleRow = ui.row({ gap = 8, align = "stretch", justify = "center" }, {
    edgeZone("left", 28, true),
    pair,
    edgeZone("right", 28, true),
  })

  return ui.column({ gap = 8, align = "stretch", fill = "surface_variant/0.06", radius = 12, padding = 12 }, {
    edgeZone("above", 28, false),
    middleRow,
    edgeZone("below", 28, false),
    ui.label({
      text = "Drag either display onto an edge to reposition it · tap " .. external.port .. "'s badge to turn it off",
      fontSize = 10,
      color = "on_surface_variant",
      textAlign = "center",
      maxLines = 2,
    }),
  })
end

-- Per-user control FIFO for wl-mirror's --stream mode (it reads lines on
-- stdin as extra CLI options — see `man wl-mirror`, STREAM MODE). A fifo
-- needs a writer held open or reads hit EOF immediately, and wl-mirror
-- itself must not be that writer (--fullscreen-output already implies
-- --stream needs stdin free for options, not double-purposed) — so a
-- second tiny process (`sh -c 'echo $$ >pidfile; exec sleep infinity
-- >fifo'`) holds the write end open forever. It records its own PID (via
-- $$, preserved across exec) to a pidfile so KILL_MIRROR can kill exactly
-- that process — pattern-matching its name doesn't work: `exec -a` only
-- changes argv[0], not the kernel comm field ps/pkill -x actually reads,
-- so it still shows up as a bare "sleep", too generic to pkill safely.
-- $(id -u) below is expanded by the shell that runs this, not by Luau.
local MIRROR_FIFO = "/tmp/dms-wlmirror-ctl-$(id -u)"
local MIRROR_WRITER_PIDFILE = "/tmp/dms-wlmirror-writer-$(id -u).pid"

-- Killed at the start of every mode switch so leaving Duplicate for another
-- mode doesn't leave a stale fullscreen mirror window (or its FIFO-holder)
-- behind. wl-mirror matched by process name (-x, no -f): a full-command-line
-- match would also match the wrapping shell script that runs this very pkill
-- call, since that script's own text contains "wl-mirror" too, and kill its
-- own parent shell mid-run.
local KILL_MIRROR = "pkill -x wl-mirror >/dev/null 2>&1"
  .. "; kill \"$(cat " .. MIRROR_WRITER_PIDFILE .. " 2>/dev/null)\" >/dev/null 2>&1"
  .. "; rm -f " .. MIRROR_WRITER_PIDFILE .. " >/dev/null 2>&1"

local function applyMode(commands)
  if #commands == 0 then
    return
  end
  mirrorActive = false
  mirrorFrozen = false
  runNiri(KILL_MIRROR .. "; " .. table.concat(commands, " && "))
end

-- Writes one option line into the running wl-mirror's --stream FIFO. Not
-- routed through applyMode/KILL_MIRROR — freezing must not kill the mirror
-- it's freezing. `|| true` because a stale/no-op write (mirror already gone)
-- shouldn't surface as a scary error for what's a convenience toggle.
--
-- Freezing specifically also closes this panel first: the mirror captures
-- everything on the laptop screen, panel included, so freezing while it's
-- open would freeze the projector on a screenshot of this very panel. The
-- shell-side `sleep 0.2` (not a Luau timer — simpler to let the already-
-- dispatched shell command wait) gives the close time to actually reach
-- the screen before wl-mirror grabs the frame to hold.
local function toggleFreeze()
  if not mirrorActive then
    return
  end
  mirrorFrozen = not mirrorFrozen
  local flag = mirrorFrozen and "--freeze" or "--unfreeze"
  local delay = ""
  if mirrorFrozen then
    panel.close()
    delay = "sleep 0.2; "
  end
  runNiri(delay .. "echo " .. quoteShellArgument(flag) .. " > " .. MIRROR_FIFO .. " 2>/dev/null || true")
end

local function onCommand(port)
  return "niri msg output " .. quoteShellArgument(port) .. " on"
end

local function offCommand(port)
  return "niri msg output " .. quoteShellArgument(port) .. " off"
end

local function positionCommand(port, x, y)
  -- clap (niri's CLI parser) reads a leading '-' as a flag, not a negative
  -- number, so a negative X/Y needs `--` first (see extendTargetFrom above).
  return "niri msg output " .. quoteShellArgument(port) .. " position set -- " .. tostring(math.floor(x)) .. " " .. tostring(math.floor(y))
end

-- Duplicate's fullscreen wl-mirror window hides whatever real windows were
-- already open on the external output's workspaces underneath it. Leaving
-- Duplicate for another mode kills wl-mirror (KILL_MIRROR) but doesn't
-- reorder what's left behind, so those windows would land back on top,
-- covering the display the user just switched to. Run once, before any
-- on/off/position change, while the output's workspaces are still valid:
-- for every window on that output except wl-mirror itself, focus it and
-- push its column to the end (niri's only "move to bottom" primitive).
-- Verified against the real running niri/jq on this machine.
local function pushExternalWindowsToBottomCommand(externalPort)
  local out = quoteShellArgument(externalPort)
  return "WS_IDS=$(niri msg --json workspaces | jq -c --arg out " .. out .. " '[.[] | select(.output==$out) | .id]'); "
    .. "niri msg --json windows | jq -r --argjson ws \"$WS_IDS\" "
    .. "'.[] | select(.app_id != \"at.yrlf.wl_mirror\") | select(.workspace_id as $w | $ws | index($w) != null) | .id' "
    .. "| while read -r wid; do niri msg action focus-window --id \"$wid\"; niri msg action move-column-to-last; done"
end

local function modeExtend()
  local internal = internalDisplay()
  local external = externalDisplay(internal and internal.port or nil)
  if internal == nil or external == nil then
    actionError = "Need both a laptop screen and an external display for Extend."
    render()
    return
  end
  local commands = {}
  if mirrorActive then
    table.insert(commands, pushExternalWindowsToBottomCommand(external.port))
  end
  table.insert(commands, onCommand(internal.port))
  table.insert(commands, positionCommand(internal.port, 0, 0))
  table.insert(commands, onCommand(external.port))
  table.insert(commands, positionCommand(external.port, internal.logicalWidth, 0))
  applyMode(commands)
end

local function modeLaptopOnly()
  local internal = internalDisplay()
  if internal == nil then
    actionError = "No laptop screen detected."
    render()
    return
  end
  local commands = {}
  if mirrorActive then
    local external = externalDisplay(internal.port)
    if external ~= nil then
      table.insert(commands, pushExternalWindowsToBottomCommand(external.port))
    end
  end
  table.insert(commands, onCommand(internal.port))
  table.insert(commands, positionCommand(internal.port, 0, 0))
  for _, d in ipairs(snapshot.displays) do
    if d.port ~= internal.port then
      table.insert(commands, offCommand(d.port))
    end
  end
  applyMode(commands)
end

local function modeScreenOnly()
  local internal = internalDisplay()
  local external = externalDisplay(internal and internal.port or nil)
  if external == nil then
    actionError = "No external display detected."
    render()
    return
  end
  local commands = {}
  if mirrorActive then
    table.insert(commands, pushExternalWindowsToBottomCommand(external.port))
  end
  table.insert(commands, onCommand(external.port))
  table.insert(commands, positionCommand(external.port, 0, 0))
  for _, d in ipairs(snapshot.displays) do
    if d.port ~= external.port then
      table.insert(commands, offCommand(d.port))
    end
  end
  applyMode(commands)
end

-- Not a compositor-level mirror: niri has no mirror IPC action and can't
-- fake one via overlapping positions (per-output workspaces). Instead this
-- launches wl-mirror, a screen-capture window, fullscreened onto the
-- external output via its own --fullscreen-output flag (no niri window-rule
-- needed — verified it actually goes fullscreen on the target output).
-- Launched with --stream, fed from a FIFO, so toggleFreeze() can pause the
-- projector's image live without killing/relaunching the mirror.
-- Known caveat: wl-mirror is reported to freeze on NVIDIA GPUs when its
-- window loses focus (this machine has one) — if the projector image
-- freezes unintentionally, reopen this panel and hit Duplicate again to
-- relaunch it (distinct from the deliberate Freeze toggle below it).
local function modeDuplicate()
  local internal = internalDisplay()
  local external = externalDisplay(internal and internal.port or nil)
  if internal == nil or external == nil then
    actionError = "Need both a laptop screen and an external display for Duplicate."
    render()
    return
  end
  if not noctalia.commandExists("wl-mirror") then
    actionError = "wl-mirror isn't installed. Run: pacman -S wl-mirror"
    render()
    return
  end
  applyMode({
    onCommand(internal.port),
    onCommand(external.port),
    "niri msg output " .. quoteShellArgument(external.port) .. " position auto",
    "rm -f " .. MIRROR_FIFO .. " " .. MIRROR_WRITER_PIDFILE,
    "mkfifo -m 600 " .. MIRROR_FIFO,
    "(setsid sh -c 'echo $$ > " .. MIRROR_WRITER_PIDFILE .. "; exec sleep infinity > " .. MIRROR_FIFO
      .. "' >/dev/null 2>&1 &)",
    "(setsid wl-mirror --stream --fullscreen-output " .. quoteShellArgument(external.port)
      .. " " .. quoteShellArgument(internal.port) .. " < " .. MIRROR_FIFO .. " >/dev/null 2>&1 &)",
  })
  mirrorActive = true
end

local function actionButton(label, glyph, onClick, variant)
  return ui.button({
    text = label,
    glyph = glyph,
    variant = variant or "secondary",
    enabled = not actionPending,
    onClick = onClick,
  })
end

local function openDetail(port)
  selectedPort = port
  actionError = ""
  render()
end

local function modeButton(label, glyph, onClick)
  return ui.button({
    text = label,
    glyph = glyph,
    variant = "secondary",
    enabled = not actionPending,
    flexGrow = 1,
    onClick = onClick,
  })
end

local function quickModesRow()
  local rows = {
    ui.row({ gap = 8, align = "stretch" }, {
      modeButton("Extend", "arrows-maximize", modeExtend),
      modeButton("Duplicate", "copy", modeDuplicate),
    }),
    ui.row({ gap = 8, align = "stretch" }, {
      modeButton("Laptop only", "device-laptop", modeLaptopOnly),
      modeButton("Screen only", "device-desktop", modeScreenOnly),
    }),
  }
  if mirrorActive then
    table.insert(rows, ui.row({ gap = 8, align = "stretch" }, {
      modeButton(
        mirrorFrozen and "Unfreeze projector" or "Freeze projector",
        mirrorFrozen and "player-play" or "player-pause",
        toggleFreeze
      ),
    }))
  end
  table.insert(rows, ui.separator({}))
  return ui.column({ gap = 8, align = "stretch" }, rows)
end

local function listView()
  local children = { quickModesRow() }
  local canvas = arrangementCanvas()
  if canvas ~= nil then
    table.insert(children, canvas)
  elseif #snapshot.displays == 0 then
    table.insert(children, ui.label({ text = "No displays found.", color = "on_surface_variant" }))
  else
    table.insert(children, ui.label({
      text = "Connect a laptop panel and an external display to arrange them here.",
      color = "on_surface_variant",
      fontSize = 11,
      maxLines = 3,
    }))
  end
  return ui.scroll({ flexGrow = 1, gap = 8, align = "stretch" }, children)
end

local function detailView()
  local display = findDisplay(selectedPort)
  if display == nil then
    selectedPort = nil
    return listView()
  end
  local ref = referenceDisplay(selectedPort)

  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.button({
        glyph = "arrow-left",
        variant = "ghost",
        onClick = function()
          selectedPort = nil
          render()
        end,
      }),
      ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({ text = display.name, fontWeight = "bold", fontSize = 15, color = "on_surface" }),
        ui.label({ text = display.port, fontSize = 11, color = "on_surface_variant" }),
      }),
    }),
  }

  if ref == nil then
    table.insert(children, ui.label({
      text = "Only one display is connected — nothing to extend against.",
      color = "on_surface_variant",
      fontSize = 12,
      maxLines = 3,
    }))
  else
    table.insert(children, ui.label({
      text = "Extend relative to " .. ref.port .. ":",
      fontSize = 12,
      color = "on_surface_variant",
    }))
    table.insert(children, ui.row({ gap = 8, align = "stretch" }, {
      actionButton("Left", "arrow-left", function() extend("left") end),
      actionButton("Right", "arrow-right", function() extend("right") end),
    }))
    table.insert(children, ui.row({ gap = 8, align = "stretch" }, {
      actionButton("Above", "arrow-up", function() extend("above") end),
      actionButton("Below", "arrow-down", function() extend("below") end),
    }))
  end

  table.insert(children, ui.separator({}))
  table.insert(children, actionButton(
    display.enabled and "Disable this display" or "Enable this display",
    display.enabled and "device-desktop-off" or "device-desktop",
    function() setPower(not display.enabled) end,
    display.enabled and "destructive" or "primary"
  ))

  table.insert(children, ui.label({
    text = "Only extend and on/off are available per-display — use the Duplicate quick mode above for mirroring. Changes are temporary and reset on restart.",
    fontSize = 10,
    color = "on_surface_variant",
    maxLines = 3,
  }))

  return ui.column({ flexGrow = 1, gap = 10, align = "stretch" }, children)
end

render = function()
  if not isOpen then
    return
  end

  local content
  if #snapshot.displays == 0 and snapshot.status == "loading" then
    content = ui.label({ text = "Loading displays…", color = "on_surface_variant" })
  elseif #snapshot.displays == 0 and snapshot.status == "error" then
    content = ui.column({ gap = 8, align = "center" }, {
      ui.glyph({ name = "alert-circle", size = 30, color = "error" }),
      ui.label({ text = snapshot.error_message, color = "error", fontSize = 12, maxLines = 3 }),
    })
  elseif selectedPort ~= nil then
    content = detailView()
  else
    content = listView()
  end

  local children = {
    ui.row({ align = "center", gap = 10 }, {
      ui.glyph({ name = "device-desktop", size = 20, color = "primary" }),
      ui.label({ text = "Displays", fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
      ui.button({ glyph = "close", variant = "ghost", onClick = panel.close }),
    }),
  }

  if actionError ~= "" then
    table.insert(children, ui.label({ text = actionError, color = "error", fontSize = 11, maxLines = 3 }))
  end

  table.insert(children, content)

  if #snapshot.displays > 0 then
    table.insert(children, ui.label({
      text = selectedPort == nil
        and "\u{2191}\u{2193} move · Enter select · Esc close"
        or "\u{2191}\u{2193}\u{2190}\u{2192} extend · Enter power · Esc back",
      fontSize = 10,
      color = "on_surface_variant",
      textAlign = "center",
    }))
  end

  panel.render(ui.column({ flexGrow = 1, gap = 10, align = "stretch", padding = 12 }, children))
end

noctalia.state.watch("display_snapshot", function(value)
  if type(value) == "table" then
    snapshot = value
    render()
  end
end)

function onOpen(_context)
  isOpen = true
  actionError = ""
  selectedPort = nil
  cursorIndex = 0
  confirmingDisable = false
  noctalia.state.set("refresh_requested", (noctalia.state.get("refresh_requested") or 0) + 1)
  render()
end

function onClose()
  isOpen = false
  selectedPort = nil
end

-- Keyboard-only flow (capture_keys in plugin.toml): Up/Down move the list
-- cursor, Return opens it; inside a display, the arrow keys ARE the extend
-- directions (Up/Down/Left/Right -> above/below/left/right) and Return
-- toggles power, so nothing here needs typing or a mouse.
function onKey(chord, pressed)
  if not pressed then
    return
  end

  if selectedPort == nil then
    local count = #snapshot.displays
    if chord == "Up" and count > 0 then
      cursorIndex = (cursorIndex - 1) % count
      render()
    elseif chord == "Down" and count > 0 then
      cursorIndex = (cursorIndex + 1) % count
      render()
    elseif chord == "Return" and count > 0 then
      openDetail(snapshot.displays[cursorIndex + 1].port)
    elseif chord == "Escape" then
      panel.close()
    end
    return
  end

  if chord == "Up" then
    extend("above")
  elseif chord == "Down" then
    extend("below")
  elseif chord == "Left" then
    extend("left")
  elseif chord == "Right" then
    extend("right")
  elseif chord == "Return" then
    local display = findDisplay(selectedPort)
    if display ~= nil then
      setPower(not display.enabled)
    end
  elseif chord == "Escape" then
    selectedPort = nil
    render()
  end
end
