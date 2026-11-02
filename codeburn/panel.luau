--!nonstrict
-- A header over two columns. The main column follows the selected period: the spend,
-- a daily token chart, the models, and the projects. The side column has one card per
-- tool, with that tool's period spend above its live limit meters.

local PERIODS = { "today", "week", "30days", "month", "all" }
local GAP = 12
local CARD_PAD = 12
-- Two list cards side by side make up the main column. The shell keeps 18px around the root.
local LIST_W = 240
local MAIN_W = LIST_W * 2 + GAP
local SIDE_W = 236
local ROOT_W = MAIN_W + GAP + SIDE_W
local MAIN_INNER = MAIN_W - CARD_PAD * 2
local LIST_INNER = LIST_W - CARD_PAD * 2
local SIDE_INNER = SIDE_W - CARD_PAD * 2
local CHART_H = 96
local MAX_BAR_W = 18
-- codeburn-rs lists at most eight models and projects. Holding that height keeps the cards still.
local LIST_ROW_H = 30
local LIST_ROWS = 8
local LOW_REMAINING = 0.15
local PROVIDER_COLOR = { claude = "primary", codex = "secondary", cursor = "tertiary" }
local TRACK = "on_surface_variant/0.2"
local view = nil
local hoverIndex = nil
-- Set from a click until the service answers, so the panel reacts before the scan ends.
local pendingPeriod = nil
local refreshing = false

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

local function grouped(n)
  local digits = tostring(math.floor(tonumber(n) or 0))
  local spaced = digits:reverse():gsub("(%d%d%d)", "%1 "):reverse()
  return (spaced:gsub("^ ", ""):gsub(" ", "\u{a0}"))
end

local function headlineMoney(cost)
  cost = tonumber(cost) or 0
  if math.abs(cost) >= 1000 then
    return "$" .. grouped(cost)
  end
  return string.format("$%.2f", cost)
end

local function tokenTotal(item)
  return (tonumber(item.inputTokens) or 0)
    + (tonumber(item.outputTokens) or 0)
    + (tonumber(item.cacheReadTokens) or 0)
    + (tonumber(item.cacheWriteTokens) or 0)
end

local function shortDate(iso)
  local month, day = tostring(iso):match("^%d+%-(%d+)%-(%d+)")
  if month == nil then
    return tostring(iso)
  end
  return noctalia.tr("date.short", {
    day = tostring(tonumber(day)),
    month = noctalia.tr("month." .. tostring(tonumber(month))),
  })
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

local function unixUtc(year, month, day, hour, minute, second)
  local y = year - (month <= 2 and 1 or 0)
  local era = math.floor(y / 400)
  if y < 0 then
    era = math.floor((y - 399) / 400)
  end
  local yoe = y - era * 400
  local mp = month + (month > 2 and -3 or 9)
  local doy = math.floor((153 * mp + 2) / 5) + day - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return (era * 146097 + doe - 719468) * 86400 + hour * 3600 + minute * 60 + second
end

local function resetCaption(iso)
  if type(iso) ~= "string" then
    return nil
  end
  local year, month, day, hour, minute, second = iso:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
  if year == nil then
    return nil
  end
  local at = unixUtc(
    tonumber(year),
    tonumber(month),
    tonumber(day),
    tonumber(hour),
    tonumber(minute),
    tonumber(second)
  )
  local delta = at - noctalia.nowMs() / 1000
  if delta <= 0 then
    return noctalia.tr("limit.reset_done")
  end
  local when
  if delta < 3600 then
    when = noctalia.tr("limit.in_min", { n = tostring(math.max(1, math.floor(delta / 60))) })
  elseif delta < 172800 then
    when = noctalia.tr("limit.in_hour", { n = tostring(math.floor(delta / 3600)) })
  else
    when = noctalia.tr("limit.in_day", { n = tostring(math.floor(delta / 86400)) })
  end
  return noctalia.tr("limit.reset", { when = when })
end

local function limitName(item)
  local kind = tostring(item.kind or "custom")
  local detail = type(item.detail) == "string" and item.detail or ""
  if kind == "weekly_model" then
    return noctalia.tr("limit.weekly_model", { detail = detail })
  end
  if kind == "custom" then
    if detail ~= "" then
      return detail
    end
    return noctalia.tr("limit.custom")
  end
  local known = kind == "five_hour"
    or kind == "daily"
    or kind == "weekly"
    or kind == "monthly"
    or kind == "auto"
    or kind == "api"
    or kind == "on_demand"
    or kind == "team"
    or kind == "credits"
  local name = known and noctalia.tr("limit." .. kind) or kind
  if detail ~= "" then
    return `{detail} · {name}`
  end
  return name
