--==================================================
-- Newsletter System (by Raposo)
--==================================================

g_ui.importStyle('/modules/game_newsletter/newsletter.otui')

local window = nil
local floatingPanel = nil
local newsList = {}

--==================================================
-- Verificar se a notícia é recente (últimos 7 dias)
--==================================================
local function isRecent(dateString)
  local day, month, year = dateString:match("(%d+)/(%d+)/(%d+)")
  if not day or not month or not year then
    return false
  end

  local newsTime = os.time({day = tonumber(day), month = tonumber(month), year = tonumber(year)})
  local currentTime = os.time()

  return (currentTime - newsTime) <= (7 * 24 * 60 * 60)
end

--==================================================
-- Funções Principais
--==================================================
function init()
    connect(g_game, { 
        onGameEnd = close,
        onGameStart = onGameStart -- Evento correto ao logar no jogo
    })
    ProtocolGame.registerExtendedOpcode(207, onExtendedOpcode)
    local multipartBuffer = ""
    local isReceivingMultipart = false
end

function onGameStart()
    requestNewsFromServer() -- Chama aqui, após conexão
end


function terminate()
    disconnect(g_game, { onGameEnd = close })
    ProtocolGame.unregisterExtendedOpcode(207)
    close()
    saveFloatingPanelPosition()
    removeFloatingNewsPanel()
end

-- Requisitar notícias do servidor
function requestNewsFromServer()
    if g_game.isOnline() then
        g_game.getProtocolGame():sendExtendedOpcode(207, json.encode({ action = "requestNews" }))
    end
end
function isNewsRead(title)
    return g_settings.getBoolean('newsRead_' .. title) or false
end
function markNewsAsRead(title)
    g_settings.set('newsRead_' .. title, true)
    g_settings.save()
end


-- Receber dados do servidor
function onExtendedOpcode(protocol, opcode, buffer)
    local prefix = buffer:sub(1,1)
    local content = buffer:sub(2)

    if prefix == "S" then
        -- Start
        multipartBuffer = content
        isReceivingMultipart = true
    elseif prefix == "P" and isReceivingMultipart then
        -- Partial
        multipartBuffer = multipartBuffer .. content
    elseif prefix == "E" and isReceivingMultipart then
        -- End
        multipartBuffer = multipartBuffer .. content
        isReceivingMultipart = false

        -- Agora decodifica o JSON completo
        local success, data = pcall(function() return json.decode(multipartBuffer) end)
        if success and data and data.action == "newsData" then
            newsList = data.news
            populateNews(newsList)
            checkNewsFloatingPanel()
        else
            print("[Newsletter] Erro ao decodificar JSON multipart.")
        end
        multipartBuffer = ""
    else
        -- Caso especial: suporte a mensagens diretas (não multipart)
        local success, data = pcall(function() return json.decode(buffer) end)
        if success and data and data.action == "newsData" then
            newsList = data.news
            populateNews(newsList)
            checkNewsFloatingPanel()
        end
    end
end


function modules.game_newsletter.open()
    if window then
        window:show()
        window:raise()
        window:focus()
        return
    end

    window = g_ui.createWidget('NewsWindow', modules.game_interface.getRootPanel())
    populateNews(newsList)
end

function modules.game_newsletter.close()
    if window then
        window:destroy()
        window = nil
    end
end

function modules.game_newsletter.closeDetail(widget)
    widget:getParent():destroy()
end

--==================================================
-- Floating Panel: Salvar e Carregar Posição
--==================================================
function saveFloatingPanelPosition()
    if not floatingPanel then return end
    local pos = floatingPanel:getPosition()
    g_settings.set('newsFloatingPanelPosX', pos.x)
    g_settings.set('newsFloatingPanelPosY', pos.y)
    g_settings.save()
end

function createFloatingNewsPanel()
    if floatingPanel then return end

    floatingPanel = g_ui.createWidget('NewsFloatingPanel', modules.game_interface.getRootPanel())

    -- Carregar posição salva
    local posX = g_settings.getNumber('newsFloatingPanelPosX')
    local posY = g_settings.getNumber('newsFloatingPanelPosY')
    if posX and posY then
        floatingPanel:setPosition({x = posX, y = posY})
    end

    floatingPanel:show()
    floatingPanel:raise()

    floatingPanel.onClick = function()
        modules.game_newsletter.open()
    end

    floatingPanel.onDragEnd = function(widget, pos)
        saveFloatingPanelPosition()
    end
end

function removeFloatingNewsPanel()
    if floatingPanel then
        floatingPanel:destroy()
        floatingPanel = nil
    end
end

function checkNewsFloatingPanel()
    if not newsList then return end

    for _, data in ipairs(newsList) do
        if isRecent(data.date) and not isNewsRead(data.title) then
            createFloatingNewsPanel()
            return
        end
    end
    removeFloatingNewsPanel()
end


--==================================================
-- Abrir Detalhes
--==================================================
function openNewsDetail(data)
    local win = g_ui.createWidget('NewsDetailWindow', modules.game_interface.getRootPanel())
    if not win then return end

    win:show()
    win:raise()
    win:focus()

    win:getChildById('detailTitle'):setText(data.title)
    win:getChildById('detailDate'):setText(data.date)

    local panel = win:getChildById('detailDescriptionPanel')
    local scroll = panel:getChildById('detailDescriptionScroll')

    if not scroll then
        print("[ERROR] detailDescriptionScroll não encontrado!")
        return
    end

    scroll:destroyChildren()

    local label = g_ui.createWidget('UILabel', scroll)
    label:setText(data.description)
    label:setFont('verdana-11px-rounded')
    label:setColor('white')
    label:setTextAlign(AlignTop)
    label:setTextWrap(true)
    label:setTextAutoResize(true)

    -- Marca como lido
    markNewsAsRead(data.title)

    -- Atualiza apenas a lista da janela, se ela estiver aberta
    if window then
        populateNews(newsList)
    end

    -- Atualiza botão flutuante
    checkNewsFloatingPanel()

    win:getChildById('closeDetailButton').onClick = function()
        win:destroy()
    end
end

--==================================================
-- Preencher Lista
--==================================================
function populateNews(list)
    if not window then return end

    local panel = window:getChildById('newsListPanel')
    local scroll = panel:getChildById('newsListScroll')
    scroll:destroyChildren()

    for _, data in ipairs(list) do
        local entry = g_ui.createWidget('NewsEntry', scroll)

        local title = entry:getChildById('titleLabel')
        local date = entry:getChildById('dateLabel')
        local description = entry:getChildById('descriptionLabel')

        title:setText(data.title)
        date:setText(data.date)
        description:setText(data.description)

        if isRecent(data.date) and not isNewsRead(data.title) then
            local badge = g_ui.createWidget('UILabel', entry)
            badge:setText('NEW')
            badge:setColor('#FF4444')
            badge:setFont('baby-10')
            badge:setSize({width = 35, height = 18})

            badge:addAnchor(AnchorTop, "parent", AnchorTop)
            badge:addAnchor(AnchorLeft, "parent", AnchorLeft)
            badge:setMarginTop(5)
            badge:setMarginLeft(5)

            title:setMarginLeft(45)
        else
            title:setMarginLeft(10)
        end

        entry.onClick = function()
            openNewsDetail(data)
        end
    end
end
