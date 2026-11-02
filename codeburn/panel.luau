--!nonstrict
-- Period totals, a token chart, and the models and projects behind them.

local PERIODS = { "today", "week", "30days", "month", "all" }
-- Five sm buttons measured at the body font. The column adds no padding of its own.
local CONTENT_W = 361
local view = nil
local hoverIndex = nil

local function decode(value)
  if type(value) ~= "string" then
    return nil
  end
  local decoded = noctalia.json.decode(value)
  if type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

local function send(cmd, payload)
  noctalia.state.set("cmd", `{noctalia.nowMs()}|{cmd}|{payload or ""}`)
end

local function money(cost)
  cost = tonumber(cost) or 0
  if math.abs(cost) >= 1000 then
    return string.format("$%.1fk", cost / 1000)
  end
  if math.abs(cost) >= 100 then
    return string.format("$%.0f", cost)
  end
  return string.format("$%.2f", cost)
end

local function compact(n)
  n = tonumber(n) or 0
  if n >= 1000000000 then
    return string.format("%.1fB", n / 1000000000)
  end
  if n >= 1000000 then
    return string.format("%.1fM", n / 1000000)
  end
  if n >= 1000 then
    return string.format("%.1fK", n / 1000)
  end
  return tostring(math.floor(n))
end

local function errorText()
  local code = view and view.error or "json"
  if code == "missing" then
    return noctalia.tr("error.missing")
  elseif code == "timeout" then
    return noctalia.tr("error.timeout")
  elseif code == "spawn" then
    return noctalia.tr("error.spawn")
  elseif code == "exit" then
    local detail = view.detail or ""
    if detail ~= "" then
      return detail
    end
    return noctalia.tr("error.exit")
  end
  return noctalia.tr("error.json")
end

local function periodButtons()
  local current = (view and view.period) or noctalia.getConfig("period") or "today"
  local buttons = {}
  for _, period in ipairs(PERIODS) do
    table.insert(buttons, ui.button({
      key = "period-" .. period,
      text = noctalia.tr("period." .. period),
      controlSize = "sm",
      variant = period == current and "primary" or "ghost",
      onClick = function()
        hoverIndex = nil
        send("period", period)
      end,
    }))
  end
  return ui.row({ gap = 4, align = "center" }, buttons)
end

local function row(name, value, dim)
  return ui.row({ width = CONTENT_W, align = "center", gap = 8 }, {
    ui.label({ text = name, flexGrow = 1, maxLines = 1 }),
    ui.label({ text = value, color = dim and "on_surface_variant" or "on_surface" }),
  })
end

local function section(title)
  return ui.label({ text = title, fontSize = 13, fontWeight = "bold" })
end

local function dayTokens(day)
  return (tonumber(day.inputTokens) or 0)
    + (tonumber(day.outputTokens) or 0)
    + (tonumber(day.cacheReadTokens) or 0)
    + (tonumber(day.cacheWriteTokens) or 0)
end

local function chartBlock()
  local history = view and view.history or {}
  local days = history.daily or {}
  if #days == 0 then
    return ui.label({ text = noctalia.tr("status.empty"), color = "on_surface_variant" })
  end
  local maxTokens = 1
  local values = {}
  local sumTokens = 0
  for _, day in ipairs(days) do
    local total = dayTokens(day)
    if total > maxTokens then
      maxTokens = total
    end
    sumTokens += total
  end
  for _, day in ipairs(days) do
    table.insert(values, dayTokens(day) / maxTokens)
  end
  local caption
  local hovered = hoverIndex and days[hoverIndex]
  if hovered then
    caption = `{hovered.date}   {compact(dayTokens(hovered))}   {money(hovered.cost)}`
  else
    caption = `{history.label or ""}   {compact(sumTokens)}`
  end
  return ui.column({ gap = 4, align = "start" }, {
    ui.row({ width = CONTENT_W, align = "center" }, {
      ui.label({ text = noctalia.tr("section.tokens"), fontSize = 13, fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = caption, color = "on_surface_variant", maxLines = 1 }),
    }),
    ui.graph({
      values = values,
      fillOpacity = 0.35,
      color = "primary",
      width = CONTENT_W,
      height = 78,
      onPointerMove = "onGraphMove",
      onPointerLeave = "onGraphLeave",
    }),
  })
