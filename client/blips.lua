MZInteractBlips = {}

local function removeBlip(handle)
  if handle and handle ~= 0 and DoesBlipExist(handle) then
    RemoveBlip(handle)
  end
end

function MZInteractBlips.create(point)
  if type(point) ~= 'table' or not point.coords or type(point.blip) ~= 'table' or point.blip.enabled ~= true then
    return nil
  end

  local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
  SetBlipSprite(blip, tonumber(point.blip.sprite) or 1)
  SetBlipColour(blip, tonumber(point.blip.color) or 0)
  SetBlipScale(blip, (tonumber(point.blip.scale) or 0.75) + 0.0)
  SetBlipAsShortRange(blip, point.blip.shortRange ~= false)

  if point.blip.display then
    SetBlipDisplay(blip, tonumber(point.blip.display) or 4)
  end

  BeginTextCommandSetBlipName('STRING')
  AddTextComponentSubstringPlayerName(tostring(point.blip.label or point.id or 'Interacao'))
  EndTextCommandSetBlipName(blip)

  return blip
end

function MZInteractBlips.remove(point)
  if type(point) ~= 'table' then
    return
  end

  removeBlip(point.__blip)
  point.__blip = nil
end

function MZInteractBlips.refresh(points)
  for _, point in pairs(points or {}) do
    MZInteractBlips.remove(point)
    if point.active ~= false then
      point.__blip = MZInteractBlips.create(point)
    end
  end
end
