MZInteract = MZInteract or {}

local Points = {}
local lastInteractAt = {}

local function debugPrint(message)
  if Config.Debug == true then
    print(('[mz_interact] %s'):format(tostring(message)))
  end
end

local function cloneTable(value)
  if type(value) ~= 'table' then
    return value
  end

  local out = {}
  for key, child in pairs(value) do
    out[key] = cloneTable(child)
  end
  return out
end

local function normalizeCoords(coords)
  if type(coords) == 'vector3' then
    return coords
  end

  if type(coords) == 'vector4' then
    return vec3(coords.x, coords.y, coords.z)
  end

  if type(coords) == 'table' then
    local x = tonumber(coords.x or coords[1])
    local y = tonumber(coords.y or coords[2])
    local z = tonumber(coords.z or coords[3])
    if x and y and z then
      return vec3(x, y, z)
    end
  end

  return nil
end

local function normalizePoint(data, owner)
  if type(data) ~= 'table' then
    return nil, 'invalid_data'
  end

  local id = tostring(data.id or '')
  if id == '' then
    return nil, 'invalid_id'
  end

  local coords = normalizeCoords(data.coords)
  if not coords then
    return nil, 'invalid_coords'
  end

  local point = cloneTable(data)
  point.id = id
  point.coords = coords
  point.drawDistance = tonumber(point.drawDistance or Config.DefaultDrawDistance) or 20.0
  point.interactDistance = tonumber(point.interactDistance or Config.DefaultInteractDistance) or 2.0
  point.key = tonumber(point.key or Config.DefaultKey) or 38
  point.priority = tonumber(point.priority) or 0
  point.active = point.active ~= false
  point.__owner = tostring(owner or point.__owner or GetCurrentResourceName())
  point.__blip = nil

  if type(point.actions) == 'table' then
    local actions = {}
    for index, action in ipairs(point.actions) do
      if type(action) == 'table' then
        local normalizedAction = cloneTable(action)
        normalizedAction.id = tostring(normalizedAction.id or index)
        normalizedAction.key = tonumber(normalizedAction.key or point.key) or point.key
        normalizedAction.active = normalizedAction.active ~= false
        actions[#actions + 1] = normalizedAction
      end
    end
    point.actions = actions
  end

  return point
end

function MZInteract.HasPointPermission(point)
  if type(point) ~= 'table' or point.visible == false then return false end
  if point.permission == nil or point.permission == '' then return true end

  -- Permissoes oficiais do mz_core vivem no servidor. O campo legado serve
  -- somente como dica visual; consumidores que precisam ocultar um ponto
  -- devem receber essa decisao do servidor e usar active/visible.
  return Config.PermissionFallbackAllow == true
end

local function triggerPointEvent(point, action)
  local event = type(action) == 'table' and action.event or point.event
  if type(event) ~= 'table' or type(event.name) ~= 'string' or event.name == '' then
    return
  end

  local now = GetGameTimer()
  local actionId = type(action) == 'table' and tostring(action.id or action.key or 'action') or 'primary'
  local cooldownId = ('%s:%s'):format(point.id, actionId)
  local previous = tonumber(lastInteractAt[cooldownId]) or 0
  if now - previous < (tonumber(action and action.cooldownMs or Config.InteractCooldownMs) or 800) then
    return
  end
  lastInteractAt[cooldownId] = now

  local args = type(event.args) == 'table' and event.args or {}
  if event.type == 'server' then
    TriggerServerEvent(event.name, table.unpack(args))
  else
    TriggerEvent(event.name, table.unpack(args))
  end
end

function MZInteract.AddPoint(data, owner)
  local point, err = normalizePoint(data, owner)
  if not point then
    debugPrint(('AddPoint failed: %s'):format(err))
    return false, err
  end

  if Points[point.id] then
    if tostring(Points[point.id].__owner or '') ~= tostring(point.__owner or '') then
      return false, 'id_owned_by_other_resource'
    end
    MZInteractBlips.remove(Points[point.id])
  end

  Points[point.id] = point
  if point.active ~= false then
    point.__blip = MZInteractBlips.create(point)
  end

  debugPrint(('point added: %s'):format(point.id))
  return true, point.id
end

function MZInteract.UpdatePoint(id, patch, owner)
  id = tostring(id or '')
  local current = Points[id]
  if not current then return false, 'not_found' end
  if owner and tostring(current.__owner or '') ~= tostring(owner) then
    return false, 'owner_mismatch'
  end
  if type(patch) ~= 'table' then return false, 'invalid_patch' end

  local updated = cloneTable(current)
  updated.__blip = nil
  for key, value in pairs(patch) do
    if key ~= 'id' and key ~= '__owner' and key ~= '__blip' then
      updated[key] = cloneTable(value)
    end
  end
  updated.id = id
  return MZInteract.AddPoint(updated, current.__owner)
end

function MZInteract.RemovePoint(id, owner)
  id = tostring(id or '')
  local point = Points[id]
  if not point then
    return false, 'not_found'
  end
  if owner and tostring(point.__owner or '') ~= tostring(owner) then
    return false, 'owner_mismatch'
  end

  MZInteractBlips.remove(point)
  Points[id] = nil
  debugPrint(('point removed: %s'):format(id))
  return true
end

function MZInteract.RemovePointsByOwner(owner)
  owner = tostring(owner or '')
  if owner == '' then return 0 end

  local ids = {}
  for id, point in pairs(Points) do
    if tostring(point.__owner or '') == owner then ids[#ids + 1] = id end
  end
  for _, id in ipairs(ids) do MZInteract.RemovePoint(id) end
  return #ids
end

function MZInteract.ClearPoints(owner)
  if owner and tostring(owner) ~= '' then
    local removed = MZInteract.RemovePointsByOwner(owner)
    debugPrint(('points cleared for owner %s: %s'):format(tostring(owner), removed))
    return true, removed
  end

  local ids = {}
  for id in pairs(Points) do ids[#ids + 1] = id end
  for _, id in ipairs(ids) do MZInteract.RemovePoint(id) end
  lastInteractAt = {}
  debugPrint('all points cleared')
  return true
end

function MZInteract.GetPoint(id)
  local point = Points[tostring(id or '')]
  if not point then
    return nil
  end

  local copy = cloneTable(point)
  copy.__blip = nil
  return copy
end

function MZInteract.GetClosestPoint(coords, maxDistance, activeOnly)
  coords = normalizeCoords(coords)
  if not coords then return nil, 'invalid_coords' end

  local closest
  local limit = tonumber(maxDistance) or math.huge
  for _, point in pairs(Points) do
    if (activeOnly ~= true or point.active ~= false) and MZInteract.HasPointPermission(point) then
      local distance = #(coords - point.coords)
      if distance <= limit then
        local candidate = {
          id = point.id,
          distance = distance,
          priority = point.priority,
          point = point
        }
        if MZInteractLogic.IsBetterCandidate(candidate, closest) then closest = candidate end
      end
    end
  end

  if not closest then return nil, 'not_found' end
  local copy = cloneTable(closest.point)
  copy.__blip = nil
  return copy, closest.distance
end

function MZInteract.SetPointActive(id, active, owner)
  id = tostring(id or '')
  local point = Points[id]
  if not point then
    return false, 'not_found'
  end
  if owner and tostring(point.__owner or '') ~= tostring(owner) then
    return false, 'owner_mismatch'
  end

  point.active = active == true
  MZInteractBlips.remove(point)
  if point.active then
    point.__blip = MZInteractBlips.create(point)
  end

  return true
end

function MZInteract.RefreshBlips()
  MZInteractBlips.refresh(Points)
  return true
end

function MZInteract.GetPoints()
  return Points
end

local function addConfiguredExamples()
  if Config.ExamplePoints ~= true then
    return
  end

  for _, point in ipairs(Config.Examples or {}) do
    MZInteract.AddPoint(point)
  end
end

CreateThread(function()
  Wait(500)
  addConfiguredExamples()
end)

CreateThread(function()
  while true do
    local sleep = tonumber(Config.DefaultLoopSleep) or 1000
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local closest

    for _, point in pairs(Points) do
      if point.active ~= false and MZInteract.HasPointPermission(point) then
        local distance = #(playerCoords - point.coords)
        local drawDistance = tonumber(point.drawDistance) or Config.DefaultDrawDistance or 20.0
        local interactDistance = tonumber(point.interactDistance) or Config.DefaultInteractDistance or 2.0
        local actionableDistance = interactDistance + (tonumber(Config.InteractTolerance) or 0.35)

        if distance <= drawDistance then
          sleep = tonumber(Config.NearLoopSleep) or 0
          MZInteractMarkers.draw(point)

          if distance <= actionableDistance then
            local candidate = {
              id = point.id,
              distance = distance,
              priority = point.priority,
              point = point,
              interactDistance = actionableDistance
            }
            if MZInteractLogic.IsBetterCandidate(candidate, closest) then closest = candidate end
          end
        end
      end
    end

    if closest then
      local point = closest.point
      if point.text ~= false then MZInteractText3D.draw(point.coords, point.text) end

      if closest.distance <= closest.interactDistance then
        local triggered = false
        if type(point.actions) == 'table' and #point.actions > 0 then
          for _, action in ipairs(point.actions) do
            if action.active ~= false and IsControlJustReleased(0, tonumber(action.key) or point.key) then
              triggerPointEvent(point, action)
              triggered = true
              break
            end
          end
        end
        if not triggered and IsControlJustReleased(0, tonumber(point.key) or Config.DefaultKey or 38) then
          triggerPointEvent(point)
        end
      end
    end

    Wait(sleep)
  end
end)

RegisterCommand('mzinteract_test', function()
  if Config.Debug ~= true then
    return
  end

  local ped = PlayerPedId()
  local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, -0.85)

  MZInteract.AddPoint({
    id = 'debug_test',
    coords = coords,
    drawDistance = 20.0,
    interactDistance = 2.0,
    marker = {
      enabled = true,
      type = 9,
      textureDict = 'mod_icon',
      textureName = 'badge_icon',
      size = vec3(0.75, 0.75, 0.75),
      color = { r = 255, g = 255, b = 255, a = 230 },
      rotate = true,
      bobUpAndDown = true,
      faceCamera = true
    },
    text = {
      enabled = true,
      label = '[E] Teste mz_interact'
    },
    event = {
      type = 'client',
      name = 'mz_interact:client:debugInteract',
      args = {}
    }
  })
end, false)

RegisterNetEvent('mz_interact:client:debugInteract', function()
  debugPrint('debug point interacted')
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  MZInteract.ClearPoints()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    MZInteract.RemovePointsByOwner(resourceName)
  end
end)
