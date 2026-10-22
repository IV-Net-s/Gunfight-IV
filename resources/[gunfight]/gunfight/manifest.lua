name "gunfight"
description "Gunfight : manches courtes de 1v1 a 4v4, loadouts tournants, drapeau en prolongation, stats et Elo"
version "1.0"
author "axora"

server_scripts { "server/main.lua" } -- server/*.lua et lib/*.lua sont des modules (require)
client_scripts { "client/main.lua" }
ui_page "ui/index.html"
files { "ui/**" }
