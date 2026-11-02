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

local function label()
  if view == nil or view.ok ~= true then
    return "—"
  end
  if not anyParsed(view.providers) then
    return "…"
  end
  local cost = tonumber(view.current and view.current.cost) or 0
  return string.format("$%.2f", cost)
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
