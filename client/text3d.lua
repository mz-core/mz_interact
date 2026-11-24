MZInteractText3D = {}

local function mergeTextConfig(text)
  local defaults = Config.DefaultText or {}
  text = type(text) == 'table' and text or {}

  return {
    enabled = MZInteractLogic.ResolveBoolean(text.enabled, defaults.enabled),
    label = (text.ui == true and ('[' .. tostring(text.keyLabel or 'E') .. '] ') or '') .. tostring(text.label or defaults.label or '[E] Interagir'),
    offsetZ = tonumber(text.offsetZ or defaults.offsetZ) or 0.35,
    offset = text.offset,
    scale = tonumber(text.scale or defaults.scale) or 0.32,
    font = tonumber(text.font or defaults.font) or 4,
    color = text.color or defaults.color or { r = 255, g = 255, b = 255, a = 230 },
    background = text.background or defaults.background or { r = 0, g = 0, b = 0, a = 95 }
  }
end

local function measureLineWidth(line, scale, font)
  SetTextScale(scale, scale)
  SetTextFont(font)
  SetTextProportional(true)
  BeginTextCommandGetWidth('STRING')
  AddTextComponentSubstringPlayerName(line)
  return EndTextCommandGetWidth(true)
end

function MZInteractText3D.draw(coords, textConfig, opacity, feedback)
  local cfg = mergeTextConfig(textConfig)
  if cfg.enabled ~= true then
    return
  end

  local offsetType = type(cfg.offset)
  local offset = (offsetType == 'table' or offsetType == 'vector3' or offsetType == 'vector4') and cfg.offset or {}
  local x = coords.x + (tonumber(offset.x or offset[1]) or 0.0)
  local y = coords.y + (tonumber(offset.y or offset[2]) or 0.0)
  local z = coords.z + cfg.offsetZ + (tonumber(offset.z or offset[3]) or 0.0)
  local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
  if not onScreen then
    return
  end

  local camCoords = GetGameplayCamCoords()
  local distance = #(coords - camCoords)
  local scale = cfg.scale * (1.0 - 0.04 * (feedback or 0.0)) / math.max(distance * 0.22, 1.0)
  local metricLabel = cfg.label:gsub('~n~', '\n'):gsub('~.-~', '')
  local lineCount, maxLineWidth = 0, 0.0
  for line in (metricLabel .. '\n'):gmatch('(.-)\n') do
    lineCount = lineCount + 1
    maxLineWidth = math.max(maxLineWidth, measureLineWidth(line, scale, cfg.font))
  end
  lineCount = math.max(1, lineCount)
  local distanceFactor = cfg.scale > 0 and math.max(0.42, math.min(1.0, scale / cfg.scale)) or 1.0
  local horizontalPadding = 0.0045 * distanceFactor
  local verticalPadding = 0.0022 * distanceFactor
  local lineHeight = GetRenderedCharacterHeight(scale, cfg.font)
  local textHeight = lineHeight * (lineCount + math.max(0, lineCount - 1) * 0.18)
  local width = math.max(0.018, maxLineWidth + horizontalPadding * 2.0)
  local height = math.max(0.012, textHeight + verticalPadding * 2.0)
  local verticalOffset = (height * 0.5) - (verticalPadding * 0.65)

  DrawRect(
    screenX,
    screenY + verticalOffset,
    width,
    height,
    tonumber(cfg.background.r) or 0,
    tonumber(cfg.background.g) or 0,
    tonumber(cfg.background.b) or 0,
    math.floor((tonumber(cfg.background.a) or 95) * (opacity or 1.0) + 0.5)
  )

  SetTextScale(scale, scale)
  SetTextFont(cfg.font)
  SetTextProportional(true)
  SetTextCentre(true)
  SetTextColour(
    tonumber(cfg.color.r) or 255,
    tonumber(cfg.color.g) or 255,
    tonumber(cfg.color.b) or 255,
    math.floor((tonumber(cfg.color.a) or 230) * (opacity or 1.0) + 0.5)
  )
  SetTextOutline()
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(cfg.label)
  EndTextCommandDisplayText(screenX, screenY)
end
