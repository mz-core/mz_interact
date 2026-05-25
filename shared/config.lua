Config = Config or {}

Config.Debug = false

Config.DefaultKey = 38 -- E
Config.DefaultDrawDistance = 20.0
Config.DefaultInteractDistance = 2.0
Config.DefaultLoopSleep = 1000
Config.NearLoopSleep = 0
Config.InteractCooldownMs = 800

Config.UseMzCorePermissions = false
Config.PermissionFallbackAllow = false

-- Optional export names tried when permission exists and mz_core is started.
-- The system calls each export safely until one returns a non-nil result.
Config.PermissionExports = {
  'HasPermission',
  'HasPerm',
  'CanAccess',
  'HasGroup'
}

-- Backward-compatible single export option, if you want to force one name.
-- Example: Config.PermissionExportName = 'HasPermission'
Config.PermissionExportName = nil

Config.DefaultMarker = {
  enabled = true,
  type = 2,
  rotation = vec3(0.0, 0.0, 0.0),
  size = vec3(0.35, 0.35, 0.35),
  color = { r = 80, g = 180, b = 255, a = 180 },
  rotate = true,
  bobUpAndDown = false,
  faceCamera = false,
  drawOnEnts = false
}

-- Default vertical rotation for custom texture markers using marker type 9.
-- If an icon appears lying on the ground, keep this at 90.0 on X.
-- You can override per point with marker.rotation = vec3(x, y, z).
Config.DefaultTextureMarkerRotation = vec3(90.0, 0.0, 0.0)

Config.DefaultText = {
  enabled = true,
  label = '[E] Interagir',
  offsetZ = 0.35,
  scale = 0.32,
  font = 4,
  color = { r = 255, g = 255, b = 255, a = 230 },
  background = { r = 0, g = 0, b = 0, a = 95 }
}

Config.ExamplePoints = false

-- Example only. Keep disabled by default.
Config.Examples = {
  {
    id = 'garage_praca',
    coords = vec3(215.5, -810.2, 30.7),
    interactDistance = 2.0,
    permission = nil,

    marker = {
      enabled = true,
      type = 9,
      textureDict = 'mod_icon',
      textureName = 'garage',
      rotation = vec3(90.0, 0.0, 0.0),
      size = vec3(0.75, 0.75, 0.75),
      color = { r = 255, g = 255, b = 255, a = 230 },
      rotate = true,
      bobUpAndDown = true,
      faceCamera = true
    },

    blip = {
      enabled = true,
      sprite = 357,
      color = 3,
      scale = 0.75,
      label = 'Garagem'
    },

    text = {
      enabled = true,
      label = '[E] Abrir garagem'
    },

    event = {
      type = 'client',
      name = 'mz_garagem:client:open',
      args = {}
    }
  }
}
