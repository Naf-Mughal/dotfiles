--!nonstrict
-- Bar widget that seals the cave (locks with Cave Abode).

local glyph = noctalia.getConfig("glyph")

local function render()
  barWidget.setGlyph(glyph)
  barWidget.setTooltip(noctalia.tr("tooltip"))
end

function update()
  render()
end

function onClick()
  noctalia.runAsync({ noctalia.pluginDir() .. "/bin/cave-abode-lock" })
end

render()
