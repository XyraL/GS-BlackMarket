fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'GS-BlackMarket'
author 'GooberScripts'
version '0.1.0'

ui_page 'web/index.html'

files {
  'web/index.html',
  'web/style.css',
  'web/app.js'
}

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'shared/sh_utils.lua',
  'shared/sh_adapter.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/sv_db.lua',
  'server/sv_main.lua'
}

client_scripts {
  'client/cl_main.lua'
}

dependencies {
  'oxmysql',
  'ox_lib'
}