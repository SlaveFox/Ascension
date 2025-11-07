minimapWidget = nil
-- minimapButton = nil
minimapWindow = nil
otmm = true
preloaded = false
fullmapView = false
oldZoom = nil
oldPos = nil

-- Cache otimizado para minimapa
local minimapCache = {}
local lastMinimapUpdate = 0
local MINIMAP_UPDATE_THROTTLE = 33 -- ~30 FPS para minimapa
local minimapUpdateEvent = nil

local MAP_COMPOSITIONS, COMPOSITIONS = {}, {}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Konohagakure", position = {x=1011, y=1031, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Sunagakure", position = {x=431, y=802, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Vila Takumi", position = {x=1288, y=518, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Monte Myoboku", position = {x=415, y=1668, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Forest", position = {x=710, y=722, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Amegakure No Sato", position = {x=666, y=1440, z=6}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Suna Camp", position = {x=437, y=1010, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Iwagakure Island", position = {x=476, y=679, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Iwagakure", position = {x=449, y=501, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Yukigakure", position = {x=1069, y=777, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Vale do Fim", position = {x=1468, y=956, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Kumogakure", position = {x=849, y=1365, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Templo do Fogo", position = {x=1373, y=776, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "New Island", position = {x=223, y=1412, z=7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Ilha Genbu", position = {x=1553, y=593, z=7}}

MAPMARK_TICK = 0
MAPMARK_QUESTION = 1
MAPMARK_EXCLAMATION = 2
MAPMARK_STAR = 3
MAPMARK_CROSS = 4
MAPMARK_TEMPLE = 5
MAPMARK_KISS = 6
MAPMARK_SHOVEL = 7
MAPMARK_SWORD = 8
MAPMARK_FLAG = 9
MAPMARK_LOCK = 10
MAPMARK_BAG = 11
MAPMARK_SKULL = 12
MAPMARK_DOLLAR = 13
MAPMARK_REDNORTH = 14
MAPMARK_REDSOUTH = 15
MAPMARK_REDEAST = 16
MAPMARK_REDWEST = 17
MAPMARK_GREENNORTH = 18
MAPMARK_GREENSOUTH = 19

local GUIDES = {}
GUIDES["Ascension"] = {
    {position = {x = 1021, y = 976, z = 7}, type = MAPMARK_SWORD, description = "Trainer Defense"},
    {position = {x = 1155, y = 743, z = 7}, type = MAPMARK_SWORD, description = "Trainer Defense"},
    {position = {x = 1300, y = 486, z = 7}, type = MAPMARK_SWORD, description = "Trainer"},
    {position = {x = 431, y = 818, z = 7}, type = MAPMARK_SWORD, description = "Trainer Defense"},
    {position = {x = 669, y = 1475, z = 6}, type = MAPMARK_SWORD, description = "Trainer Defense"},
    {position = {x = 1509, y = 481, z = 7}, type = MAPMARK_SWORD, description = "Trainer Defense"},
    {position = {x = 899, y = 1325, z = 1}, type = MAPMARK_SWORD, description = "Trainer Defense"},
    {position = {x = 167, y = 1432, z = 7}, type = MAPMARK_SWORD, description = "Trainer Defense"},
    {position = {x = 452, y = 463, z = 7}, type = MAPMARK_SWORD, description = "Trainer"},
    {position = {x = 1016, y = 970, z = 7}, type = MAPMARK_SWORD, description = "Rikudou Event Arena"},
    {position = {x = 1008, y = 961, z = 7}, type = MAPMARK_BAG, description = "Mercante"},
    {position = {x = 1008, y = 972, z = 7}, type = MAPMARK_BAG, description = "Blessing"},
    {position = {x = 1028, y = 966, z = 7}, type = MAPMARK_BAG, description = "Mercenário"},
    {position = {x = 1022, y = 959, z = 7}, type = MAPMARK_BAG, description = "Banker"},
    {position = {x = 1496, y = 501, z = 7}, type = MAPMARK_BAG, description = "Chinatsu Vip"},
    {position = {x = 1508, y = 473, z = 7}, type = MAPMARK_BAG, description = "Staminer"},
    {position = {x = 1023, y = 1017, z = 7}, type = MAPMARK_BAG, description = "Hiromi Utility's"},
    {position = {x = 1016, y = 1017, z = 7}, type = MAPMARK_BAG, description = "Chinatsu Potions"},
    {position = {x = 1038, y = 1021, z = 7}, type = MAPMARK_KISS, description = "Fonte Termal"},
    {position = {x = 913, y = 1340, z = 3}, type = MAPMARK_KISS, description = "Fonte Termal"},
    {position = {x = 429, y = 786, z = 8}, type = MAPMARK_KISS, description = "Fonte Termal"},
    {position = {x = 970, y = 1023, z = 7}, type = MAPMARK_SWORD, description = "Arena PVP"},
    {position = {x = 1022, y = 963, z = 6}, type = MAPMARK_SWORD, description = "Dungeons"},
    {position = {x = 1023, y = 963, z = 5}, type = MAPMARK_STAR, description = "Initial Items"},
    {position = {x = 1013, y = 954, z = 6}, type = MAPMARK_QUESTION, description = "Minoru"},
    {position = {x = 902, y = 1310, z = 11}, type = MAPMARK_QUESTION, description = "Minoru"},
    {position = {x = 1258, y = 893, z = 7}, type = MAPMARK_SWORD, description = "Jinchuuriki Kyuubi"},
    {position = {x = 1085, y = 1218, z = 7}, type = MAPMARK_SWORD, description = "Jinchuuriki Nanabi"},
    {position = {x = 701, y = 1113, z = 7}, type = MAPMARK_STAR, description = "Akatsuki Alliance"},
    {position = {x = 1328, y = 1343, z = 7}, type = MAPMARK_SWORD, description = "Raiga Kurosuki Boss"},
    {position = {x = 477, y = 931, z = 7}, type = MAPMARK_SWORD, description = "Kankuro Boss"},
    {position = {x = 232, y = 839, z = 7}, type = MAPMARK_SWORD, description = "Jinchuuriki Shukaku"},
    {position = {x = 431, y = 788, z = 7}, type = MAPMARK_BAG, description = "Temari [NPC]"},
    {position = {x = 549, y = 899, z = 7}, type = MAPMARK_BAG, description = "Deidara [NPC]"},
    {position = {x = 905, y = 464, z = 7}, type = MAPMARK_BAG, description = "Hidan [NPC]"},
    {position = {x = 1307, y = 1310, z = 7}, type = MAPMARK_BAG, description = "Itachi [NPC]"},
    {position = {x = 1166, y = 1169, z = 7}, type = MAPMARK_BAG, description = "Sasori [NPC]"},
    {position = {x = 989, y = 1003, z = 7}, type = MAPMARK_BAG, description = "Markinhos [NPC]"},
    {position = {x = 895, y = 1310, z = 11}, type = MAPMARK_BAG, description = "Chinatsu"},
    {position = {x = 546, y = 876, z = 7}, type = MAPMARK_SWORD, description = "Temari Boss"},
    {position = {x = 739, y = 934, z = 7}, type = MAPMARK_SWORD, description = "Jinchuuriki Yonbi"},
    {position = {x = 867, y = 903, z = 5}, type = MAPMARK_STAR, description = "Anbu Alliance"},
    {position = {x = 1195, y = 690, z = 7}, type = MAPMARK_SWORD, description = "Jinchuuriki Sanbi"},
    {position = {x = 1052, y = 544, z = 7}, type = MAPMARK_SWORD, description = "Naruto Boss"},
    {position = {x = 898, y = 1330, z = 12}, type = MAPMARK_SWORD, description = "Arena PVP"},
    {position = {x = 1146, y = 368, z = 7}, type = MAPMARK_SWORD, description = "Jinchuuriki Rokubi"},
    {position = {x = 491, y = 562, z = 7}, type = MAPMARK_SWORD, description = "Jinchuuriki Gobi"},
    {position = {x = 508, y = 1346, z = 7}, type = MAPMARK_SWORD, description = "Jinchuuriki Nibi"},
    {position = {x = 351, y = 1324, z = 7}, type = MAPMARK_SWORD, description = "Jinchuuriki Hachibi"},
    {position = {x = 538, y = 1207, z = 7}, type = MAPMARK_SWORD, description = "Hashirama Boss"},
    {position = {x = 924, y = 1066, z = 7}, type = MAPMARK_SWORD, description = "Kakashi Boss"},
    {position = {x = 534, y = 765, z = 6}, type = MAPMARK_SWORD, description = "Sasuke Boss"},
    {position = {x = 1055, y = 1179, z = 7}, type = MAPMARK_SWORD, description = "Lee Boss"},
    {position = {x = 1282, y = 504, z = 7}, type = MAPMARK_LOCK, description = "Temple"},
    {position = {x = 1023, y = 969, z = 7}, type = MAPMARK_LOCK, description = "Temple"},
    {position = {x = 432, y = 812, z = 7}, type = MAPMARK_LOCK, description = "Temple"},
    {position = {x = 678, y = 1452, z = 6}, type = MAPMARK_LOCK, description = "Temple"},
    {position = {x = 439, y = 438, z = 6}, type = MAPMARK_LOCK, description = "Temple"},
    {position = {x = 1156, y = 719, z = 6}, type = MAPMARK_LOCK, description = "Temple"},
    {position = {x = 871, y = 1348, z = 3}, type = MAPMARK_LOCK, description = "Temple"},
    {position = {x = 204, y = 1432, z = 7}, type = MAPMARK_LOCK, description = "Temple"},
    {position = {x = 881, y = 1305, z = 3}, type = MAPMARK_STAR, description = "Mercenary Alliance"},
    {position = {x = 1202, y = 1378, z = 10}, type = MAPMARK_BAG, description = "Kakuzu {Banker}"},
    {position = {x = 1202, y = 1379, z = 10}, type = MAPMARK_BAG, description = "Hidan {Blesser}"},
    {position = {x = 1212, y = 1460, z = 10}, type = MAPMARK_BAG, description = "Sasori {Trader}"},
    {position = {x = 1289, y = 1428, z = 10}, type = MAPMARK_BAG, description = "Zetsu {Healer}"},
    {position = {x = 1337, y = 1406, z = 10}, type = MAPMARK_BAG, description = "Kisame {Stamina}"},
    {position = {x = 1331, y = 1406, z = 10}, type = MAPMARK_KISS, description = "Fonte Termal"},
    {position = {x = 860, y = 894, z = 5}, type = MAPMARK_EXCLAMATION, description = "Danzo Shimura {Anbu}"},
    {position = {x = 899, y = 1311, z = 12}, type = MAPMARK_EXCLAMATION, description = "Mercenary Leader {Mercenary}"},
    {position = {x = 852, y = 859, z = 6}, type = MAPMARK_SWORD, description = "Trainer Defense"},
    {position = {x = 1251, y = 1446, z = 10}, type = MAPMARK_SWORD, description = "Trainer Defense"},
    {position = {x = 879, y = 835, z = 6}, type = MAPMARK_SWORD, description = "Arena PVP"},
    {position = {x = 1225, y = 1400, z = 10}, type = MAPMARK_SWORD, description = "Arena PVP"},
    {position = {x = 898, y = 1330, z = 12}, type = MAPMARK_SWORD, description = "Arena PVP"},
}

local guideEnabled = true
local guideMarks = {}

local function removeGuides()
    for k, v in pairs(guideMarks) do
        v:destroy()
    end
    guideMarks = {}
end

local function addGuides()
    for k, city in pairs(GUIDES) do
        for _, mark in pairs(city) do
            guideMarks[#guideMarks + 1] = minimapWidget:addFlag(mark.position, mark.type, tr(mark.description))
        end
    end
end

function setGuidesDisplay(v)
    guideEnabled = v
    if (not guideEnabled) then
        removeGuides()
    end
end

function init()
  minimapWindow = g_ui.loadUI('minimap', modules.game_interface.getRightPanel())
  minimapWindow:setContentMinimumHeight(64)

  -- if not minimapWindow.forceOpen then
    -- minimapButton = modules.client_topmenu.addRightGameToggleButton('minimapButton', 
      -- tr('Minimap') .. ' (Ctrl+M)', '/images/topbuttons/minimap', toggle)
    -- minimapButton:setOn(true)
  -- end

  minimapWidget = minimapWindow:recursiveGetChildById('minimap')

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyPress('Alt+Left', function() minimapWidget:move(1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Right', function() minimapWidget:move(-1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Up', function() minimapWidget:move(0,1) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Down', function() minimapWidget:move(0,-1) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+M', toggle)
  g_keyboard.bindKeyDown('Ctrl+Shift+M', toggleFullMap)

  minimapWindow:setup()

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  if g_game.isOnline() then
    saveMap()
  end

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyPress('Alt+Left', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Right', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Up', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Down', gameRootPanel)
  g_keyboard.unbindKeyDown('Ctrl+M')
  g_keyboard.unbindKeyDown('Ctrl+Tab')

  minimapWindow:destroy()
  -- minimapButton:destroy()
end

function toggle()
	if minimapWindow:isVisible() then
		minimapWindow:close()
	else
		minimapWindow:open()
	end
end

function onMiniWindowClose()
  -- minimapButton:setOn(false)
end

function preload()
  loadMap(false)
  preloaded = true
end

function online()
  loadMap(not preloaded)
  updateCameraPosition()
end

function offline()
  saveMap()
end

local function loadCompositions()
    -- g_minimap.loadImage('/images/map', {x = 0, y = 0, z = 7}, 0.5)

    for _, composition in pairs(MAP_COMPOSITIONS) do
        local flag = g_ui.createWidget('MinimapFlag')
        local flag2 = g_ui.createWidget('MinimapFlag')
        minimapWidget:insertChild(1, flag)
        minimapWidget:insertChild(1, flag2)
        flag.pos = composition.position
        flag:setText(composition.text)
        flag:setFont("verdana-11px-monochrome")
        flag:setColor("#FAFAFA")
        flag:setTextAutoResize(true)
        flag:setVisible(true)
        flag2.pos = composition.position
        flag2:setText(composition.text)
        flag2:setFont("verdana-11px-monochrome")
        flag2:setColor("#000000")
        flag2:setTextAutoResize(true)
        flag2:setVisible(true)
        flag2:setMarginTop(1)
        flag2:setMarginLeft(2)
        minimapWidget:centerInPosition(flag, flag.pos)
        COMPOSITIONS[#COMPOSITIONS + 1] = flag
        minimapWidget:centerInPosition(flag2, flag2.pos)
        COMPOSITIONS[#COMPOSITIONS + 1] = flag2
    end
end

local function toggleCompositions()
    for _, composition in pairs(COMPOSITIONS) do
        composition:setVisible(fullmapView)
    end
end

function loadMap(clean, ignoreConfig)
  local protocolVersion = g_game.getProtocolVersion()

  if clean then
    g_minimap.clean()
  end

  if (not ignoreConfig) then
      if otmm then
        local minimapFile = '/minimap.otmm'
        if g_resources.fileExists(minimapFile) then
          g_minimap.loadOtmm(minimapFile)
        end
      else
        local minimapFile = '/minimap_' .. protocolVersion .. '.otcm'
        if g_resources.fileExists(minimapFile) then
          g_map.loadOtcm(minimapFile)
        end
      end
  end
  loadCompositions()
  removeGuides()
  if (guideEnabled) then
    addGuides()
  end
  minimapWidget:load()
end

function saveMap()
  local protocolVersion = g_game.getProtocolVersion()
  if otmm then
    local minimapFile = '/minimap.otmm'
    g_minimap.saveOtmm(minimapFile)
  else
    local minimapFile = '/minimap_' .. protocolVersion .. '.otcm'
    g_map.saveOtcm(minimapFile)
  end
  minimapWidget:save()
end

function updateCameraPosition()
  local now = g_clock.millis()
  if now - lastMinimapUpdate < MINIMAP_UPDATE_THROTTLE then
    return
  end
  lastMinimapUpdate = now
  
  updateCameraPositionOptimized()
end

function updateCameraPositionOptimized()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  if not pos then return end
  
  -- Cache da posição para evitar atualizações desnecessárias
  local posKey = pos.x .. "," .. pos.y .. "," .. pos.z
  if minimapCache.lastPosition == posKey then
    return
  end
  minimapCache.lastPosition = posKey
  
  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(player:getPosition())
    end
    minimapWidget:setCrossPosition(player:getPosition())
  end
end

function toggleFullMap()
  if not fullmapView then
    fullmapView = true
    minimapWindow:hide()
    minimapWidget:setParent(modules.game_interface.getRootPanel())
    minimapWidget:fill('parent')
    minimapWidget:setAlternativeWidgetsVisible(true)
  else
    fullmapView = false
    minimapWidget:setParent(minimapWindow:getChildById('contentsPanel'))
    minimapWidget:fill('parent')
    minimapWindow:show()
    minimapWidget:setAlternativeWidgetsVisible(false)
  end

  local zoom = oldZoom or 0
  local pos = oldPos or minimapWidget:getCameraPosition()
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()
  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end

function toggleFullMapVisible()
    if (fullmapView) then
        toggleFullMap()
    end
end

function openSearch()
	searchWindow = g_ui.displayUI('search.otui')
end

function searchMonster()
  local monsterName = searchWindow:getChildById('searchMonster'):getText()
  if monsterName ~= "" then
    clearMarkMap()
    g_game.talk("!radar " .. monsterName)
    searchWindow:destroy()
  end
  searchWindow:destroy()
end	

function clearMarkMap()
  if minimapWidget then
    minimapWidget:clearAllFlags()
  end
end

_G.clearMarkMap = clearMarkMap