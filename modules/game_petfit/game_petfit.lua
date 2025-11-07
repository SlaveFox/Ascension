opcode = 16
profileImageOpcode = 33

PetData = {}
PetSelectionWindow = nil
petButton = nil

function init()
  ProtocolGame.registerExtendedOpcode(opcode, onRecvImagesOpcode)
  petButton = modules.client_topmenu.addLeftButton("PetButton", tr("Pets"), "/images/topbuttons/profile", requestImages, true)
end

function terminate()
  if PetSelectionWindow then
    PetSelectionWindow:destroy()
    PetSelectionWindow = nil
  end
  if petButton then
    petButton:destroy()
    petButton = nil
  end
  ProtocolGame.unregisterExtendedOpcode(opcode)
end

function requestImages(petName)
  -- print("chamou")
  g_game.getProtocolGame():sendExtendedOpcode(opcode, "getImages;" .. petName)
end

function onRecvImagesOpcode(pg, opcode, buffer)
  PetData = {}
  PetData.availableImages = buffer
  openPetWindow()
end

function openPetWindow()
  if not PetSelectionWindow then
    PetSelectionWindow = g_ui.displayUI("game_petfit.otui")
  end
  PetSelectionWindow:show()
  PetSelectionWindow:raise()
  PetSelectionWindow:focus()
  createPetImageButtons()
end

function closePetWindow()
  if PetSelectionWindow then
    PetSelectionWindow:setVisible(false)
	modules.game_interface.focusfaz()
  end
end

function parsePetImageData(data)
  local petDataList = {}
  if data == "" then return petDataList end

  local sections = data:split("|")
  local unlockedIDs = {}
  local lockedIDs = {}
  local inuseID = nil

  for _, section in ipairs(sections) do
    local key, value = section:match("([^:]+):(.*)")
    if key and value then
      if key == "unlocked" then
        for petID in value:gmatch("([^;]+)") do
          petID = tonumber(petID)
          if petID then
            table.insert(unlockedIDs, petID)
          end
        end
      elseif key == "locked" then
        for petID in value:gmatch("([^;]+)") do
          petID = tonumber(petID)
          if petID then
            table.insert(lockedIDs, petID)
          end
        end
      elseif key == "inuse" then
        inuseID = tonumber(value)
      end
    end
  end

  for _, petID in ipairs(unlockedIDs) do
    local status = (petID == inuseID) and "inuse" or "unlocked"
    table.insert(petDataList, petID .. ";" .. status)
  end

  for _, petID in ipairs(lockedIDs) do
    table.insert(petDataList, petID .. ";locked")
  end

  return petDataList
end

function createPetImageButtons()
  if not PetSelectionWindow then return end
  
  local panel = PetSelectionWindow:getChildById("Petbar")
  panel:destroyChildren()  

  local imagesInfo = PetData.availableImages
  if imagesInfo == "" then return end

  local allImages = parsePetImageData(imagesInfo)
  for _, petData in ipairs(allImages) do
    if petData ~= "" then
      local parts = petData:split(";")
      local petID = tonumber(parts[1])
      local status = tostring(parts[2])
      
      local button = g_ui.createWidget("UIButton", panel)
      button:setSize("100 100")
      button:raise()

      local outfitWidget = g_ui.createWidget("CreatureOutfit", button)
      outfitWidget:setSize("64 64")
      outfitWidget.outfitBox:setPhantom(true)
      outfitWidget.outfitBox:setOutfit({ type = petID })
      
      if status == "unlocked" or status == "inuse" then
        local tooltipText = tr("Clique para selecionar a skin")
        button:setTooltip(tooltipText)
        outfitWidget:setTooltip(tooltipText)
        local onClickFunc = function() 
          local params = {
            type = "Petfit",
            petOutfit = petID
          }
          g_game.getProtocolGame():sendExtendedOpcode(profileImageOpcode, json.encode(params))
          closePetWindow()
          -- displayInfoBox(tr("Pet"), tr("Seu pet foi alterado."))
        end
        button.onClick = onClickFunc
        outfitWidget.onClick = onClickFunc
        
        if status == "inuse" then
          -- button:setBackgroundColor("blue")
        else
          -- button:setBackgroundColor("green")
        end
      else
        local tooltipText = tr("Skin bloqueada.")
        button:setTooltip(tooltipText)
        outfitWidget:setTooltip(tooltipText)
        button.onClick = function()
          confirmBuySkin(petID)
        end
        outfitWidget.onClick = function()
          confirmBuySkin(petID)
        end
        function confirmBuySkin(petID)
          local cost = 15 -- Mesmo valor do servidor
          local message = "Deseja comprar a skin por " .. cost .. " pontos?"

          local box -- precisamos declarar fora para acessar no callback
          box = displayGeneralBox("Confirmação de Compra", message,
            {
              { text = "Sim", callback = function()
                  local params = {
                    type = "PetSkinBuy",
                    petOutfit = petID
                  }
                  g_game.getProtocolGame():sendExtendedOpcode(profileImageOpcode, json.encode(params))
                  box:destroy()
                end
              },
              { text = "Não", callback = function()
                  box:destroy()
                end
              }
            },
            nil, nil, true
          )
        end
        local icon = g_ui.createWidget("UIButton", button)
        icon:setSize("18 18")
        icon:setImageSource("assets/pet/bloqueado")
        icon:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
        icon:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        icon:setPhantom(true)
      end
    end
  end
end
