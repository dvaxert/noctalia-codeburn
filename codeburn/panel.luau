--!nonstrict
-- Period switcher and the latest status payload.

local PERIODS = { "today", "week", "30days", "month", "all" }
local view = nil

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
  return string.format("$%.2f", tonumber(cost) or 0)
end

local function providerLine(provider)
  local name = noctalia.tr("provider." .. tostring(provider.name or ""))
  if provider.located ~= true then
    return noctalia.tr("provider.absent", { name = name })
  end
  if provider.parsed == true then
    return noctalia.tr("provider.priced", { name = name })
  end
  local files = tonumber(provider.files) or 0
  if files > 0 then
    return noctalia.tr("provider.files", { name = name, files = files })
  end
  return noctalia.tr("provider.found", { name = name })
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
        send("period", period)
      end,
    }))
  end
  return ui.row({ gap = 4, align = "center" }, buttons)
end

local function bodyRows()
  if view == nil then
    return { ui.label({ text = noctalia.tr("status.waiting"), color = "on_surface_variant" }) }
  end
  if view.ok ~= true then
    return { ui.label({ text = errorText(), color = "error" }) }
  end
  local rows = {
    ui.label({
      text = money(view.current and view.current.cost),
      fontSize = 28,
      fontWeight = "bold",
    }),
  }
  local priced = false
  if type(view.providers) == "table" then
    for _, provider in ipairs(view.providers) do
      if type(provider) == "table" then
        if provider.parsed == true then
          priced = true
        end
        table.insert(rows, ui.label({
          text = providerLine(provider),
          color = "on_surface_variant",
        }))
      end
    end
  end
  if not priced then
    table.insert(rows, ui.label({ text = noctalia.tr("status.unpriced"), color = "on_surface_variant" }))
  end
  local models = view.current and view.current.topModels
  if type(models) == "table" then
    for _, model in ipairs(models) do
      if type(model) == "table" then
        table.insert(rows, ui.label({
          text = `{model.name or ""}  {money(model.cost)}`,
        }))
      end
    end
  end
  local projects = view.current and view.current.projects
  if type(projects) == "table" then
    for _, project in ipairs(projects) do
      if type(project) == "table" then
        table.insert(rows, ui.label({
          text = `{project.name or ""}  {money(project.cost)}`,
          color = "on_surface_variant",
        }))
      end
    end
  end
  return rows
end

local function render()
  panel.render(ui.column({ flexGrow = 1, gap = 8 }, {
    ui.row({ gap = 6, align = "center" }, {
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
    ui.column({ gap = 4 }, bodyRows()),
  }))
end

local function apply(value)
  view = decode(value)
  render()
end

noctalia.state.watch("view", apply)
apply(noctalia.state.get("view"))

function onOpen()
  render()
end
