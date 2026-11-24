MZInteract = MZInteract or {}

local Points = {}
local lastInteractAt = {}
local visuals = {}
local selectedId
local displayedText
local lastTextX, lastTextY
local nextTargetCheck, targetActive = 0, false
local actionMenu

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

local function refreshPointCoords(point)
  local follow = point.follow
  if type(follow) ~= 'table' then return true end
  local entity = tonumber(follow.entity)
  if not entity or entity == 0 then return false end
  local exists = DoesEntityExist(entity)
  if exists ~= true and exists ~= 1 then return false end
  local bone = type(follow.bone) == 'string' and GetEntityBoneIndexByName(entity, follow.bone) or -1
  if bone and bone ~= -1 then
    point.coords = GetWorldPositionOfEntityBone(entity, bone)
  else
    local offsetType = type(follow.offset)
    local offset = (offsetType == 'table' or offsetType == 'vector3') and follow.offset or {}
    point.coords = GetOffsetFromEntityInWorldCoords(entity, tonumber(offset.x) or 0.0, tonumber(offset.y) or 0.0, tonumber(offset.z) or 0.0)
  end
  return true
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
    return false
  end

  local now = GetGameTimer()
  local actionId = type(action) == 'table' and tostring(action.id or action.key or 'action') or 'primary'
  local cooldownId = ('%s:%s'):format(point.id, actionId)
  local previous = tonumber(lastInteractAt[cooldownId]) or 0
  if now - previous < (tonumber(action and action.cooldownMs or Config.InteractCooldownMs) or 800) then
    return false
  end
  lastInteractAt[cooldownId] = now

  local args = type(event.args) == 'table' and event.args or {}
  if event.type == 'server' then
    TriggerServerEvent(event.name, table.unpack(args))
  else
    TriggerEvent(event.name, table.unpack(args))
  end
  return true
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
  visuals[id] = nil
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
    if (activeOnly ~= true or point.active ~= false) and MZInteract.HasPointPermission(point) and refreshPointCoords(point) then
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
  local previousTime = GetGameTimer()
  while true do
    local sleep = tonumber(Config.DefaultLoopSleep) or 1000
    local now = GetGameTimer()
    local elapsed = math.max(0, math.min(now - previousTime, 100))
    previousTime = now
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local paused = IsPauseMenuActive()
    local closest, selected, discovery
    local available = {}

    for id, point in pairs(Points) do
      available[id] = refreshPointCoords(point)
      if available[id] and point.active ~= false and MZInteract.HasPointPermission(point) then
        local distance = #(playerCoords - point.coords)
        local drawDistance = tonumber(point.drawDistance) or Config.DefaultDrawDistance or 20.0
        local interactDistance = tonumber(point.interactDistance) or Config.DefaultInteractDistance or 2.0
        local actionableDistance = interactDistance + (tonumber(Config.InteractTolerance) or 0.35)

        if distance <= drawDistance then
          sleep = tonumber(Config.NearLoopSleep) or 0
          if type(point.text) == 'table' and point.text.ui == true and point.text.discovery == true and point.text.enabled ~= false then
            local candidate = { id = point.id, distance = distance, priority = point.priority, point = point }
            if MZInteractLogic.IsBetterCandidate(candidate, discovery) then discovery = candidate end
          end
          if distance <= actionableDistance then
            local candidate = {
              id = point.id,
              distance = distance,
              priority = point.priority,
              point = point,
              interactDistance = actionableDistance
            }
            if MZInteractLogic.IsBetterCandidate(candidate, closest) then closest = candidate end
            if point.id == selectedId then selected = candidate end
          end
        end
      end
    end

    if MZInteractLogic.KeepSelection(selected, closest) then closest = selected end
    selectedId = closest and closest.id or nil

    for id, point in pairs(Points) do
      local state = visuals[id]
      local permitted = available[id] and MZInteract.HasPointPermission(point)
      local distance = permitted and #(playerCoords - point.coords) or math.huge
      local drawDistance = tonumber(point.drawDistance) or Config.DefaultDrawDistance or 20.0
      local visible = permitted and point.active ~= false and distance <= drawDistance
      if visible and not state then
        state = { marker = 0.0, text = 0.0 }
        visuals[id] = state
      end
      if state and not permitted then
        visuals[id] = nil
      elseif state then
        local markerTarget = visible and MZInteractLogic.FadeByDistance(distance, drawDistance, 3.0) or 0.0
        local textTarget = closest and closest.id == id and point.text ~= false
          and MZInteractLogic.FadeByDistance(distance, closest.interactDistance, 0.5) or 0.0
        state.marker = MZInteractLogic.Approach(state.marker, markerTarget, elapsed, 220)
        state.text = MZInteractLogic.Approach(state.text, textTarget, elapsed, 180)
        if state.marker > 0 or state.text > 0 or visible then
          sleep = tonumber(Config.NearLoopSleep) or 0
          if state.marker > 0 and not paused then
            local markerOpacity = state.marker
            if type(point.marker) == 'table' and point.marker.hideWhenNear == true then
              markerOpacity = markerOpacity * (1.0 - state.text)
            end
            MZInteractMarkers.draw(point, markerOpacity, 0.88 + 0.12 * state.text)
          end
          if not paused and state.text > 0 and point.text ~= false and not (type(point.text) == 'table' and point.text.ui == true and GetResourceState('mz_lib') == 'started') then
            local feedback = state.pressedAt and math.max(0.0, 1.0 - (now - state.pressedAt) / 160.0) or 0.0
            MZInteractText3D.draw(point.coords, point.text, state.text, feedback)
          end
        else
          visuals[id] = nil
        end
      end
    end

    if now >= nextTargetCheck then
      targetActive = false
      if GetResourceState('mz_target') == 'started' then
        local ok, active = pcall(function() return exports['mz_target']:IsTargetActive() end)
        targetActive = ok and active == true
      end
      nextTargetCheck = now + 250
    end
    local menuActions = {}
    if closest and type(closest.point.actions) == 'table' then
      for _, action in ipairs(closest.point.actions) do
        if action.active ~= false then menuActions[#menuActions + 1] = action end
      end
    end
    if actionMenu and (paused or targetActive or not closest or closest.id ~= actionMenu.id
      or (closest.point.follow and closest.point.follow.entity) ~= actionMenu.entity
      or not closest.point.actionMenu or #menuActions < 2
      or GetResourceState('mz_lib') ~= 'started') then
      actionMenu = nil
    end
    if actionMenu then
      actionMenu.index = math.min(actionMenu.index, #menuActions)
      for _, control in ipairs({ 14, 15, 172, 173, 200 }) do DisableControlAction(0, control, true) end
      if IsDisabledControlJustReleased(0, 200) then
        actionMenu = nil
      elseif IsDisabledControlJustReleased(0, 14) or IsDisabledControlJustReleased(0, 172) then
        actionMenu.index = (actionMenu.index - 2) % #menuActions + 1
      elseif IsDisabledControlJustReleased(0, 15) or IsDisabledControlJustReleased(0, 173) then
        actionMenu.index = actionMenu.index % #menuActions + 1
      end
    end
    local uiCandidate = closest or discovery
    local text = uiCandidate and uiCandidate.point.text
    local useTextUI = type(text) == 'table' and text.ui == true and text.enabled ~= false
      and not paused and not targetActive and GetResourceState('mz_lib') == 'started'
    local expanded = closest ~= nil and uiCandidate.id == closest.id
    local onScreen, x, y
    if useTextUI then
      local coords = text.discovery == true and uiCandidate.point.coords or playerCoords
      onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + (text.discovery == true and 0.0 or 0.35))
      if text.discovery == true and not onScreen then useTextUI = false end
    end
    local options, selectedOption = nil, nil
    if actionMenu and closest then
      options = {}
      local first = math.max(1, math.min(actionMenu.index - 2, #menuActions - 4))
      for index = first, math.min(first + 4, #menuActions) do options[#options + 1] = tostring(menuActions[index].label or 'Interagir') end
      selectedOption = actionMenu.index - first + 1
    end
    local textKey = useTextUI and (uiCandidate.id .. ':' .. tostring(expanded) .. ':' .. tostring(text.keyLabel or 'E') .. ':' .. tostring(text.label or 'Interagir') .. ':' .. tostring(actionMenu and actionMenu.index or '') .. ':' .. table.concat(options or {}, '|')) or nil
    local screenX, screenY = onScreen and x or 0.5, onScreen and y or 0.6
    if useTextUI and (displayedText ~= textKey or screenX ~= lastTextX or screenY ~= lastTextY) then
      exports['mz_lib']:textUI(tostring(text.label or 'Interagir'), {
        key = tostring(text.keyLabel or 'E'), variant = 'context', expanded = expanded,
        x = screenX, y = screenY, options = options, selected = selectedOption
      })
      lastTextX, lastTextY = screenX, screenY
      displayedText = textKey
    elseif displayedText ~= textKey then
      if displayedText and GetResourceState('mz_lib') == 'started' then
        exports['mz_lib']:hideTextUI()
      end
      displayedText = textKey
    end

    if closest and not paused and not (targetActive and type(closest.point.text) == 'table' and closest.point.text.ui == true) then
      local point = closest.point

      if closest.distance <= closest.interactDistance then
        local triggered = false
        local useMenu = point.actionMenu == true and #menuActions > 1 and GetResourceState('mz_lib') == 'started'
        if useMenu and IsControlJustReleased(0, tonumber(point.key) or Config.DefaultKey or 38) then
          if actionMenu then
            local action = menuActions[actionMenu.index]
            if action and action.active ~= false and triggerPointEvent(point, action) and visuals[point.id] then visuals[point.id].pressedAt = now end
            actionMenu = nil
          else
            actionMenu = { id = point.id, index = 1, entity = point.follow and point.follow.entity }
          end
          triggered = true
        elseif point.actionMenu == true and #menuActions <= 1 and IsControlJustReleased(0, tonumber(point.key) or Config.DefaultKey or 38) then
          if menuActions[1] and triggerPointEvent(point, menuActions[1]) and visuals[point.id] then visuals[point.id].pressedAt = now end
          triggered = true
        elseif not useMenu and type(point.actions) == 'table' and #point.actions > 0 then
          for _, action in ipairs(point.actions) do
            if action.active ~= false and IsControlJustReleased(0, tonumber(action.key) or point.key) then
              if triggerPointEvent(point, action) and visuals[point.id] then visuals[point.id].pressedAt = now end
              triggered = true
              break
            end
          end
        end
        if not triggered and IsControlJustReleased(0, tonumber(point.key) or Config.DefaultKey or 38) then
          if triggerPointEvent(point) and visuals[point.id] then visuals[point.id].pressedAt = now end
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
  if displayedText and GetResourceState('mz_lib') == 'started' then exports['mz_lib']:hideTextUI() end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    MZInteract.RemovePointsByOwner(resourceName)
  end
end)
