ClassSelection = {}

local classes = {
    { id = 1, name = "Dano" },
    { id = 2, name = "Tank" },
    { id = 3, name = "Suporte" }
}

function ClassSelection.init()
    ClassSelection.window = g_ui.loadUI('classSelection.otui', modules.game_interface.getRootPanel())
    if not ClassSelection.window then
        return
    end
    ClassSelection.window:hide()
    ProtocolGame.registerExtendedOpcode(106, ClassSelection.onOpcode)
end

function ClassSelection.terminate()
    -- Desregistra o opcode 106
    ProtocolGame.unregisterExtendedOpcode(106)
    if ClassSelection.window then
        ClassSelection.window:destroy()
    end
end

function ClassSelection.onOpcode(protocol, opcode, buffer)
  if opcode ~= 106 then return end

  if not buffer or buffer == "" then
      return
  end

  -- Decodifica o JSON recebido
  local success, classes = pcall(json.decode, buffer)
  if not success or not classes then
      return
  end
  -- Atualiza os botões e textos na interface
  for _, class in ipairs(classes) do
      if class.id == 1 then
          local danoText = ClassSelection.window:getChildById('danoText')
          local danoImage = ClassSelection.window:getChildById('danoImage')
          if danoText then danoText:setText(class.name) end
          if danoImage then danoImage:setTooltip(class.description) end
      elseif class.id == 2 then
          local tankText = ClassSelection.window:getChildById('tankText')
          local tankImage = ClassSelection.window:getChildById('tankImage')
          if tankText then tankText:setText(class.name) end
          if tankImage then tankImage:setTooltip(class.description) end
      elseif class.id == 3 then
          local suporteText = ClassSelection.window:getChildById('suporteText')
          local suporteImage = ClassSelection.window:getChildById('suporteImage')
          if suporteText then suporteText:setText(class.name) end
          if suporteImage then suporteImage:setTooltip(class.description) end
      end
  end

  -- Mostra a interface
  ClassSelection.show()
end


function ClassSelection.show()
    ClassSelection.showMainPanel()
    ClassSelection.window:show()
    ClassSelection.window:raise()
    ClassSelection.window:focus()
end

function ClassSelection.hide()
    if ClassSelection.window then
        ClassSelection.window:hide()
    end
end

function ClassSelection.showMainPanel()
    local mainPanel = ClassSelection.window:getChildById('mainPanel')
    local buttonPanel = ClassSelection.window:getChildById('buttonPanel')
    local detailPanel = ClassSelection.window:getChildById('detailPanel')

    if mainPanel and buttonPanel and detailPanel then
        mainPanel:setVisible(true)
        buttonPanel:setVisible(true)
        detailPanel:setVisible(false)
    else
    end
end

function ClassSelection.showClassDetail(className)
    local mainPanel = ClassSelection.window:getChildById('mainPanel')
    local buttonPanel = ClassSelection.window:getChildById('buttonPanel')
    local detailPanel = ClassSelection.window:getChildById('detailPanel')
    local infoPanel = detailPanel:getChildById('benefitsPanel')


    if not (mainPanel and buttonPanel and detailPanel and infoPanel) then
        return
    end

    -- Mapeia o nome da classe para o ID e benefícios
    local benefits = {
        ["Dano"] = {
            { text = "Aumento de dano: +2% por nível, com seu valor máximo em +30%", image = "images/Icons/Damage.png" },
            { text = "Dano contra mobs: +1% por nível, com seu valor máximo em +15%", image = "images/Icons/MobDamage.png" },
            { text = "Fist Fighting: +1 por nível, com seu valor máximo em +15", image = "images/Icons/Fist.png" },
        },
        ["Tank"] = {
            { text = "Proteção geral: +1% por nível, com seu valor máximo em +15%", image = "images/Icons/Protection.png" },
            { text = "Defesa contra mobs: +1% por nível, com seu valor máximo em +15%", image = "images/Icons/Defense.png" },
            { text = "Shielding: +2 por nível, com seu valor máximo em +30", image = "images/Icons/Shielding.png" },
        },
        ["Suporte"] = {
            { text = "Bônus de cura: +1% por nível, com seu valor máximo em +15%", image = "images/Icons/BonusHealing.png" },
            { text = "Roubo de vida: +1% por nível, com seu valor máximo em +15%", image = "images/Icons/LifeLeech.png" },
            { text = "Nível mágico: +1 por nível, com seu valor máximo em +15", image = "images/Icons/MagicLevel.png" },
        },
    }

    -- Define o ID da classe selecionada com base no nome
    for _, class in ipairs(classes) do
        if class.name == className then
            ClassSelection.selectedClassId = class.id
            break
        end
    end

    if not ClassSelection.selectedClassId then
        return
    end

    local selectedBenefits = benefits[className]
    if not selectedBenefits then
        return
    end

    for i, benefit in ipairs(selectedBenefits) do
    local benefitPanel = infoPanel:getChildById("benefit" .. i .. "Panel")
    if benefitPanel then
        local benefitImage = benefitPanel:getChildById("benefit" .. i .. "Image")
        local benefitText = benefitPanel:getChildById("benefit" .. i .. "Text")

        if benefitImage and benefitText then
            benefitImage:setImageSource(benefit.image)
            benefitText:setText(benefit.text)
        else
        end
    else
    end
end


    mainPanel:setVisible(false)
    buttonPanel:setVisible(false)
    detailPanel:setVisible(true)
    
end



function ClassSelection.selectClass()
  if not ClassSelection.selectedClassId then
      return
  end

  if not g_game.isOnline() then
      return
  end

  -- Envia o ID da classe selecionada ao servidor
  local data = tostring(ClassSelection.selectedClassId)
  local protocol = g_game.getProtocolGame()
  if not protocol then
      return
  end

  protocol:sendExtendedOpcode(106, data)

  -- Oculta a interface após a seleção
  ClassSelection.hide()
end

return ClassSelection
