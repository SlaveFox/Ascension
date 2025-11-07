-- Shop Client Module (compatível com GameShop:handleOpcode ? opcode 40)

local shopWindow
local buyPanel
local transferPanel
local buttonShop = nil

local gameShopOpcode = 40
local categoryPattern = "Promocao"
local zShopCache = {}

-- Montagem de mensagens multipartes S/P/E
local _multiBuf = nil

local function _resetMulti()
  _multiBuf = nil
end

local function _appendMulti(kind, chunk)
  if kind == 'S' then
    _multiBuf = chunk or ""
  elseif kind == 'P' then
    if _multiBuf then _multiBuf = _multiBuf .. (chunk or "") end
  elseif kind == 'E' then
    if not _multiBuf then
      return nil -- nada para fechar
    end
    -- E pode vir só com "E" vazio quando coube em 1 parte no server
    if chunk and #chunk > 0 then
      _multiBuf = _multiBuf .. chunk
    end
    local done = _multiBuf
    _multiBuf = nil
    return done
  end
  return nil
end

local function _sendJSON(opcode, tbl)
  g_game.getProtocolGame():sendExtendedOpcode(opcode, json.encode(tbl))
end

-- =========================
-- Ciclo de vida
-- =========================
function init()
  connect(g_game, { onGameStart = naoexibir, onGameEnd = offline })

  shopWindow = g_ui.loadUI("shop", modules.game_interface.getRootPanel())
  shopWindow:hide()

  -- Painel de depósito (se existir no seu .otui)
  local depositButton = shopWindow:getChildById('depositButton')
  local depositPanel  = shopWindow:getChildById('depositPanel')
  if depositButton and depositPanel then
    local closeDeposit = depositPanel:getChildById('closeDeposit')
    if closeDeposit then
      closeDeposit.onClick = function() depositPanel:hide() end
    end
    depositButton.onClick = function() depositPanel:show() end
  end

  buttonShop = modules.client_topmenu.addRightGameToggleButton('shopSystem', "Shop", '/images/topbuttons/shop', sendShopInfo, true)

  -- IMPORTANTE: registrar handler "não-JSON" para suportar S/P/E e JSON simples
  ProtocolGame.registerExtendedOpcode(gameShopOpcode, onShopOpcodeRaw)
end

function terminate()
  disconnect(g_game, { onGameStart = naoexibir, onGameEnd = offline })
  ProtocolGame.unregisterExtendedOpcode(gameShopOpcode)
  naoexibir()
end

function offline()
  zShopCache = {}
  _resetMulti()
end

-- =========================
-- Abertura/fechamento
-- =========================
function sendShopInfo(forceStayOn)
  -- Se o botão já está ON e não for forçado, fecha
  if buttonShop:isOn() and not forceStayOn then
    return naoexibir()
  end

  if zShopCache[1] then
    doCreateShopInfo(zShopCache[1], forceStayOn)
    buttonShop:setOn(true)
  else
    -- Novo protocolo: action="open" no opcode 40
    _sendJSON(gameShopOpcode, { action = "open" })
  end
end

function exibir()
  shopWindow:show()
  shopWindow:raise()
  shopWindow:focus()
end

function naoexibir()
  if shopWindow then shopWindow:hide() end
  closePanelBuying()
  closeTransfer()
  if buttonShop then buttonShop:setOn(false) end
end

-- =========================
-- Recepção (opcode 40)
-- =========================
function onShopOpcodeRaw(protocol, opcode, buffer)
  -- buffer pode ser:
  -- 1) mensagem multipart S/P/E: começa com 'S','P' ou 'E'
  -- 2) JSON direto (ex.: reloadShop): começa com '{'
  if type(buffer) ~= 'string' or #buffer == 0 then return end

  local head = buffer:sub(1,1)
  if head == 'S' or head == 'P' or head == 'E' then
    local chunk = buffer:sub(2)
    local completed = _appendMulti(head, chunk)
    if completed then
      local ok, payload = pcall(json.decode, completed)
      if ok and type(payload) == "table" then
        onPlayerReceiveShop(nil, opcode, payload)
      else
      end
    end
    return
  end

  -- Tenta JSON direto
  if head == '{' or head == '[' then
    local ok, payload = pcall(json.decode, buffer)
    if ok and type(payload) == "table" then
      onPlayerReceiveShop(nil, opcode, payload)
    else
    end
  else
  end
end

-- Router lógico do payload JSON
function onPlayerReceiveShop(_, _, payload)
  if payload.type == "openShop" then
    doCreateShopInfo(payload)
    zShopCache[1] = payload
    if buttonShop then buttonShop:setOn(true) end

  elseif payload.type == "reloadShop" then
    if zShopCache[1] then
      zShopCache[1].premiumPoints = payload.premiumPoints
    end
    sendShopInfo(true)
  elseif payload.type == "error" and payload.message then
    modules.game_textmessage.displayGameMessage("Shop: " .. payload.message)
  end
end

