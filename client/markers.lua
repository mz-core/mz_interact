MZInteractMarkers = {}

local requestedTextures = {}

local function clampColor(color)
  color = type(color) == 'table' and color or {}

  return {
    r = tonumber(color.r) or 255,
    g = tonumber(color.g) or 255,
    b = tonumber(color.b) or 255,
    a = tonumber(color.a) or 180
  }
end

local function getRotation(marker, defaults)
  local rotation = marker.rotation or defaults.rotation
  if type(rotation) == 'vector3' then
    return rotation
  end

  if type(rotation) == 'table' then
    return vec3(
      tonumber(rotation.x or rotation[1]) or 0.0,
      tonumber(rotation.y or rotation[2]) or 0.0,
      tonumber(rotation.z or rotation[3]) or 0.0
    )
  end

  return vec3(0.0, 0.0, 0.0)
end

local function mergeMarkerConfig(marker)
  local defaults = Config.DefaultMarker or {}
  marker = type(marker) == 'table' and marker or {}
  local markerType = tonumber(marker.type or defaults.type) or 2
  local hasTexture = marker.textureDict ~= nil and marker.textureName ~= nil
  local rotation = getRotation(marker, defaults)

  if markerType == 9 and hasTexture and marker.rotation == nil then
    rotation = Config.DefaultTextureMarkerRotation or vec3(90.0, 0.0, 0.0)
  end

  return {
    enabled = marker.enabled ~= nil and marker.enabled == true or defaults.enabled == true,
    type = markerType,
    textureDict = marker.textureDict,
    textureName = marker.textureName,
    rotation = rotation,
    size = marker.size or defaults.size or vec3(0.35, 0.35, 0.35),
    color = clampColor(marker.color or defaults.color),
    rotate = marker.rotate ~= nil and marker.rotate == true or defaults.rotate == true,
    bobUpAndDown = marker.bobUpAndDown ~= nil and marker.bobUpAndDown == true or defaults.bobUpAndDown == true,
    faceCamera = marker.faceCamera ~= nil and marker.faceCamera == true or defaults.faceCamera == true,
    drawOnEnts = marker.drawOnEnts ~= nil and marker.drawOnEnts == true or defaults.drawOnEnts == true
  }
end

local function requestTextureDictOnce(textureDict)
  if type(textureDict) ~= 'string' or textureDict == '' then
    return false
  end

  if HasStreamedTextureDictLoaded(textureDict) then
    return true
  end

  if requestedTextures[textureDict] ~= true then
    requestedTextures[textureDict] = true
    RequestStreamedTextureDict(textureDict, true)
  end

  return HasStreamedTextureDictLoaded(textureDict)
end

function MZInteractMarkers.draw(point)
  if type(point) ~= 'table' or not point.coords then
    return
  end

  local marker = mergeMarkerConfig(point.marker)
  if marker.enabled ~= true then
    return
  end

  local textureDict = nil
  local textureName = nil

  if marker.type == 9 and marker.textureDict and marker.textureName then
    if requestTextureDictOnce(marker.textureDict) then
      textureDict = marker.textureDict
      textureName = marker.textureName
    end
  end

  DrawMarker(
    marker.type,
    point.coords.x,
    point.coords.y,
    point.coords.z,
    0.0,
    0.0,
    0.0,
    marker.rotation.x or 0.0,
    marker.rotation.y or 0.0,
    marker.rotation.z or 0.0,
    marker.size.x or 0.35,
    marker.size.y or 0.35,
    marker.size.z or 0.35,
    marker.color.r,
    marker.color.g,
    marker.color.b,
    marker.color.a,
    marker.bobUpAndDown,
    marker.faceCamera,
    2,
    marker.rotate,
    textureDict,
    textureName,
    marker.drawOnEnts
  )
end
