--!nonstrict
-- Countdown timer desktop widget — the reference [[desktop_widget]] entry.
--
-- Desktop widgets describe their UI declaratively: build a tree with the ui.*
-- constructors and hand it to desktopWidget.render(). The host diffs the tree
-- against the previous one and updates the retained native controls, so calling
-- render() with an unchanged tree is free.
--
--   desktopWidget.render(tree)            replace the widget's UI tree
--   desktopWidget.setWantsSecondTicks(b)  tick update() on second boundaries
--   desktopWidget.getConfig(key)          settings (seeded from the manifest)
--   button onClick = "name"               calls the plugin global of that name

local duration = desktopWidget.getConfig("duration")
local color = desktopWidget.getConfig("color")
local showProgress = desktopWidget.getConfig("show_progress")

noctalia.setUpdateInterval(100)

local remaining = duration
local running = false
local deadline = 0 -- os.clock() timestamp when the countdown hits zero

local function formatTime(seconds)
  local m = seconds // 60
  local s = seconds % 60
  if m >= 60 then -- hours
    return `{m // 60}:{string.format("%02d", m % 60)}:{string.format("%02d", s)}`
  end
  return `{m}:{string.format("%02d", s)}`
end

local function render()
  -- timer label
  local rows = {
    ui.row({align="center", justify="center"}, {
      if not running then ui.button({
        variant = "ghost",
        glyph = "minus",
        glyphSize = 18,
        color = "on_surface",
        onClick = "minus60",
        onRightClick = "minus10",
      }) else nil,

      ui.label({
        text = formatTime(remaining),
        fontSize = 34,
        fontWeight = "bold",
        color = remaining == 0 and "error" or color,
      }),

      if not running then ui.button({
        variant = "ghost",
        glyph = "plus",
        glyphSize = 18,
        color = "on_surface",
        onClick = "plus60",
        onRightClick = "plus10",
      }) else nil,
    })
  }

  if showProgress then
    table.insert(rows, ui.progress({
      progress = duration > 0 and remaining / duration or 0,
      fill = color,
      width = 160,
      height = 6,
      radius = 3,
    }))
  end

  table.insert(rows, ui.row({ gap = 8 }, {
    ui.button({
      text = running and "Pause" or "Start",
      variant = "primary",
      onClick = "toggleTimer",
    }),
    ui.button({
      text = "Reset",
      variant = "outline",
      onClick = "resetTimer",
    }),
  }))

  desktopWidget.render(ui.column({ gap = 10, align = "center" }, rows))
end

function update()
  desktopWidget.setWantsSecondTicks(true)
  if running then
    remaining = math.max(0, deadline - os.clock())
    if remaining == 0 then
      running = false
      noctalia.notify("Timer", `Time's up — {formatTime(duration)} elapsed`)
    end
  end
  render()
end

function toggleTimer()
  if remaining == 0 then
    remaining = duration
  end
  running = not running
  if running then
    deadline = os.clock() + remaining
  end
  render()
end

function resetTimer()
  running = false
  remaining = duration
  render()
end

function changeTimer(delta)
  duration = math.max(0, duration + delta)
  remaining = math.max(0, remaining + delta)
end

function minus10()
  changeTimer(-10)
end

function minus60()
  changeTimer(-60)
end

function plus10()
  changeTimer(10)
end

function plus60()
  changeTimer(60)
end
