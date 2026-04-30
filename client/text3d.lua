MZInteractText3D = {}

local function mergeTextConfig(text)
  local defaults = Config.DefaultText or {}
  text = type(text) == 'table' and text or {}

  return {
    enabled = text.enabled ~= nil and text.enabled == true or defaults.enabled == true,
    label = tostring(text.label or defaults.label or '[E] Interagir'),
    offsetZ = tonumber(text.offsetZ or defaults.offsetZ) or 0.35,
    scale = tonumber(text.scale or defaults.scale) or 0.32,
    font = tonumber(text.font or defaults.font) or 4,
    color = text.color or defaults.color or { r = 255, g = 255, b = 255, a = 230 },
    background = text.background or defaults.background or { r = 0, g = 0, b = 0, a = 95 }
  }
end

function MZInteractText3D.draw(coords, textConfig)
  local cfg = mergeTextConfig(textConfig)
  if cfg.enabled ~= true then
    return
  end

  local x, y, z = coords.x, coords.y, coords.z + cfg.offsetZ
  local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
  if not onScreen then
    return
  end

  local camCoords = GetGameplayCamCoords()
  local distance = #(coords - camCoords)
  local scale = cfg.scale / math.max(distance * 0.22, 1.0)

  SetTextScale(scale, scale)
  SetTextFont(cfg.font)
  SetTextProportional(true)
  SetTextCentre(true)
  SetTextColour(
    tonumber(cfg.color.r) or 255,
    tonumber(cfg.color.g) or 255,
    tonumber(cfg.color.b) or 255,
    tonumber(cfg.color.a) or 230
  )
  SetTextOutline()
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(cfg.label)
  EndTextCommandDisplayText(screenX, screenY)

  local width = math.min((#cfg.label * 0.0048) + 0.018, 0.22)
  DrawRect(
    screenX,
    screenY + 0.012,
    width,
    0.028,
    tonumber(cfg.background.r) or 0,
    tonumber(cfg.background.g) or 0,
    tonumber(cfg.background.b) or 0,
    tonumber(cfg.background.a) or 95
  )
end
