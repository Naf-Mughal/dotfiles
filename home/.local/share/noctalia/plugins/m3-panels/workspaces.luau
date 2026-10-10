--!nonstrict
-- Workspaces as an M3 Expressive page indicator: the active workspace is a
-- long numbered pill, the others are dots (dark when they hold windows, faint
-- when empty). Same look as Noctalia's focus_hint style, but with dots twice
-- its size, which that style can't do. Fed live by `umbriel subscribe
-- workspaces`; click a dot to switch (scrolling is bound in config).

local PILL = 23          -- pill thickness
local ACTIVE_LEN = 60    -- active pill length along the bar
local DOT = 12           -- inactive dot (Noctalia draws ~6)

local workspaces = {}
local output = nil

local function apply(list)
  if type(list) ~= "table" then
    return
  end
  output = output or barWidget.outputName()
  local mine = {}
  for _, w in ipairs(list) do
    if output == nil or w.output == output then
      table.insert(mine, w)
    end
  end
  table.sort(mine, function(a, b)
    return (a.index or 0) < (b.index or 0)
  end)
  workspaces = mine
end

local function switch(w)
  noctalia.runAsync({ "umbriel", "msg", "workspace-switch:" .. tostring(w.name or w.index) })
end

local function render()
  local items = {}
  for _, w in ipairs(workspaces) do
    if w.active then
      table.insert(items, ui.column({
        key = "w" .. tostring(w.index),
        width = PILL,
        height = ACTIVE_LEN,
        radius = PILL / 2,
        fill = "on_primary",
        align = "center",
        justify = "center",
      }, {
        ui.label({ text = tostring(w.name or w.index), fontSize = 12, fontWeight = "bold", color = "primary" }),
      }))
    else
      -- Full-size slot so the dot is easy to hit; the dot sits centred in it.
      table.insert(items, ui.column({
        key = "w" .. tostring(w.index),
        width = PILL,
        height = PILL,
        align = "center",
        justify = "center",
        onClick = function()
          switch(w)
        end,
      }, {
        ui.box({ width = DOT, height = DOT, radius = DOT / 2, fill = if w.occupied then "on_primary" else "outline" }),
      }))
    end
  end
  -- The bar lays the root out along its own axis; the inner column stacks.
  barWidget.render(ui.row({ align = "center", justify = "center" }, {
    ui.column({ gap = 2, align = "center" }, items),
  }))
end


noctalia.runAsync({ "umbriel", "workspaces", "--json" }, function(r)
  apply(noctalia.json.decode(r.stdout or ""))
  render()
end)

noctalia.runStream("umbriel subscribe workspaces", function(line)
  local ev = noctalia.json.decode(line)
  if type(ev) == "table" and ev.event == "workspaces" then
    apply(ev.data)
    render()
  end
end)

render()
noctalia.setUpdateInterval(600000)
