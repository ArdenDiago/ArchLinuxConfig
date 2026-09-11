--!nonstrict
-- Display Control bar widget — icon that opens the panel.

local function render()
  barWidget.render(ui.glyph({ name = "device-desktop", size = 16, color = "on_surface" }))
end

render()

function update()
  noctalia.setUpdateInterval(5000)
end

function onClick()
  noctalia.togglePanel("arden/display-control:panel")
end
