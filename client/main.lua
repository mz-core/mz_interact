MZInteract = MZInteract or {}

local Points = {}
local lastInteractAt = 0

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

local function normalizePoint(data)
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
  point.active = point.active ~= false
  point.__blip = nil

  return point
end

local function callMzCorePermissionExport(source, permission)
  if GetResourceState('mz_core') ~= 'started' then
    return nil
  end

  local exportNames = {}
  if Config.PermissionExportName and Config.PermissionExportName ~= '' then
    exportNames[#exportNames + 1] = Config.PermissionExportName
  end

  for _, name in ipairs(Config.PermissionExports or {}) do
    exportNames[#exportNames + 1] = name
  end

  for _, exportName in ipairs(exportNames) do
    local ok, result = pcall(function()
      local fn = exports['mz_core'][exportName]
      if type(fn) ~= 'function' then
        return nil
      end

      return fn(source, permission)
    end)

    if ok and result ~= nil then
      return result == true
    end
  end

  return nil
end

function MZInteract.HasPointPermission(point)
  if type(point) ~= 'table' or point.permission == nil or point.permission == '' then
    return true
  end

  if Config.UseMzCorePermissions ~= true then
    return Config.PermissionFallbackAllow == true
  end

  local result = callMzCorePermissionExport(GetPlayerServerId(PlayerId()), point.permission)
  if result ~= nil then
    return result == true
  end

  return Config.PermissionFallbackAllow == true
end

local function triggerPointEvent(point)
  if type(point.event) ~= 'table' or type(point.event.name) ~= 'string' or point.event.name == '' then
    return
  end

  local now = GetGameTimer()
  if now - lastInteractAt < (tonumber(Config.InteractCooldownMs) or 800) then
    return
  end
  lastInteractAt = now

  local args = type(point.event.args) == 'table' and point.event.args or {}
  if point.event.type == 'server' then
    TriggerServerEvent(point.event.name, table.unpack(args))
  else
    TriggerEvent(point.event.name, table.unpack(args))
  end
end

function MZInteract.AddPoint(data)
  local point, err = normalizePoint(data)
  if not point then
    debugPrint(('AddPoint failed: %s'):format(err))
    return false, err
  end

  if Points[point.id] then
    MZInteractBlips.remove(Points[point.id])
  end

  Points[point.id] = point
  if point.active ~= false then
    point.__blip = MZInteractBlips.create(point)
  end

  debugPrint(('point added: %s'):format(point.id))
  return true, point.id
end

function MZInteract.RemovePoint(id)
  id = tostring(id or '')
  local point = Points[id]
  if not point then
    return false, 'not_found'
  end

  MZInteractBlips.remove(point)
  Points[id] = nil
  debugPrint(('point removed: %s'):format(id))
  return true
end

function MZInteract.ClearPoints()
  for _, point in pairs(Points) do
    MZInteractBlips.remove(point)
  end

  Points = {}
  debugPrint('points cleared')
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

function MZInteract.SetPointActive(id, active)
  id = tostring(id or '')
  local point = Points[id]
  if not point then
    return false, 'not_found'
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

    for _, point in pairs(Points) do
      if point.active ~= false and MZInteract.HasPointPermission(point) then
        local distance = #(playerCoords - point.coords)
        local drawDistance = tonumber(point.drawDistance) or Config.DefaultDrawDistance or 20.0
        local interactDistance = tonumber(point.interactDistance) or Config.DefaultInteractDistance or 2.0

        if distance <= drawDistance then
          sleep = tonumber(Config.NearLoopSleep) or 0
          MZInteractMarkers.draw(point)

          if point.text ~= false and distance <= (interactDistance + 1.0) then
            MZInteractText3D.draw(point.coords, point.text)
          end

          if distance <= interactDistance and IsControlJustReleased(0, tonumber(point.key) or Config.DefaultKey or 38) then
            triggerPointEvent(point)
          end
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
