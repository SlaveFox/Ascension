-- chunkname: @/modules/profile_image_selector/script.lua

opcode = 14
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

function requestImages()
  g_game.getProtocolGame():sendExtendedOpcode(opcode, "getPets")
end

function onRecvImagesOpcode(pg, opcode, buffer)
  PetData = {}
  PetData.availableImages = buffer
  
  openPetWindow()
end

function openPetWindow()
  if PetSelectionWindow and PetSelectionWindow:isVisible() then
    closePetWindow()
    return
  end
  if not PetSelectionWindow then
    PetSelectionWindow = g_ui.displayUI("game_pet.otui")
  end
  PetSelectionWindow:setVisible(true)
  PetSelectionWindow:raise()
  PetSelectionWindow:focus()
  createPetImageButtons()
end


function closePetWindow()
  if PetSelectionWindow then
    PetSelectionWindow:setVisible(false)
  end
end

function createPetImageButtons()
  if not PetSelectionWindow then return end
  
  local panel = PetSelectionWindow:getChildById("Petbar")
  panel:destroyChildren()  

  local imagesInfo = PetData.availableImages
  if imagesInfo == "" then return end

  local allImages = imagesInfo:split(",")

  table.sort(allImages, function(a, b)
    local partsA = a:split(";")
    local partsB = b:split(";")
    local statusA = tostring(partsA[2])
    local statusB = tostring(partsB[2])
    local orderA = (statusA == "locked") and 2 or 1
    local orderB = (statusB == "locked") and 2 or 1
    return orderA < orderB
  end)

  for _, imgData in ipairs(allImages) do
  if imgData ~= "" then
    local parts = imgData:split(";")
    local petName = tostring(parts[1])
    local status = tostring(parts[2])
    local outfit = tonumber(parts[3]) or 0

local button = g_ui.createWidget("PetButton", panel)
button:setSize("100 100") -- OK manter, se não for fixado no .otui

local creatureOutfit = g_ui.createWidget("UICreature", button)
creatureOutfit:setOutfit({ type = outfit })
creatureOutfit:setSize("90 90")
creatureOutfit:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
creatureOutfit:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
creatureOutfit:setPhantom(true)
if status == "inuse" then
  button:setBorderColor("#32CD32")
end



    local tooltipText = (status == "inuse" and tr("Pet %s em uso", petName)) or
                        (status == "unlocked" and tr("Pet %s", petName)) or
                        tr("Pet %s Bloqueado", petName)
    button:setTooltip(tooltipText)

    if status == "unlocked" or status == "inuse" then
      button.onClick = function()
        local params = {
          type = "Pet",
          petN = petName
        }
        g_game.getProtocolGame():sendExtendedOpcode(profileImageOpcode, json.encode(params))
        closePetWindow()
      end
    else
      button.onClick = function() end
      local icon = g_ui.createWidget("UIButton", button)
      icon:setSize("14 14")
      icon:setMarginLeft(10)
      icon:setMarginTop(10)
      icon:setImageSource("assets/pet/bloqueado")
      icon:addAnchor(AnchorTop, "parent", AnchorTop)
      icon:addAnchor(AnchorLeft, "parent", AnchorLeft)
      icon:setPhantom(true)
    end
  end
end
end