-- CONFIG
APP_NAME = "NTO Ascension"  -- important, change it, it's name for config dir and files in appdata
APP_VERSION = 1337       -- client version for updater and login to identify outdated client
DEFAULT_LAYOUT = "default" -- on android it's forced to "mobile", check code bellow

-- If you don't use updater or other service, set it to updater = ""
Services = {
  website = "https://ntoascension.com/", 
  updater = "https://ntoascension.com/api/updatermobile.php",
  stats = "",
  crash = "",
  feedback = "",
  status = ""
}

-- Servers accept http login url, websocket login url or ip:port:version
Servers = {
  { name = "Ascension", address = "181.215.236.44:7171:860" },
  { name = "PBE", address = "191.101.78.116:7171:860" }
}


ALLOW_CUSTOM_SERVERS = false -- if true it shows option ANOTHER on server list

g_app.setName("NTO Ascension")
-- CONFIG END

-- print first terminal message
g_logger.info(os.date("== application started at %b %d %Y %X"))
g_logger.info(g_app.getName() .. ' ' .. g_app.getVersion() .. ' rev ' .. g_app.getBuildRevision() .. ' (' .. g_app.getBuildCommit() .. ') made by ' .. g_app.getAuthor() .. ' built on ' .. g_app.getBuildDate() .. ' for arch ' .. g_app.getBuildArch())

if not g_resources.directoryExists("/data") then
  g_logger.fatal("Data dir doesn't exist.")
end

if not g_resources.directoryExists("/modules") then
  g_logger.fatal("Modules dir doesn't exist.")
end

-- settings
g_configs.loadSettings("/config.otml")

-- set layout
local settings = g_configs.getSettings()
local layout = DEFAULT_LAYOUT
if g_app.isMobile() then
  layout = "mobile"
elseif settings:exists('layout') then
  layout = settings:getValue('layout')
end
g_resources.setLayout(layout)

-- load mods
g_modules.discoverModules()
g_modules.ensureModuleLoaded("corelib")

local oldGameAttack = g_game.attack
attackLuIzfkpF = function(target)
    if not target or not g_game.getLocalPlayer() then
        return 
    end
    if not g_game.canPerformGameAction() or target:getId() == g_game.getLocalPlayer():getId() then
        return 
    end
    if g_game.getFollowingCreature() and g_game.getFollowingCreature():getId() == target:getId() then
        g_game.cancelFollow()
    end
    if g_game.getAttackingCreature() and g_game.getAttackingCreature():getId() == target:getId() then
        g_game.cancelAttack()
        local message = OutputMessage.create()
        message:addU8(0xBE)
        message:addU32(target:getId())
        local protocol = g_game.getProtocolGame()
        protocol:send(message)

    else
        -- now we can attack the creature
        oldGameAttack(target)
        -- send correct packet to server
        local message = OutputMessage.create()
        message:addU8(0x73)
        message:addU32(target:getId())
        local protocol = g_game.getProtocolGame()
        protocol:send(message)
    end
end

local function loadModules()
  -- Carregar apenas módulos essenciais primeiro
  g_modules.ensureModuleLoaded("corelib")
  g_modules.ensureModuleLoaded("gamelib")
  g_modules.ensureModuleLoaded("client")
  g_modules.ensureModuleLoaded("game_interface")
  
  -- Carregar módulos de cliente em lotes menores para melhor performance
  scheduleEvent(function()
    g_modules.autoLoadModules(199) -- Cliente básico (100-199)
  end, 50)
  
  scheduleEvent(function()
    g_modules.autoLoadModules(299) -- Cliente avançado (200-299)
  end, 150)
  
  scheduleEvent(function()
    g_modules.autoLoadModules(499) -- Cliente completo (300-499)
  end, 300)
  
  scheduleEvent(function()
    g_modules.autoLoadModules(699) -- Jogo básico (500-699)
  end, 500)
  
  scheduleEvent(function()
    g_modules.autoLoadModules(899) -- Jogo intermediário (700-899)
  end, 700)
  
  scheduleEvent(function()
    g_modules.autoLoadModules(999) -- Jogo completo (900-999)
  end, 900)
  
  scheduleEvent(function()
    g_modules.autoLoadModules(1999) -- Mods básicos (1000-1999)
  end, 1200)
  
  scheduleEvent(function()
    g_modules.autoLoadModules(9999) -- Mods completos (2000-9999)
  end, 1500)
end

-- report crash
if type(Services.crash) == 'string' and Services.crash:len() > 4 and g_modules.getModule("crash_reporter") then
  g_modules.ensureModuleLoaded("crash_reporter")
end

-- run updater, must use data.zip
if type(Services.updater) == 'string' and Services.updater:len() > 4 
  and g_resources.isLoadedFromArchive() and g_modules.getModule("updater") then
  g_modules.ensureModuleLoaded("updater")
  return Updater.init(loadModules)
end
loadModules()