end

local function providerTitle(name)
  if name == "claude" or name == "codex" or name == "cursor" then
    return noctalia.tr("provider." .. name)
  end
  if name == "" then
    return noctalia.tr("section.limits")
  end
  return name
end

local function providerColor(name)
  return PROVIDER_COLOR[name] or "on_surface_variant"
end

local function card(props, children)
  props.fill = "surface_variant"
  props.radius = 12
  props.padding = CARD_PAD
  return ui.column(props, children)
end

local function dot(color)
  return ui.box({ width = 8, height = 8, radius = 4, fill = color })
end

local function caption(text)
  return ui.label({ text = text, fontSize = 12, color = "on_surface_variant", maxLines = 1 })
end

local function cardTitle(text)
  return ui.label({ text = text, fontSize = 13, fontWeight = "bold" })
end

local function stat(value, name)
  return ui.column({ gap = 0, align = "end" }, {
    ui.label({ text = value, fontSize = 15, fontWeight = "semibold" }),
    caption(name),
  })
end

local function heroRow(current)
  return ui.row({ width = MAIN_INNER, align = "center", gap = 20 }, {
    ui.column({ gap = 0, flexGrow = 1, align = "start" }, {
      ui.label({ text = headlineMoney(current.cost), fontSize = 34, fontWeight = "bold" }),
      caption(noctalia.tr("period." .. tostring(view.period or "today"))),
    }),
    stat(grouped(current.calls), noctalia.tr("stat.calls")),
    stat(grouped(current.sessions), noctalia.tr("stat.sessions")),
    stat(compact(tokenTotal(current)), noctalia.tr("stat.tokens")),
  })
end

