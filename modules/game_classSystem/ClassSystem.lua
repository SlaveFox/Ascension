ClassSystem = {}

local classSystemButton -- Variável para o botão

function ClassSystem.init()
  -- Carregar a interface
  ClassSystem.window = g_ui.loadUI('ClassSystem.otui', modules.game_interface.getRootPanel())
  ClassSystem.window:hide()

  -- Registra o opcode no cliente
  ProtocolGame.registerExtendedOpcode(105, ClassSystem.onOpcode)
  -- Adiciona o botão ao menu superior
  classSystemButton = modules.client_topmenu.addRightGameToggleButton(
    'classSystemButton',
    tr('Class System') .. ' (Ctrl+Shift+C)',
    '/images/topbuttons/classinfo',
    toggleClassSystemWindow
  )
  classSystemButton:setOn(false)

  -- Configura atalho de teclado
  g_keyboard.bindKeyDown('Ctrl+Shift+C', toggleClassSystemWindow)
end

function ClassSystem.terminate()
  ClassSystem.window:destroy()
  ProtocolGame.unregisterExtendedOpcode(105)

  -- Remove o botão e o atalho
  if classSystemButton then
    classSystemButton:destroy()
    classSystemButton = nil
  end
  g_keyboard.unbindKeyDown('Ctrl+Shift+C')
end

-- Alterna a exibição da interface
function toggleClassSystemWindow()
  if ClassSystem.window:isVisible() then
    ClassSystem.window:hide()
    classSystemButton:setOn(false)
  else
    ClassSystem.window:show()
    ClassSystem.window:raise()
    ClassSystem.window:focus()
    classSystemButton:setOn(true)
  end
end


function ClassSystem.onOpcode(protocol, opcode, buffer)
  if opcode ~= 105 then return end

  local classData = json.decode(buffer)
  if not classData then
    return
  end

  local window = ClassSystem.window

  -- Atualiza o nome da classe
  window:getChildById('className'):setText(ClassSystem.getClassName(classData.classId))

  -- Verifica se o jogador possui uma classe
  if classData.classId == 0 then
    -- Jogador sem classe: oculta atributos e barra de experiência
    window:getChildById('attributesPanel'):setVisible(false)
    window:getChildById('experienceBar'):setVisible(false)
    window:getChildById('level'):setText("-")
  else
    -- Jogador com classe: exibe atributos e barra de experiência
    window:getChildById('attributesPanel'):setVisible(true)
    window:getChildById('experienceBar'):setVisible(true)
    window:getChildById('level'):setText(tostring(classData.classLevel or 0))

    -- Atualiza a barra de experiência
    local experienceBar = window:getChildById('experienceBar')
    if experienceBar then
      local currentExperience = classData.classExperience or 0
      local nextLevelExp = ClassSystem.getNextLevelExp(classData.classLevel)
      local percent = math.min((currentExperience / nextLevelExp) * 100, 100)

      local currentPercent = experienceBar:getPercent() or 0
      ClassSystem.animateExperienceBar(experienceBar, currentPercent, percent, 500) -- 500ms de duração

      -- Configura o tooltip
      local xpNeeded = nextLevelExp - currentExperience
      experienceBar:setTooltip("Experiência: " .. currentExperience .. " / " .. nextLevelExp ..
                               "\nFaltando: " .. xpNeeded)
    else
    end

    -- Atualiza os atributos
    local attributes = ClassSystem.getClassAttributes(classData.classId, classData)
    local attributesPanel = window:getChildById('attributesPanel')
    if attributesPanel then
      attributesPanel:getChildById('attribute1'):setText(attributes[1])
      attributesPanel:getChildById('attribute2'):setText(attributes[2])
      attributesPanel:getChildById('attribute3'):setText(attributes[3])
    end
  end

  window:raise()
  window:focus()
end

  
  
  function ClassSystem.getClassAttributes(classId, classData)
    local classAttributes = {
      [1] = { -- Dano
        "Dano: " .. (classData.damage or 0) .. "%",
        "Dano em Monstros: " .. (classData.mobDamage or 0) .. "%",
        "Fist Fighting: " .. (classData.fistFighting or 0)
      },
      [2] = { -- Tank
        "Proteção Geral: " .. (classData.protectionAll or 0) .. "%",
        "Proteção contra Monstros: " .. (classData.mobProtection or 0) .. "%",
        "Shielding: " .. (classData.shielding or 0)
      },
      [3] = { -- Suporte
        "Bônus de Cura: " .. (classData.healingBonus or 0) .. "%",
        "Roubo de Vida: " .. (classData.lifeLeech or 0) .. "%",
        "Nível Mágico: " .. (classData.magicLevel or 0)
      }
    }
  
    return classAttributes[classId] or {"-", "-", "-"}
  end

  function ClassSystem.getNextLevelExp(level)
    local expTable = {
      1000, 3000, 6000, 10000, 15000,
      21000, 28000, 36000, 45000, 55000,
      66000, 78000, 91000, 105000, 120000
    }
    return expTable[level + 1] or 0
  end

function ClassSystem.updateWidget(widget, text, errorMessage)
  if widget then
    widget:setText(text)
  else
    print(errorMessage)
  end
end

function ClassSystem.getClassName(classId)
  local classNames = {
    [1] = "Dano",
    [2] = "Tank",
    [3] = "Suporte"
  }
  return classNames[classId] or "Nenhuma"
end

function ClassSystem.animateExperienceBar(bar, fromPercent, toPercent, duration)
  local startTime = g_clock.millis()
  local endTime = startTime + duration

  local function update()
    local currentTime = g_clock.millis()
    local progress = math.min((currentTime - startTime) / duration, 1.0)
    local newPercent = fromPercent + (toPercent - fromPercent) * progress
    bar:setPercent(newPercent)

    if progress < 1.0 then
      scheduleEvent(update, 30) -- Atualiza a cada 30ms
    end
  end

  update()
end
