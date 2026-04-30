fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mz_interact'
author 'Mazus'
description 'Centralized world interaction points for markers, blips and 3D text.'
version '0.1.0'

shared_scripts {
  'shared/config.lua'
}

client_scripts {
  'client/text3d.lua',
  'client/markers.lua',
  'client/blips.lua',
  'client/main.lua',
  'client/exports.lua'
}

files {
  'stream/mod_icon.ytd'
}