-- A stacked bar of each tool's part of the period spend, with its legend beneath.
local function shareBlock(total)
  local spending = {}
  for _, provider in ipairs(view.providers or {}) do
    if type(provider) == "table" and (tonumber(provider.cost) or 0) > 0 then
      table.insert(spending, provider)
    end
  end
  if #spending == 0 or total <= 0 then
    return nil
  end
  local gaps = (#spending - 1) * 2
  local segments = {}
  local legend = {}
  for _, provider in ipairs(spending) do
    local name = tostring(provider.name or "")
    local share = provider.cost / total
    table.insert(segments, ui.box({
      key = "share-" .. name,
      width = math.max(3, (MAIN_INNER - gaps) * share),
      height = 6,
      radius = 3,
      fill = providerColor(name),
    }))
    table.insert(legend, ui.row({ key = "legend-" .. name, gap = 6, align = "center" }, {
      dot(providerColor(name)),
      ui.label({ text = providerTitle(name), fontSize = 12 }),
      caption(`{math.floor(share * 100 + 0.5)}%`),
    }))
  end
  return ui.column({ gap = 6, width = MAIN_INNER, align = "start" }, {
    ui.row({ gap = 2, width = MAIN_INNER, align = "center" }, segments),
    ui.row({ gap = 14, align = "center" }, legend),
  })
end

local function chartBlock()
  local days = view.history and view.history.daily or {}
  local n = #days
  if n == 0 then
    return caption(noctalia.tr("status.empty"))
  end
  local maxTokens = 1
  local sumTokens = 0
  for _, day in ipairs(days) do
    local total = tokenTotal(day)
    maxTokens = math.max(maxTokens, total)
    sumTokens += total
  end
  local slot = MAIN_INNER / n
  local inset = math.max(0.5, (slot - MAX_BAR_W) / 2)
  local accent = hoverIndex or n
  local bars = {}
  for index, day in ipairs(days) do
    local total = tokenTotal(day)
    local fill = index == accent and "primary" or "primary/0.5"
    if total <= 0 then
      fill = TRACK
    end
    table.insert(bars, ui.column({
      key = `day-{index}`,
      width = slot,
      height = CHART_H,
      paddingH = inset,
      justify = "end",
      onHover = "onBarHover",
    }, {
      ui.box({
        height = math.max(2, total / maxTokens * CHART_H),
        radius = 2,
        fill = fill,
      }),
    }))
  end
  local hovered = hoverIndex and days[hoverIndex]
  local summary
  if hovered then
    summary = `{shortDate(hovered.date)}  ·  {compact(tokenTotal(hovered))}  ·  {money(hovered.cost)}`
  else
    summary = `{noctalia.tr("chart.days", { n = tostring(n) })}  ·  {compact(sumTokens)}`
  end
  return ui.column({ gap = 6, width = MAIN_INNER, align = "start" }, {
    ui.row({ width = MAIN_INNER, align = "center" }, {
      ui.label({ text = noctalia.tr("section.tokens"), fontSize = 13, fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = summary, fontSize = 13, color = "on_surface_variant", maxLines = 1 }),
    }),
    ui.row({ width = MAIN_INNER, height = CHART_H, gap = 0, align = "end" }, bars),
    ui.row({ width = MAIN_INNER, align = "center" }, {
      ui.label({
        text = shortDate(days[1].date),
        fontSize = 12,
        color = "on_surface_variant",
        flexGrow = 1,
      }),
      caption(shortDate(days[n].date)),
    }),
  })
end

local function listCard(title, items, total)
  local rows = { cardTitle(title) }
  if #items == 0 then
    table.insert(rows, caption(noctalia.tr("status.empty")))
  end
  for index, item in ipairs(items) do
    local cost = tonumber(item.cost) or 0
    table.insert(rows, ui.column({ key = `item-{index}`, gap = 3, width = LIST_INNER }, {
      ui.row({ width = LIST_INNER, align = "center", gap = 8 }, {
        ui.label({ text = tostring(item.name or ""), fontSize = 13, flexGrow = 1, maxLines = 1 }),
        caption(compact(item.tokens)),
        ui.label({ text = money(cost), fontSize = 13, fontWeight = "semibold" }),
      }),
      ui.progress({
        progress = total > 0 and math.clamp(cost / total, 0, 1) or 0,
        fill = "primary",
        track = TRACK,
        width = LIST_INNER,
        height = 4,
        radius = 2,
      }),
    }))
  end
  return card({
    width = LIST_W,
    gap = 8,
    align = "start",
    minHeight = CARD_PAD * 2 + 26 + LIST_ROW_H * LIST_ROWS,
  }, rows)
end

local function meter(item, color)
  local used = math.clamp(tonumber(item.used) or 0, 0, 1)
  local remaining = 1 - used
  local low = remaining < LOW_REMAINING
  local percent = `{math.floor(remaining * 100 + 0.5)}%`
  local head = {
    ui.label({ text = limitName(item), fontSize = 13, flexGrow = 1, maxLines = 1 }),
  }
  if low then
    table.insert(head, ui.glyph({ name = "alert-triangle", size = 14, color = "error" }))
  end
  table.insert(head, ui.label({
    text = percent,
    fontSize = 15,
    fontWeight = "semibold",
    color = low and "error" or "on_surface",
  }))
  local children = {
    ui.row({ width = SIDE_INNER, align = "center", gap = 6 }, head),
    ui.progress({
      progress = remaining,
      fill = low and "error" or color,
      track = TRACK,
      width = SIDE_INNER,
      height = 8,
      radius = 4,
    }),
  }
  local resets = resetCaption(item.resetsAt)
  if resets ~= nil then
    table.insert(children, caption(resets))
  end
  return ui.column({ gap = 2, width = SIDE_INNER }, children)
end

local function providerCard(name, provider, limits)
  local color = providerColor(name)
  local head = {
    dot(color),
    ui.label({ text = providerTitle(name), fontSize = 14, fontWeight = "bold", flexGrow = 1, maxLines = 1 }),
  }
  local absent = provider ~= nil and provider.located ~= true
  if absent then
    table.insert(head, caption(noctalia.tr("provider.absent")))
  elseif provider ~= nil then
    table.insert(head, caption(compact(tokenTotal(provider))))
    table.insert(head, ui.label({ text = money(provider.cost), fontSize = 13, fontWeight = "semibold" }))
  end
  local rows = { ui.row({ width = SIDE_INNER, align = "center", gap = 6 }, head) }
  for index, item in ipairs(limits) do
    table.insert(rows, ui.column({ key = `limit-{index}`, width = SIDE_INNER }, { meter(item, color) }))
  end
  if #limits == 0 and not absent then
    table.insert(rows, caption(noctalia.tr("limit.empty")))
  end
  return card({ key = "provider-" .. name, width = SIDE_W, gap = 8, align = "start" }, rows)
end

local function sideColumn()
  local order = {}
  local providers = {}
  local limitsBy = {}
  for _, provider in ipairs(view.providers or {}) do
    if type(provider) == "table" then
      local name = tostring(provider.name or "")
      table.insert(order, name)
      providers[name] = provider
      limitsBy[name] = {}
    end
  end
  for _, item in ipairs(type(view.limits) == "table" and view.limits or {}) do
    if type(item) == "table" then
      local name = tostring(item.provider or "")
      if limitsBy[name] == nil then
        table.insert(order, name)
        limitsBy[name] = {}
      end
      table.insert(limitsBy[name], item)
    end
  end
  local rows = {
    ui.row({ width = SIDE_W, align = "center", paddingH = CARD_PAD }, {
      ui.label({ text = noctalia.tr("section.limits"), fontSize = 13, fontWeight = "bold", flexGrow = 1 }),
      caption(noctalia.tr("limit.left")),
    }),
  }
  for _, name in ipairs(order) do
    table.insert(rows, providerCard(name, providers[name], limitsBy[name]))
  end
  return ui.column({ width = SIDE_W, gap = 8, align = "start" }, rows)
end

local function periodButtons()
  local current = pendingPeriod or (view and view.period) or noctalia.getConfig("period") or "today"
  local buttons = {}
  for _, period in ipairs(PERIODS) do
    table.insert(buttons, ui.button({
      key = "period-" .. period,
      text = noctalia.tr("period." .. period),
      fontSize = 13,
      controlSize = "sm",
      variant = period == current and "primary" or "ghost",
      onClick = function()
        if period == current then
          return
        end
        hoverIndex = nil
        pendingPeriod = period
        render()
        send("period", period)
      end,
    }))
  end
  return ui.row({ gap = 2, align = "center", fill = "surface_variant", radius = 10, padding = 2 }, buttons)
end

local function headerRow()
  return ui.row({ width = ROOT_W, gap = 8, align = "center" }, {
    ui.glyph({ name = "flame", size = 20, color = "primary" }),
    ui.label({ text = noctalia.tr("title"), fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
    periodButtons(),
    ui.button({
      glyph = "refresh",
      variant = "ghost",
      controlSize = "sm",
      enabled = not refreshing,
      tooltip = noctalia.tr("tooltip.refresh"),
      onClick = function()
        refreshing = true
        render()
        send("refresh")
      end,
    }),
  })
end

local function statusCard(glyph, text, color)
  return ui.column({ width = ROOT_W, flexGrow = 1, gap = 10, align = "center", justify = "center" }, {
    ui.glyph({ name = glyph, size = 32, color = color }),
    ui.label({
      text = text,
      color = color,
      maxWidth = MAIN_INNER,
      maxLines = 6,
      textAlign = "center",
    }),
  })
end

local function dashboard()
  local current = view.current or {}
  local total = tonumber(current.cost) or 0
  local spend = { heroRow(current) }
  local share = shareBlock(total)
  if share ~= nil then
    table.insert(spend, share)
  end
  table.insert(spend, chartBlock())
  return ui.scroll({ flexGrow = 1 }, {
    ui.row({
      width = ROOT_W,
      gap = GAP,
      align = "stretch",
      opacity = pendingPeriod and 0.55 or 1,
    }, {
      ui.column({ width = MAIN_W, gap = GAP, align = "start" }, {
        card({ width = MAIN_W, gap = 14, align = "start" }, spend),
        ui.row({ width = MAIN_W, gap = GAP, align = "stretch" }, {
          listCard(noctalia.tr("section.models"), current.topModels or {}, total),
          listCard(noctalia.tr("section.projects"), current.projects or {}, total),
        }),
      }),
      sideColumn(),
    }),
  })
end

function render()
  local body
  if view == nil then
    body = statusCard("flame", noctalia.tr("status.waiting"), "on_surface_variant")
  elseif view.ok ~= true then
    body = statusCard("alert-triangle", errorText(), "error")
  else
    body = dashboard()
  end
  panel.render(ui.column({ flexGrow = 1, gap = GAP }, {
    headerRow(),
    body,
  }))
end

function onBarHover(state, key)
  local index = tonumber(tostring(key):match("^day%-(%d+)$"))
  if index == nil then
    return
  end
  if state == "true" then
    if hoverIndex ~= index then
      hoverIndex = index
      render()
    end
  elseif hoverIndex == index then
    hoverIndex = nil
    render()
  end
end

local function apply(value)
  view = decode(value)
  hoverIndex = nil
  refreshing = false
  if view == nil or view.ok ~= true or view.period == pendingPeriod then
    pendingPeriod = nil
  end
  render()
end

noctalia.state.watch("view", apply)
apply(noctalia.state.get("view"))

function onOpen()
  render()
end
