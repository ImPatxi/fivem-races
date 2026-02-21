fx_version 'cerulean'
game 'gta5'

name 'patxi-carrera'
description 'Offroad Race System with Lobby, Checkpoints & Leaderboard'
author 'Patxi'
version '1.0.0'
repository 'https://github.com/patxi/patxi-carrera'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

lua54 'yes'

dependencies {
    'ox_lib',
    'ox_target',
    'qb-core',
}