-- =========================
-- Construção de UI
-- =========================
function doCreateShopInfo(shopData, forceStayOn)
  if not shopWindow:isVisible() and not forceStayOn then
    exibir()
  end

  if shopWindow.premiumPoints then
    shopWindow.premiumPoints:setText(shopData.premiumPoints)
    shopWindow.premiumPoints:setTooltip("Premium points: " .. shopData.premiumPoints)
  end

  -- Categorias
  if shopWindow.PanelCategory and shopWindow.PanelCategory.categoryList then
    shopWindow.PanelCategory.categoryList:destroyChildren()

    for _, categoryData in ipairs(shopData.category or {}) do
      local shopOffer = g_ui.createWidget("ButtonCategory", shopWindow.PanelCategory.categoryList)
      shopOffer:setImageSource("menus/" .. categoryData.name)

      -- seleção inicial
      if categoryData.name == categoryPattern then
        shopOffer:focus()
        if shopWindow.categoryInfo and shopWindow.categoryInfo.descriptionPanel then
          local lbl = shopWindow.categoryInfo.descriptionPanel.descriptionLabel
          if lbl then
            lbl:setText(categoryData.description or "")
            lbl:setFont("baby-14")
          end
        end
        doCreateItems(shopData)
      end

      shopOffer.onClick = function()
        categoryPattern = categoryData.name
        if shopWindow.categoryInfo and shopWindow.categoryInfo.descriptionPanel then
          local lbl = shopWindow.categoryInfo.descriptionPanel.descriptionLabel
          if lbl then
            lbl:setText(categoryData.description or "")
            lbl:setFont("baby-14")
          end
        end
        doCreateItems(shopData)
      end
    end
  end

  -- Transferência
  if shopWindow.transfer then
    shopWindow.transfer.onClick = function()
      if transferPanel then return end

      transferPanel = g_ui.createWidget("transferPanel", shopWindow)
      transferPanel.playerName:setValidCharacters('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ')
      transferPanel.labelTransfer:setText("1")
      amount(transferPanel)

      transferPanel.closeTransferPanel.onClick = function()
        closeTransfer()
      end

      transferPanel.transfer.onClick = function()
        local targetName = transferPanel.playerName:getText()
        local amt = tonumber(transferPanel.amountPanel.textAmount:getText()) or 0
        -- Novo protocolo: action="transfer" no opcode 40
        _sendJSON(gameShopOpcode, { action = "transfer", name = targetName, amount = amt })
        closeTransfer()
      end
    end
  end
end

function doCreateItems(shopData)
  closePanelBuying()
  if not (shopWindow.PanelShopList and shopWindow.PanelShopList.shopList) then return end

  shopWindow.PanelShopList.shopList:destroyChildren()

  for _, data in ipairs(shopData.shopData or {}) do
    if data.category == categoryPattern then
      local shopItem = g_ui.createWidget("shopItem", shopWindow.PanelShopList.shopList)
      shopItem:setId(data.category)

      -- tooltip e texto
      local tooltipItem = string.format("%s\n%s", data.name or "", data.description or "")
      shopItem:setTooltip(tooltipItem)

      if shopItem.item and data.itemId then
        shopItem.item:setItemId(data.itemId)
      end
      if shopItem.itemName then
        shopItem.itemName:setText(data.name or "")
      end
      if shopItem.itemPoints then
        shopItem.itemPoints:setText(data.points or 0)
      end
      if shopItem.icon and data.points then
        shopItem.icon:setTooltip("Points: " .. tostring(data.points))
      end

      shopItem.onClick = function()
        if buyPanel then return end

        buyPanel = g_ui.createWidget("BuyPanel", shopWindow)
        if buyPanel.buyLabelName then buyPanel.buyLabelName:setText(data.name or "") end
        if buyPanel.item and data.itemId then buyPanel.item:setItemId(data.itemId) end
        if buyPanel.price then buyPanel.price:setText(data.points or 0) end

        amount(buyPanel, data)

        if buyPanel.buy then
          buyPanel.buy.onClick = function()
            local qty = tonumber(buyPanel.amountPanel.textAmount:getText()) or 1
            -- Novo protocolo: action="buy" no opcode 40
            _sendJSON(gameShopOpcode, { action = "buy", index = data.index, count = qty })
          end
        end

        if buyPanel.closeBuyPanel then
          buyPanel.closeBuyPanel.onClick = function() closePanelBuying() end
        end
      end
    end
  end
end

-- =========================
-- Painéis auxiliares
-- =========================
function closePanelBuying()
  if buyPanel then
    buyPanel:destroy()
    buyPanel = nil
  end
end

function closeTransfer()
  if transferPanel then
    transferPanel:destroy()
    transferPanel = nil
  end
end

-- =========================
-- Componente Amount
-- =========================
function amount(widget, data)
  widget.amountPanel.textAmount:setText(1)
  widget.amountPanel.textAmount:setValidCharacters('0123456789')
  widget.amountPanel.textAmount:setFocusable(false)
  widget.amountPanel.textAmount.minimum = 1
  widget.amountPanel.textAmount.maximum = data and 100 or 1000

  widget.amountPanel.textAmount.onTextChange = function(self, text, oldText)
    local number = tonumber(text)

    if not number then
      self:setText(self.minimum)
      number = self.minimum
    else
      if number < self.minimum then
        self:setText(self.minimum)
        number = self.minimum
      elseif number > self.maximum then
        self:setText(self.maximum)
        number = self.maximum
      end
    end

    if text:len() == 0 then
      self:setText(self.minimum)
      number = self.minimum
    end

    if data then
      widget.price:setText(number * (data.points or 0))
    else
      widget.labelTransfer:setText(number)
    end
  end

  widget.amountPanel.decrementAll.onClick = function()
    widget.amountPanel.textAmount:setText(1)
  end

  widget.amountPanel.decrement.onClick = function()
    local n = tonumber(widget.amountPanel.textAmount:getText()) or 1
    widget.amountPanel.textAmount:setText(math.max(1, n - 1))
  end

  widget.amountPanel.incrementAll.onClick = function()
    widget.amountPanel.textAmount:setText(widget.amountPanel.textAmount.maximum)
  end

  widget.amountPanel.increment.onClick = function()
    local n = tonumber(widget.amountPanel.textAmount:getText()) or 1
    local maxv = widget.amountPanel.textAmount.maximum
    widget.amountPanel.textAmount:setText(math.min(n + 1, maxv))
  end
end
