--!nonstrict
-- Shared Material 3 Expressive pieces for every panel in this plugin. Same
-- language as the edges action center: tonal layers drawn as light overlays of
-- the text colour, round icon buttons that morph into wider rounded squares in
-- the accent when on, pill sliders, and inner tiles for list items.

local M = {}

M.CARD = "on_surface/0.05"
M.TILE = "on_surface/0.06"
M.IDLE = "on_surface/0.09"
M.R_CARD = 28
M.R_TILE = 20

function M.msg(...)
  local argv = { "noctalia", "msg" }
  for _, a in ipairs({ ... }) do
    table.insert(argv, a)
  end
  return argv
end

function M.isOn(v)
  return v == "on" or v == "true" or v == "enabled" or v == "yes"
end

function M.cap(s)
  s = tostring(s or "")
  return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

-- Rounded-square badge with a glyph; `tone` is a palette role.
function M.badge(glyph, tone, size)
  tone = tone or "primary"
  size = size or 44
  return ui.row({
    width = size,
    height = size,
    radius = math.floor(size * 0.36),
    fill = tone .. "/0.18",
    align = "center",
    justify = "center",
  }, {
    ui.glyph({ name = glyph, size = math.floor(size * 0.46), color = tone }),
  })
end

-- Panel header: badge · title over subtitle · trailing controls.
function M.header(glyph, title, subtitle, trailing, tone)
  local row = {
    M.badge(glyph, tone),
    ui.column({ gap = 1, flexGrow = 1 }, {
      ui.label({ text = title, fontSize = 20, fontWeight = "bold", maxLines = 1 }),
      ui.label({ text = subtitle or "", fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
    }),
  }
  for _, t in ipairs(trailing or {}) do
    table.insert(row, t)
  end
  return ui.row({ gap = 12, align = "center", paddingH = 4 }, row)
end

function M.card(key, children, opts)
  opts = opts or {}
  return ui.column({
    key = key,
    gap = opts.gap or 10,
    padding = opts.padding or 14,
    radius = opts.radius or M.R_CARD,
    fill = opts.fill or M.CARD,
    flexGrow = opts.grow,
  }, children)
end

function M.section(text, trailing)
  local row = {
    ui.label({ text = text, fontSize = 12, fontWeight = "semibold", color = "primary", flexGrow = 1 }),
  }
  if trailing then
    table.insert(row, trailing)
  end
  return ui.row({ align = "center", paddingH = 6, height = 22 }, row)
end

-- Icon button: tonal circle idle, wide accent squircle when active.
function M.circle(key, glyph, active, onClick, tooltip, size, tone)
  size = size or 44
  tone = tone or "primary"
  return ui.row({
    key = key,
    width = if active then math.floor(size * 1.3) else size,
    height = size,
    radius = if active then math.floor(size * 0.32) else size / 2,
    fill = if active then tone else M.IDLE,
    align = "center",
    justify = "center",
    onClick = onClick or "",
    tooltip = tooltip,
  }, {
    ui.glyph({ name = glyph, size = math.floor(size * 0.42), color = if active then "on_" .. tone else "on_surface" }),
  })
end

-- Big expressive toggle tile: glyph + label + state line, fills when on.
function M.tile(key, glyph, title, state, active, onClick, tone)
  tone = tone or "primary"
  return ui.row({
    key = key,
    flexGrow = 1,
    height = 64,
    gap = 10,
    paddingH = 14,
    radius = if active then 22 else 32,
    fill = if active then tone else M.TILE,
    align = "center",
    onClick = onClick or "",
  }, {
    ui.glyph({ name = glyph, size = 20, color = if active then "on_" .. tone else "on_surface" }),
    ui.column({ gap = 0, flexGrow = 1 }, {
      ui.label({ text = title, fontSize = 13, fontWeight = "semibold", maxLines = 1,
        color = if active then "on_" .. tone else "on_surface" }),
      ui.label({ text = state or "", fontSize = 11, maxLines = 1,
        color = if active then "on_" .. tone .. "/0.8" else "on_surface_variant" }),
    }),
  })
end

-- List item. `lead` is a glyph name or { image = path }.
function M.item(o)
  local active = o.active == true
  local tone = o.tone or "primary"
  local lead
  if type(o.lead) == "table" and o.lead.image then
    lead = ui.image({ path = o.lead.image, width = 40, height = 40, radius = 14, fit = "cover" })
  else
    lead = ui.row({
      width = 40,
      height = 40,
      radius = if active then 14 else 20,
      fill = if active then tone else M.IDLE,
      align = "center",
      justify = "center",
    }, {
      ui.glyph({ name = o.lead or "point", size = 18, color = if active then "on_" .. tone else "on_surface" }),
    })
  end
  local text = {
    ui.label({ text = o.title or "", fontSize = 14, fontWeight = if active then "semibold" else "medium", maxLines = 1,
      color = if active then tone else "on_surface" }),
  }
  if o.subtitle and o.subtitle ~= "" then
    table.insert(text, ui.label({ text = o.subtitle, fontSize = 11, color = "on_surface_variant", maxLines = 1 }))
  end
  local row = { lead, ui.column({ gap = 1, flexGrow = 1 }, text) }
  for _, t in ipairs(o.trailing or {}) do
    table.insert(row, t)
  end
  return ui.row({
    key = o.key,
    gap = 12,
    padding = 10,
    radius = M.R_TILE,
    fill = if active then tone .. "/0.14" else M.TILE,
    align = "center",
    onClick = o.onClick or "",
    tooltip = o.tooltip,
    flexGrow = o.grow,
  }, row)
end

-- Small pill chip (status or action).
function M.chip(key, text, onClick, filled, tone)
  tone = tone or "primary"
  return ui.row({
    key = key,
    height = 30,
    paddingH = 12,
    radius = 15,
    fill = if filled then tone else tone .. "/0.16",
    align = "center",
    justify = "center",
    onClick = onClick or "",
  }, {
    ui.label({ text = text, fontSize = 12, fontWeight = "semibold", color = if filled then "on_" .. tone else tone }),
  })
end

-- Connected button group (M3 Expressive): the chosen segment is filled and
-- squarer, the rest stay round and tonal.
function M.segmented(items)
  local children = {}
  for _, it in ipairs(items) do
    local on = it.on == true
    local content = {}
    if it.glyph then
      table.insert(content, ui.glyph({ name = it.glyph, size = 16, color = if on then "on_primary" else "on_surface" }))
    end
    -- Only the chosen segment carries its label; the rest stay icon-only.
    if it.text and (on or not it.glyph) then
      table.insert(content, ui.label({ text = it.text, fontSize = 12, fontWeight = "semibold", maxLines = 1,
        color = if on then "on_primary" else "on_surface" }))
    end
    table.insert(children, ui.row({
      key = it.key,
      flexGrow = if on then 2.2 else 1,
      height = 44,
      gap = 6,
      radius = if on then 14 else 22,
      fill = if on then "primary" else M.IDLE,
      align = "center",
      justify = "center",
      onClick = it.onClick or "",
      tooltip = it.tooltip or it.text,
    }, content))
  end
  return ui.row({ gap = 4 }, children)
end

-- Pill slider with the glyph on the handle and a value chip on the right; the
-- chip is a button (e.g. mute) when `chipClick` is set.
function M.slider(key, glyph, value, max, onChange, onEnd, chipClick, chipActive, tooltip, tone)
  tone = tone or "primary"
  return ui.row({ key = key, gap = 10, align = "center" }, {
    ui.slider({
      pill = true,
      thickness = 40,
      glyph = glyph,
      min = 0,
      max = max,
      step = 1,
      value = value,
      flexGrow = 1,
      onChange = onChange,
      onDragEnd = onEnd,
    }),
    ui.row({
      key = key .. "-chip",
      width = 58,
      height = 40,
      radius = if chipActive then 12 else 20,
      fill = if chipActive then tone else M.IDLE,
      align = "center",
      justify = "center",
      onClick = chipClick or "",
      tooltip = tooltip,
    }, {
      ui.label({ text = tostring(value) .. "%", fontSize = 12, fontWeight = "semibold",
        color = if chipActive then "on_" .. tone else "on_surface" }),
    }),
  })
end

function M.empty(glyph, text)
  return ui.column({ flexGrow = 1, align = "center", justify = "center", gap = 10, paddingV = 18 }, {
    ui.row({ width = 64, height = 64, radius = 24, fill = "primary/0.12", align = "center", justify = "center" }, {
      ui.glyph({ name = glyph, size = 28, color = "primary" }),
    }),
    ui.label({ text = text, fontSize = 13, color = "on_surface_variant", textAlign = "center" }),
  })
end

-- Footer link to the full settings page for this area.
function M.footer(text, onClick)
  return ui.row({
    height = 40,
    gap = 8,
    radius = 20,
    paddingH = 14,
    fill = M.IDLE,
    align = "center",
    justify = "center",
    onClick = onClick,
  }, {
    ui.glyph({ name = "settings", size = 16, color = "on_surface" }),
    ui.label({ text = text, fontSize = 12, fontWeight = "semibold" }),
  })
end

-- Hover previews: a panel opened by hovering its bar icon closes again when
-- the pointer leaves the icon without coming into the panel (once inside,
-- Noctalia's close_on_leave takes over). Panels mark themselves "entered"
-- through their root's onHover; the bar control does the closing.
function M.panelHover(state)
  if state == "true" then
    noctalia.state.set("m3.entered", true)
  end
end

function M.panelOpened(id)
  noctalia.state.set("m3.openPanel", id)
  noctalia.state.set("m3.entered", false)
end

function M.panelClosed(_id)
  noctalia.state.set("m3.openPanel", nil)
  noctalia.state.set("m3.entered", false)
end

-- Throttled setter for slider drags.
function M.throttle(ms)
  local last = 0
  return function(fn)
    local now = noctalia.nowMs()
    if now - last >= ms then
      last = now
      fn()
    end
  end
end

return M
