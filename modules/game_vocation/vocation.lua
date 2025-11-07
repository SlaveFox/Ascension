local vocationWindow = nil
local changeVocationWindow = nil
local changeVocationClicked = false
local newVocationButton = nil
local GameVocationOpcode = 10

Cache_G = {}

function init()
  connect(g_game, {
    onGameStart = naoexibir,
    onGameEnd   = offline,
  })

  vocationWindow = g_ui.loadUI("vocation", modules.game_interface.getRootPanel())
  newVocationButton = modules.client_topmenu.addRightGameToggleButton(
    'newVocationButton', tr('Change Vocation'), '/images/topbuttons/vocation', sendInfo
  )
  newVocationButton:setOn(false)

  -- registra o handler do opcode 10
  ProtocolGame.registerExtendedOpcode(GameVocationOpcode, onReceiveVocation)

  vocationWindow:hide()
end

function terminate()
  disconnect(g_game, {
    onGameStart = naoexibir,
    onGameEnd   = offline,
  })

  ProtocolGame.unregisterExtendedOpcode(GameVocationOpcode)
  if vocationWindow then vocationWindow:hide() end
end

function exibir()
  if vocationWindow:isVisible() then
    naoexibir()
  else
    vocationWindow:show()
  end
end

function offline()
  Cache_G = {}
end

function naoexibir()
  if vocationWindow then vocationWindow:hide() end
  changeVocationClicked = false
  if newVocationButton then newVocationButton:setOn(false) end
end

function sendInfo()
  if newVocationButton:isOn() then
    return naoexibir()
  end

  if Cache_G[1] then
    createVocationInfo(Cache_G[1])
  else
    -- ?? pede a lista via opcode 10
    g_game.getProtocolGame():sendExtendedOpcode(GameVocationOpcode, json.encode({ type = "openVocation" }))
  end
end

function onReceiveVocation(protocol, opcode, payload)
  local ok, json_data = pcall(function() return json.decode(payload or "") end)
  if not ok or type(json_data) ~= "table" then return end

  if json_data.type == "update" then
    Cache_G[1] = json_data
    createVocationInfo(json_data)

  elseif json_data.type == "refreshCache" and Cache_G[1] then
    for index, data in ipairs(Cache_G[1].vocations) do
      if data.name == json_data.name then
        Cache_G[1].vocations[index].unlocked = true
      end
    end
  end
end

function createVocationInfo(payload)
  newVocationButton:setOn(true)
  exibir()

  if payload.type ~= "update" then return end

  vocationWindow.description:setText(payload.category[1].description)

  -- filtros
  vocationWindow.PanelFilters:destroyChildren()
  for _, data in ipairs(payload.category) do
    local buttonCategory = g_ui.createWidget("VocationButtonCategory", vocationWindow.PanelFilters)
    buttonCategory:setText(data.category)
    buttonCategory.onClick = function()
      local children = vocationWindow.PanelVocations.VocationList:getChildren()
      vocationWindow.description:setText(data.description)
      for _, child in ipairs(children) do
        if data.category == "Todos" then
          child:setVisible(true)
        else
          child:setVisible(child:getId() == data.category)
        end
      end
    end
  end

  -- lista de vocações
  vocationWindow.PanelVocations.VocationList:destroyChildren()
  for _, data in ipairs(payload.vocations) do
    local imageVocation = g_ui.createWidget("imageVocation", vocationWindow.PanelVocations.VocationList)
    imageVocation:setTooltip(data.name)
    imageVocation:setId(data.category)

    if data.unlocked then
      imageVocation:setImageSource("images/desbloqueado")
    else
      imageVocation:setEnabled(false)
    end

    local outfit = g_ui.createWidget("CreatureOutfitChangeVocation", imageVocation)
    outfit.outfitBox:setOutfit({ type = data.outfit })
    outfit.outfitBox:setAnimate(true)
    outfit.outfitBox:setSize("125 125")
    outfit.outfitBox:setCenter(true)
    outfit.outfitBox:setMarginRight(30)
    outfit.outfitBox:setMarginTop(-30)
    outfit.outfitBox:setTooltip(data.name)

    imageVocation.vocationName:setText(data.name)

    local function choose()
      doChangeVocation(data.name)
    end
    imageVocation.onClick = choose
    outfit.outfitBox.onClick = choose
  end
end

function doChangeVocation(name)
  if changeVocationClicked then return end

  if changeVocationWindow then
    changeVocationWindow:hide()
    changeVocationWindow = nil
  end

  changeVocationClicked = true

  local yesCallback = function()
    if changeVocationWindow then
      changeVocationWindow:hide()
      changeVocationWindow = nil
    end
    changeVocationClicked = false
    g_game.getProtocolGame():sendExtendedOpcode(GameVocationOpcode, json.encode({ type = "changeVocation", name = name }))
    naoexibir()
  end

  local noCallback = function()
    if changeVocationWindow then
      changeVocationWindow:hide()
      changeVocationWindow = nil
    end
    changeVocationClicked = false
  end

  changeVocationWindow = displayGeneralBox(
    tr(name),
    tr("Deseja mudar para a vocação " .. name .. "?"),
    {
      { text = tr('Yes'), callback = yesCallback },
      { text = tr('No'),  callback = noCallback  },
      anchor = AnchorHorizontalCenter
    },
    yesCallback,
    noCallback
  )
end
