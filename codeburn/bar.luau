--!nonstrict
-- Flame glyph plus a cost. An ellipsis means files were found and not priced yet.

local PANEL = "dvaxert/codeburn:panel"
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

local function anyParsed(providers)
  if type(providers) ~= "table" then
    return false
  end
  for _, provider in ipairs(providers) do
    if type(provider) == "table" and provider.parsed == true then
      return true
    end
  end
  return false
end

local function compact(n)
  n = tonumber(n) or 0
  if n >= 1000000 then
    return string.format("%.1fM", n / 1000000)
  end
  if n >= 1000 then
    return string.format("%.1fK", n / 1000)
  end
  return tostring(math.floor(n))
end

local function label()
  if view == nil or view.ok ~= true or not anyParsed(view.providers) then
    return "—"
  end
  local current = view.current or {}
  local cost = tonumber(current.cost) or 0
  if cost >= 1000 then
    return string.format("$%.1fk", cost / 1000)
  end
  if cost > 0 then
    return string.format("$%.2f", cost)
  end
  local tokens = (tonumber(current.inputTokens) or 0) + (tonumber(current.outputTokens) or 0)
  if tokens > 0 then
    return compact(tokens)
  end
  return "$0.00"
end

local function render()
  local broken = view == nil or view.ok ~= true
  barWidget.setGlyph("flame")
  barWidget.setGlyphColor(broken and "error" or "primary")
  barWidget.setText(label())
  barWidget.setTooltip(noctalia.tr("tooltip.bar"))
end

noctalia.state.watch("view", function(value)
  view = decode(value)
  render()
end)

view = decode(noctalia.state.get("view"))
render()

function onClick()
  noctalia.togglePanel(PANEL)
end