end

local function detailRows()
  local rows = {}
  local current = view.current or {}
  table.insert(rows, section(noctalia.tr("section.models")))
  local models = current.topModels or {}
  if #models == 0 then
    table.insert(rows, ui.label({ text = noctalia.tr("status.empty"), color = "on_surface_variant" }))
  end
  for _, model in ipairs(models) do
    table.insert(rows, row(
      tostring(model.name or ""),
      `{money(model.cost)}  {compact(model.tokens)}`,
      true
    ))
  end
  table.insert(rows, section(noctalia.tr("section.projects")))
  local projects = current.projects or {}
  if #projects == 0 then
    table.insert(rows, ui.label({ text = noctalia.tr("status.empty"), color = "on_surface_variant" }))
  end
  for _, project in ipairs(projects) do
    table.insert(rows, row(
      tostring(project.name or ""),
      `{money(project.cost)}  {compact(project.tokens)}`,
      true
    ))
  end
  table.insert(rows, section(noctalia.tr("section.tools")))
  for _, provider in ipairs(view.providers or {}) do
    if type(provider) == "table" then
      local name = noctalia.tr("provider." .. tostring(provider.name or ""))
      local text
      if provider.located ~= true then
        text = noctalia.tr("provider.absent", { name = name })
      else
        text = `{name}   {money(provider.cost)}   {compact((provider.inputTokens or 0) + (provider.outputTokens or 0) + (provider.cacheReadTokens or 0) + (provider.cacheWriteTokens or 0))}`
      end
      table.insert(rows, ui.label({ text = text, color = "on_surface_variant", maxLines = 1 }))
    end
  end
  return rows
end

local function render()
  local body
  if view == nil then
    body = { ui.label({ text = noctalia.tr("status.waiting"), color = "on_surface_variant" }) }
  elseif view.ok ~= true then
    body = { ui.label({ text = errorText(), color = "error" }) }
  else
    local current = view.current or {}
    local tokens = (tonumber(current.inputTokens) or 0)
      + (tonumber(current.outputTokens) or 0)
      + (tonumber(current.cacheReadTokens) or 0)
      + (tonumber(current.cacheWriteTokens) or 0)
    body = {
      ui.label({ text = money(current.cost), fontSize = 28, fontWeight = "bold" }),
      ui.label({
        text = noctalia.tr("status.meta", {
          calls = tostring(current.calls or 0),
          sessions = tostring(current.sessions or 0),
          tokens = compact(tokens),
        }),
        color = "on_surface_variant",
      }),
      chartBlock(),
      ui.column({ gap = 4, align = "start" }, detailRows()),
    }
  end
  panel.render(ui.column({ gap = 8, align = "start", justify = "start" }, {
    ui.row({ width = CONTENT_W, gap = 6, align = "center" }, {
      ui.glyph({ name = "flame", size = 18, color = "primary" }),
      ui.label({ text = noctalia.tr("title"), fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
      ui.button({
        glyph = "refresh",
        variant = "ghost",
        controlSize = "sm",
        tooltip = noctalia.tr("tooltip.refresh"),
        onClick = function()
          send("refresh")
        end,
      }),
    }),
    periodButtons(),
    ui.separator({}),
    ui.column({ gap = 8, align = "start" }, body),
  }))
end

function onGraphMove(x, _y)
  local days = view and view.history and view.history.daily or {}
  local n = #days
  if n == 0 then
    return
  end
  local idx = math.clamp(math.floor((tonumber(x) or 0) * n) + 1, 1, n)
  if hoverIndex ~= idx then
    hoverIndex = idx
    render()
  end
end

function onGraphLeave()
  if hoverIndex ~= nil then
    hoverIndex = nil
    render()
  end
end

local function apply(value)
  view = decode(value)
  hoverIndex = nil
  render()
end

noctalia.state.watch("view", apply)
apply(noctalia.state.get("view"))

function onOpen()
  render()
end
