Market = {}
local protocol = runinsandbox('marketprotocol')
local MARKET_OPCODE = 22

marketWindow = nil
mainTabBar = nil
displaysTabBar = nil
offersTabBar = nil
selectionTabBar = nil
msgWindow = nil
InviteWindow = nil
marketOffersPanel = nil
browsePanel = nil
offerButton = nil
overviewPanel = nil
itemOffersPanel = nil
itemDetailsPanel = nil
itemStatsPanel = nil
myOffersPanel = nil
currentOffersPanel = nil
offerHistoryPanel = nil
itemsPanel = nil
selectedOffer = {}
selectedMyOffer = {}
LOADED = false


MarketSeller = nil 
MarketSendMessage = nil
MarketSendOfferId = nil
MakerSendOfferName = nil
MarketSendOfferType = nil
MarketSendExpireTime = nil
MarketSendBuyer = nil


itemDescTable = nil
MyOfferTable = nil

nameLabel = nil
feeLabel = nil
balanceLabel = nil
premiumPointsLabel = nil
eventsPointsLabel = nil
totalPriceEdit = nil
piecePriceEdit = nil
amountEdit = nil
searchEdit = nil
categorySelect = nil
radioItemSet = nil
selectedItem = nil
selectedItemOffer = nil
offerTypeList = nil
categoryList = nil
subCategoryList = nil
slotFilterList = nil
createOfferButton = nil
buyButton = nil
sellButton = nil
anonymous = nil
filterButtons = {}

buyOfferTable = nil
sellOfferTable = nil
histTable = nil
detailsTable = nil
itemdetailsTable = nil
buyStatsTable = nil
sellStatsTable = nil

buyCancelButton = nil
sellCancelButton = nil
buyMyOfferTable = nil
sellMyOfferTable = nil

lastTimeStamp = nil
lastCounter = nil

selectedTimeStamp = nil
selectedCounters = nil 

senderName = nil
senderMessage = nil
ItemName = nil
itemPremium = nil
expireAt = nil


offerExhaust = {}
marketOffers = {}
marketItems = {}
information = {}
currentItems = {}
lastCreatedOffer = 0
lastDelay = 0
fee = 0
averagePrice = 0

loaded = false

local function clearItems()
  currentItems = {}
end

local function clearOffers()
  marketOffers[MarketAction.Buy] = {}
  marketOffers[MarketAction.Sell] = {}
  sellOfferTable:clearData()
  MyOfferTable:clearData()
  histTable:clearData()
  lastCounterArray = {}
  hlastCounterArray = {}
  hlastTimeStompArray = {}
  lastTimeStompArray = {}
end

local function clearMyOffers()
  sellMyOfferTable:clearData()
end


local function updateDesc(desc, itemId)
	if LOADED then
	itemDescTable:clearData()
	itemDescTable:setColor('#33FF00')
	itemDescTable:setText(string.gsub(desc, "255", ""))
	selectedItemOffer:setItemId(itemId)
	itemDescTable:setTooltip(desc)
	local offer = selectedOffer[MarketAction.Buy]
	if offer:getPrice() == 0 then
		buyButton:disable()
	end
	end
end

local function clearFilters()
  for _, filter in pairs(filterButtons) do
    if filter and filter:isChecked() ~= filter.default then
      filter:setChecked(filter.default)
    end
  end
end

local function clearFee()
  feeLabel:setText('')
  fee = 20
end


local function addOffer(offer, offerType)
  if not offer then
    return false
  end
  local id = offer:getId()
  local player = offer:getPlayer()
  local amount = offer:getAmount()
  local price = offer:getPrice()
  local timestamp = offer:getTimeStamp()
  local itemName = offer.itemname
  local state = ""
  local premium = offer:getPremium()
  
  for i, v in pairs(MarketOfferState) do
	if v == offer:getState() then
		state = i
	end
  end
  sellOfferTable:toggleSorting(false)

  sellMyOfferTable:toggleSorting(false)

  if amount < 1 then return false end
  if offerType == MarketAction.Buy then
    if offer.warn then
      buyOfferTable:setColumnStyle('OfferTableWarningColumn', true)
    end

    if offer.warn then
      row:setTooltip(tr('This offer is 25%% below the average market price'))
    end
  else
    if offer.warn then
      sellOfferTable:setColumnStyle('OfferTableWarningColumn', true)
    end

    local row = nil
	local totalOfferPrice = ""
	local offerText = ""
	if price == 0 then
		offerText = "Offer"
	else
		offerText = price/1
	end
	if price == 0 then
		totalOfferPrice = "Offer"
	else
		totalOfferPrice = (price/1)*amount
	end
	
    if offer.var == MarketRequest.MyOffers then	
		if not isInArray(lastCounterArray, offer:getCounter()) and not isInArray(lastTimeStompArray, offer:getTimeStamp()) then 
			row = sellMyOfferTable:addRow({
				{text = itemName},
				{text = premium},
				{text = offerText},
				{text = amount},
				{text = string.gsub(os.date('%c', timestamp), " ", "  "), sortvalue = timestamp}
			})
			table.insert(lastCounterArray, offer:getCounter())
			table.insert(lastTimeStompArray, offer:getTimeStamp())
		end
	elseif offer.var == MarketRequest.MyHistory then
		if not isInArray(hlastCounterArray, offer:getCounter()) and not isInArray(hlastTimeStompArray, offer:getTimeStamp()) then 
			row = histTable:addRow({
				{text = itemName},
				{text = premium},
				{text = amount},
				{text = state},
				{text = string.gsub(os.date('%c', timestamp), " ", "  "), sortvalue = timestamp}
			})
			table.insert(hlastCounterArray, offer:getCounter())
			table.insert(hlastTimeStompArray, offer:getTimeStamp())
	  end
    else
		row = sellOfferTable:addRow({
			{text = itemName},
			{text = player},
			{text = amount},
			{text = premium},
			{text = offerText},
			{text = string.gsub(os.date('%c', timestamp), " ", "  "), sortvalue = timestamp}
		})
    end
	if row then
		row.ref = id
	end

    if offer.warn then
      row:setTooltip(tr('This offer is 25%% above the average market price'))
      sellOfferTable:setColumnStyle('OfferTableColumn', true)
    end
  end

  sellOfferTable:toggleSorting(false)
  sellOfferTable:sort()

  sellMyOfferTable:toggleSorting(false)
  sellMyOfferTable:sort()
  return true
end

local function mergeOffer(offer)
  if not offer then
    return false
  end

  local id = offer:getId()
  local offerType = offer:getType()
  local amount = offer:getAmount()
  local replaced = false

  if offerType == MarketAction.Buy then
    if averagePrice > 0 then
      offer.warn = offer:getPrice() <= averagePrice - math.floor(averagePrice / 4)
    end

    for i = 1, #marketOffers[MarketAction.Buy] do
      local o = marketOffers[MarketAction.Buy][i]
      -- replace existing offer
      if o:isEqual(id) then
        marketOffers[MarketAction.Buy][i] = offer
        replaced = true
      end
    end
    if not replaced then
      table.insert(marketOffers[MarketAction.Buy], offer)
    end
  else
    if averagePrice > 0 then
      offer.warn = offer:getPrice() >= averagePrice + math.floor(averagePrice / 4)
    end

    for i = 1, #marketOffers[MarketAction.Sell] do
      local o = marketOffers[MarketAction.Sell][i]
      -- replace existing offer
      if o:isEqual(id) then
        marketOffers[MarketAction.Sell][i] = offer
        replaced = true
      end
    end
    if not replaced then
      table.insert(marketOffers[MarketAction.Sell], offer)
    end
  end
  return true
end

lastCounterArray = {}
lastTimeStompArray = {}
hlastCounterArray = {}
hlastTimeStompArray = {}

local function updateOffers(offers)
  if not sellOfferTable then
    return
  end
    
  balanceLabel:setColor('#bbbbbb')
  premiumPointsLabel:setColor('#bbbbbb')
  eventsPointsLabel:setColor('#bbbbbb')
  selectedOffer[MarketAction.Buy] = nil
  selectedOffer[MarketAction.Sell] = nil

  selectedMyOffer[MarketAction.Buy] = nil
  selectedMyOffer[MarketAction.Sell] = nil

  sellOfferTable:clearData()
  sellOfferTable:setSorting(4, TABLE_SORTING_ASC)

  buyButton:setEnabled(false)
  contactButton:disable()
  refuseButton:disable()
  acceptButton:disable()
  sellCancelButton:setEnabled(false)

  local function isSellCondition(offer)
    return type == MarketAction.Sell and offer.var ~= MarketRequest.MyOffers and offer.var ~= MarketRequest.MyHistory
  end

  for _, offer in pairs(offers) do
    mergeOffer(offer)
  end

  local itemCount = 0
  for type, offers in pairs(marketOffers) do
    for i = 1, #offers do
      local meetsCondition = offers[i].amount <= 100
      meetsCondition = meetsCondition and (categorySelect:getText() == "All" or getCategoryById(offers[i]:getItem():getId()) == categorySelect:getText())
      meetsCondition = meetsCondition and (searchEdit:getText():len() <= 1 or string.find(offers[i].itemname:lower(), searchEdit:getText():lower()))

      if meetsCondition and offers[i]:getPlayer() ~= g_game.getLocalPlayer():getName() then
          addOffer(offers[i], type)
      end
    end
  end

  LOADED = true
end

function getCategoryById(Id)
	local categorias = {
		['Gloves'] = {10043}, 
	}
	for i, v in pairs(categorias) do
		for u, p in pairs(v) do
			if p == Id then 
				return i
			end
		end
	end
	return "Others"
end

local function updateDetails(itemId, descriptions, purchaseStats, saleStats)
  if not selectedItem then
    return
  end

  -- update item details
  detailsTable:clearData()
  for k, desc in pairs(descriptions) do
    local columns = {
      {text = getMarketDescriptionName(desc[1])..':'},
      {text = desc[2]}
    }
    detailsTable:addRow(columns)
  end

  -- update sale item statistics
  sellStatsTable:clearData()
  if table.empty(saleStats) then
    sellStatsTable:addRow({{text = 'No information'}})
  else
    local offerAmount = 0
    local transactions, totalPrice, highestPrice, lowestPrice = 0, 0, 0, 0
    for _, stat in pairs(saleStats) do
      if not stat:isNull() then
        offerAmount = offerAmount + 1
        transactions = transactions + stat:getTransactions()
        totalPrice = totalPrice + stat:getTotalPrice()
        local newHigh = stat:getHighestPrice()
        if newHigh > highestPrice then
          highestPrice = newHigh
        end
        local newLow = stat:getLowestPrice()
        -- ?? getting '0xffffffff' result from lowest price in 9.60 cipsoft
        if (lowestPrice == 0 or newLow < lowestPrice) and newLow ~= 0xffffffff then
          lowestPrice = newLow
        end
      end
    end

    if offerAmount >= 5 and transactions >= 10 then
      averagePrice = math.round(totalPrice / transactions)
    else
      averagePrice = 0
    end
	MyOfferTable:clearData()
    sellStatsTable:addRow({{text = 'Total Transations:'}, {text = transactions}})
    sellStatsTable:addRow({{text = 'Highest Price:'}, {text = highestPrice}})

    if totalPrice > 0 and transactions > 0 then
      sellStatsTable:addRow({{text = 'Average Price:'},
        {text = math.floor(totalPrice/transactions)}})
    else
      sellStatsTable:addRow({{text = 'Average Price:'}, {text = 0}})
    end

    sellStatsTable:addRow({{text = 'Lowest Price:'}, {text = lowestPrice}})
  end

  -- update buy item statistics
  buyStatsTable:clearData()
  if table.empty(purchaseStats) then
    buyStatsTable:addRow({{text = 'No information'}})
  else
    local transactions, totalPrice, highestPrice, lowestPrice = 0, 0, 0, 0
    for _, stat in pairs(purchaseStats) do
      if not stat:isNull() then
        transactions = transactions + stat:getTransactions()
        totalPrice = totalPrice + stat:getTotalPrice()
        local newHigh = stat:getHighestPrice()
        if newHigh > highestPrice then
          highestPrice = newHigh
        end
        local newLow = stat:getLowestPrice()
        if (lowestPrice == 0 or newLow < lowestPrice) and newLow ~= 0xffffffff then
          lowestPrice = newLow
        end
      end
    end

    buyStatsTable:addRow({{text = 'Total Transations:'},{text = transactions}})
    buyStatsTable:addRow({{text = 'Highest Price:'}, {text = highestPrice}})

    if totalPrice > 0 and transactions > 0 then
      buyStatsTable:addRow({{text = 'Average Price:'},
        {text = math.floor(totalPrice/transactions)}})
    else
      buyStatsTable:addRow({{text = 'Average Price:'}, {text = 0}})
    end

    buyStatsTable:addRow({{text = 'Lowest Price:'}, {text = lowestPrice}})
  end
end

local function updateFee(price, amount)
  fee = math.ceil(price / 100 * amount)
  if fee < 20 then
    fee = 20
  elseif fee > 1000 then
    fee = 1000
  end
  feeLabel:setText('Fee: '..(fee/1))
  feeLabel:resizeToText()
end

local function destroyAmountWindow()
  if amountWindow then
    amountWindow:destroy()
    amountWindow = nil
  end
   if msgWindow then
    msgWindow:destroy()
    msgWindow = nil
  end
  
 if InviteWindow then
    InviteWindow:destroy()
    InviteWindow = nil
  end
end

local function cancelMyOffer(actionType)
  local offer = selectedMyOffer[actionType]
  MarketProtocol.sendMarketCancelOffer(offer:getTimeStamp(), offer:getCounter())
  Market.refreshMyOffers()
  Market.refreshMyHist()
  refresh()
end

local function openAmountWindow(callback, actionType, actionText)
  if not Market.isOfferSelected(actionType) then
    return
  end

  amountWindow = g_ui.createWidget('AmountWindow', rootWidget)
  amountWindow:lock()

  local offer = selectedOffer[actionType]
  local item = offer:getItem()
  local premium = offer:getPremium()

  local maximum = offer:getAmount()
  if actionType == MarketAction.Buy then
	if premium == "Gold Coins" then
		maximum = math.min(maximum, math.floor(getGoldCoins / offer:getPrice()))
	elseif premium == "Events Points" then
		maximum = math.min(maximum, math.floor(getEventsPoints / offer:getPrice()))
	else
		maximum = math.min(maximum, math.floor(getPremiumPoints / offer:getPrice()))
	end
  end

  if item:isStackable() then
    maximum = math.min(maximum, MarketMaxAmountStackable)
  else
    maximum = math.min(maximum, MarketMaxAmount)
  end

  local itembox = amountWindow:getChildById('item')
  itembox:setItemId(item:getId())

  local scrollbar = amountWindow:getChildById('amountScrollBar')
  if premium == "Gold Coins" then
	scrollbar:setText((offer:getPrice()/1)..' Gold Coins')
  elseif premium == "Events Points" then
	scrollbar:setText((offer:getPrice()/1)..' Events Points')
  else
	scrollbar:setText((offer:getPrice()/1)..' Premium Points')
  end

  scrollbar.onValueChange = function(widget, value)
    if premium == "Gold Coins" then
		widget:setText((value*(offer:getPrice()/1))..' Gold Coins')
    elseif premium == "Events Points" then
		widget:setText((value*(offer:getPrice()/1))..' Events Points')
	else
		widget:setText((value*(offer:getPrice()/1))..' Premium Points')
	end
    itembox:setText(value)
  end

  scrollbar:setRange(1, maximum)
  scrollbar:setValue(1)

  local okButton = amountWindow:getChildById('buttonOk')
  if actionText then
    okButton:setText(actionText)
  end

  local okFunc = function()
    local counter = offer:getCounter()
    local timestamp = offer:getTimeStamp()
    callback(scrollbar:getValue(), timestamp, counter)
    destroyAmountWindow()
    refresh()	
  end

  local cancelButton = amountWindow:getChildById('buttonCancel')
  local cancelFunc = function()
    destroyAmountWindow()
  end

  amountWindow.onEnter = okFunc
  amountWindow.onEscape = cancelFunc

  okButton.onClick = okFunc
  cancelButton.onClick = cancelFunc
end

local function onSelectSellOffer(table, selectedRow, previousSelectedRow)
  if LOADED then

    for _, offer in pairs(marketOffers[MarketAction.Sell]) do
      if offer:isEqual(selectedRow.ref) then
        selectedOffer[MarketAction.Buy] = offer
      end
    end

    local offer = selectedOffer[MarketAction.Buy]

    if offer then
      MarketProtocol.sendMarketItemDesc(offer:getTimeStamp(), offer:getCounter())

      local price = offer:getPrice()
      local premium = offer:getPremium()

      if price == 0 then
        offerButton:enable()
      end

      local player = g_game.getLocalPlayer()

      if (price > getGoldCoins) and premium == "Gold Coins" then
        balanceLabel:setColor('#b22222') -- vermelho
        buyButton:setEnabled(false)
      elseif (price <= getGoldCoins) and premium == "Gold Coins" then
        local slice = (getGoldCoins / 2)
        local color

        if (price / slice) * 100 <= 40 then
          color = '#008b00' -- verde
        elseif (price / slice) * 100 <= 70 then
          color = '#eec900' -- amarelo
        else
          color = '#ee9a00' -- laranja
        end

        balanceLabel:setColor(color)
        buyButton:setEnabled(true)
      end
	  
	if (price > getEventsPoints) and premium == "Events Points" then
        balanceLabel:setColor('#b22222') -- vermelho
        buyButton:setEnabled(false)
      elseif (price <= getEventsPoints) and premium == "Events Points" then
        local slice = (getEventsPoints / 2)
        local color

        if (price / slice) * 100 <= 40 then
          color = '#008b00' -- verde
        elseif (price / slice) * 100 <= 70 then
          color = '#eec900' -- amarelo
        else
          color = '#ee9a00' -- laranja
        end

        eventsPointsLabel:setColor(color)
        buyButton:setEnabled(true)
      end

      if (price > getPremiumPoints) and premium == "Premium Points" then
        premiumPointsLabel:setColor('#b22222') -- vermelho
        buyButton:setEnabled(false)
      elseif (price <= getPremiumPoints) and premium == "Premium Points" then
        local slice2 = (getPremiumPoints / 2)
        local color

        if (price / slice2) * 100 <= 40 then
          color = '#008b00' -- verde
        elseif (price / slice2) * 100 <= 70 then
          color = '#eec900' -- amarelo
        else
          color = '#ee9a00' -- laranja
        end

        premiumPointsLabel:setColor(color)
        buyButton:setEnabled(true)
      end

      if player:getName() == offer.player then
        buyButton:setEnabled(false)
      end
    end
  end
end

local function onSelectMyOffer(table, selectedRow, previousSelectedRow)
	if LOADED then
	senderName = selectedRow.sender
	senderMessage = selectedRow.message
	itemPremium = selectedRow.premium
	contactButton:enable()
	refuseButton:enable()
	acceptButton:enable()
	end
end

function doContact()
	if senderName ~= nil then
		g_game.openPrivateChannel(senderName)
	end
end

function doAccept()
	if senderName ~= nil then
		local checkBuy = 
		{
				protocol = "AcceptMarket",
				MarketSendOfferId = selectedCounters, 
		}
				
		local checkBuyJson = json.encode(checkBuy)
		g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, checkBuyJson)
		MyOfferTable:clearData()
		Market.refreshMyOffers()		
	end
end

function doRecuse()
	if senderName ~= nil then		
		local checkBuy = 
		{
				protocol = "RecuseMarket",
				MarketSendOfferId = selectedCounters, 
		}
				
		local checkBuyJson = json.encode(checkBuy)
		g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, checkBuyJson)
		MyOfferTable:clearData()
	end
end

local function onSelectBuyOffer(table, selectedRow, previousSelectedRow)
  if LOADED then
	for _, offer in pairs(marketOffers[MarketAction.Buy]) do
		if offer:isEqual(selectedRow.ref) then
			selectedOffer[MarketAction.Sell] = offer
			MarketProtocol.sendMarketItemDesc(offer:getTimeStamp(), offer:getCounter())
		end
	end
  end
end

local function onSelectMyBuyOffer(table, selectedRow, previousSelectedRow)
	if LOADED then
  for _, offer in pairs(marketOffers[MarketAction.Buy]) do
    if offer:isEqual(selectedRow.ref) then
      selectedMyOffer[MarketAction.Buy] = offer
    end
  end
  end
end

local function onSelectMySellOffer(table, selectedRow, previousSelectedRow)
if LOADED then
  for _, offer in pairs(marketOffers[MarketAction.Sell]) do
    if offer:isEqual(selectedRow.ref) then
      selectedMyOffer[MarketAction.Sell] = offer
      sellCancelButton:setEnabled(true)	  
	 ItemName = offer.itemname
	 local sellerId = offer:getCounter()
	  
	local timestamp = offer:getTimeStamp()
	local counter = offer:getCounter()
	local data = { protocol = "SelectSell", timestamp = timestamp, counter = counter, ItemName = ItemName }
	local json_data = json.encode(data)
	g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, json_data)

	contactButton:disable()
	refuseButton:disable()
	acceptButton:disable()
	selectedTimeStamp = offer:getTimeStamp()
	selectedCounters = offer:getCounter()
	  
    end
  end
  end
end

local function onChangeOfferType(combobox, option)
  local item = selectedItem.item
  local maximum = item.thingType:isStackable() and MarketMaxAmountStackable or MarketMaxAmount

  if option == 'Sell' then
	maximum = selectedItem.count
    amountEdit:setMaximum(maximum)
  else
    amountEdit:setMaximum(maximum)
  end
end

local function onTotalPriceChange()
  local amount = amountEdit:getValue()
  local totalPrice = totalPriceEdit:getValue()
  local piecePrice = math.floor(totalPrice/amount)

  piecePriceEdit:setValue(piecePrice, true)
  if Market.isItemSelected() then
    updateFee(piecePrice, amount)
  end
end

local function onPiecePriceChange()
  local amount = amountEdit:getValue()
  local totalPrice = totalPriceEdit:getValue()
  local piecePrice = piecePriceEdit:getValue()

  totalPriceEdit:setValue(piecePrice*amount, true)
  if Market.isItemSelected() then
    updateFee(piecePrice, amount)
  end
end

local function onAmountChange()
  local amount = amountEdit:getValue()
  local piecePrice = piecePriceEdit:getValue()
  local totalPrice = piecePrice * amount

  totalPriceEdit:setValue(piecePrice*amount, true)
  if Market.isItemSelected() then
    updateFee(piecePrice, amount)
  end
end

local function onMarketMessage(messageMode, message)
  Market.displayMessage(message)
end

local function initInterface()
  -- TODO: clean this up
  -- setup main tabs
  mainTabBar = marketWindow:getChildById('mainTabBar')
  mainTabBar:setContentWidget(marketWindow:getChildById('mainTabContent'))

  -- setup 'Market Offer' section tabs
  marketOffersPanel = g_ui.loadUI('ui/marketoffers')
  mainTabBar:addTab(tr('Ofertas'), marketOffersPanel)

  selectionTabBar = marketOffersPanel:getChildById('leftTabBar')
  selectionTabBar:setContentWidget(marketOffersPanel:getChildById('leftTabContent'))

  displaysTabBar = marketOffersPanel:getChildById('rightTabBar')
  displaysTabBar:setContentWidget(marketOffersPanel:getChildById('rightTabContent'))

  itemStatsPanel = g_ui.loadUI('ui/marketoffers/itemstats')
  itemDetailsPanel = g_ui.loadUI('ui/marketoffers/itemdetails')

  itemOffersPanel = g_ui.loadUI('ui/marketoffers/itemoffers')
  displaysTabBar:addTab(tr('Offers'), itemOffersPanel)
  displaysTabBar:selectTab(displaysTabBar:getTab(tr('Offers')))

  -- setup 'My Offer' section tabs
  myOffersPanel = g_ui.loadUI('ui/myoffers')
  mainTabBar:addTab(tr('Minhas Ofertas'), myOffersPanel)

  offersTabBar = myOffersPanel:getChildById('offersTabBar')
  offersTabBar:setContentWidget(myOffersPanel:getChildById('offersTabContent'))

  currentOffersPanel = g_ui.loadUI('ui/myoffers/currentoffers')
  offersTabBar:addTab(tr('Itens á venda'), currentOffersPanel)

  offerHistoryPanel = g_ui.loadUI('ui/myoffers/offerhistory')
  offersTabBar:addTab(tr('Historico'), offerHistoryPanel)

  balanceLabel = marketWindow:getChildById('balanceLabel')
  premiumPointsLabel = marketWindow:getChildById('premiumPointsLabel')
  eventsPointsLabel = marketWindow:getChildById('eventsPointsLabel')

  -- setup offers
  buyButton = itemOffersPanel:getChildById('buyButton')
  buyButton.onClick = function()
  if not Market.isOfferSelected(MarketAction.Buy) then
    return
  end

  local offer = selectedOffer[MarketAction.Buy]
  local data = {
    protocol = "BuyMarket",
    MarketSendBuyer = g_game.getCharacterName(),
    MarketSendMessage = offer:getPrice(),
    MarketSendOfferId = offer:getCounter(),
    MakerSendOfferName = offer.itemname,
    MarketSendOfferType = offer:getPremium(),
    MarketSendExpireTime = offer:getTimeStamp(),
    MarketSendSeller = offer:getPlayer(),
  }

  g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, json.encode(data))
end


  -- setup selected item
  nameLabel = marketOffersPanel:getChildById('nameLabel')
  selectedItem = marketOffersPanel:getChildById('selectedItem')
  selectedItemOffer = marketOffersPanel:getChildById('selectedOfferItem')
  searchEdit = marketOffersPanel:getChildById('searchEdit')
  findLabel = marketOffersPanel:getChildById('findLabel')
  findLabel:resizeToText()
  categorySelect = marketOffersPanel:getChildById('CategorySelect')

  -- setup create new offer
  totalPriceEdit = marketOffersPanel:getChildById('totalPriceEdit')
  piecePriceEdit = marketOffersPanel:getChildById('piecePriceEdit')
  amountEdit = marketOffersPanel:getChildById('amountEdit')
  feeLabel = marketOffersPanel:getChildById('feeLabel')
  totalPriceEdit.onValueChange = onTotalPriceChange
  piecePriceEdit.onValueChange = onPiecePriceChange
  amountEdit.onValueChange = onAmountChange

  anonymous = marketOffersPanel:getChildById('anonymousCheckBox')
  onlyoffer = marketOffersPanel:getChildById('onlyOfferCheckBox')
  premiumPoints = marketOffersPanel:getChildById('premiumPointsCheckBox')
  eventsPoints = marketOffersPanel:getChildById('eventsPointsCheckBox')
  createOfferButton = marketOffersPanel:getChildById('createOfferButton')
  createOfferButton.onClick = Market.createNewOffer
  offerButton = itemOffersPanel:getChildById('sendOfferButton')
  offerButton.onClick = sendOffer
    if offerButton then offerButton:setVisible(false) end
if anonymousCb then anonymousCb:setVisible(false) end
local receiveOffersCb = marketOffersPanel:getChildById('onlyOfferCheckBox')
if receiveOffersCb then receiveOffersCb:setVisible(false) end
  Market.enableCreateOffer(false)
  createOfferButton:setEnabled(false)

  -- setup filters
  -- set filter default values
  clearFilters()

  -- hook filters

  -- setup tables
  histTable = offerHistoryPanel:recursiveGetChildById('myHistTable')
  itemDescTable = itemOffersPanel:recursiveGetChildById('itemdetailsTable')
  sellOfferTable = itemOffersPanel:recursiveGetChildById('sellingTable')
  detailsTable = itemDetailsPanel:recursiveGetChildById('detailsTable')
  buyStatsTable = itemStatsPanel:recursiveGetChildById('buyStatsTable')
  sellStatsTable = itemStatsPanel:recursiveGetChildById('sellStatsTable')
  sellOfferTable.onSelectionChange = onSelectSellOffer

  -- setup my offers
  sellMyOfferTable = currentOffersPanel:recursiveGetChildById('mySellingTable')
  sellMyOfferTable.onSelectionChange = onSelectMySellOffer
  
  MyOfferTable = currentOffersPanel:recursiveGetChildById('myBuyTable')
  MyOfferTable.onSelectionChange = onSelectMyOffer


  sellCancelButton = currentOffersPanel:getChildById('sellCancelButton')
  sellCancelButton.onClick = function() cancelMyOffer(MarketAction.Sell) end
  
  contactButton = currentOffersPanel:getChildById('contactButton')
  contactButton.onClick = doContact
  
  acceptButton = currentOffersPanel:getChildById('acceptButton')
  acceptButton.onClick = doAccept
  
  refuseButton = currentOffersPanel:getChildById('refuseButton')
  refuseButton.onClick = doRecuse

  buyStatsTable:setColumnWidth({120, 270})
  sellStatsTable:setColumnWidth({120, 270})
  detailsTable:setColumnWidth({80, 330})

  sellOfferTable:setSorting(4, TABLE_SORTING_ASC)

  sellMyOfferTable:setSorting(3, TABLE_SORTING_DESC)
  itemDescTable:setText(' ')
  selectedItemOffer:setItemId(0)
  onlyoffer:disable()
  premiumPoints:disable()
  eventsPoints:disable()
  	contactButton:disable()
	refuseButton:disable()
	acceptButton:disable()
end

function onlyOffer()
	if onlyoffer:isChecked() then
		piecePriceEdit:setValue(0)
		piecePriceEdit:disable()
	else
		piecePriceEdit:enable()
	end
end

function offerType()
	if premiumPoints:isChecked() then
		eventsPoints:disable()
	elseif eventsPoints:isChecked() then
		premiumPoints:disable()
	else
		eventsPoints:enable()
		premiumPoints:enable()
	end
end

function sendMarketDetails(protocol, opcode, buffer)
	local receive = json.decode(buffer)
	
	local MarketSendBuyer = receive.playerName
	local MarketSendMessage = receive.newOffer
	local MarketSendOfferId = receive.offerCounter
	local MakerSendOfferName = receive.offerName
	local MarketSendOfferType = receive.offerPremium
	local MarketSendExpireTime = receive.offerTimeStamp
	local MarketSendSeller = g_game.getCharacterName()
			
    if receive.protocol == "sendInvite" then
		sendInvite(MarketSendBuyer, MarketSendMessage, MarketSendOfferId, MakerSendOfferName, MarketSendOfferType, MarketSendExpireTime, MarketSendSeller) 
	end
	
	if receive.protocol == "premiumPoints" then
        local points = receive.premiumPoints
        local balance = receive.bankBalance
        local events = receive.eventsPoints
		local CheckHistory = receive.history
        getPremiumPoints = points
        getGoldCoins = balance
        getEventsPoints = events
		GetCheckHistory = CheckHistory
        
        premiumPointsLabel:setText("Premium Points: " .. points .. " ")
        premiumPointsLabel:resizeToText()

        balanceLabel:setText("Balance: " .. balance .. " ")
        balanceLabel:resizeToText()

        eventsPointsLabel:setText("Events Points: " .. events .. " ")
        eventsPointsLabel:resizeToText()
	elseif receive.protocol == "refresh" then
		updateMyHist(protocol, opcode, buffer)
	elseif receive.protocol == "updaterMyOffer" then
		updateMyOffer(protocol, opcode, buffer)
	elseif receive.protocol == "resetMarket" then
		ResetMarket()
    end
end

function ResetMarket()
	clearOffers()
	Market.refreshMyOffers()
end

function sendInvite(MarketSendBuyer, MarketSendMessage, MarketSendOfferId, MakerSendOfferName, MarketSendOfferType, MarketSendExpireTime, MarketSendSeller)
      InviteWindow = g_ui.createWidget('InviteWindow', rootWidget)
      InviteWindow:lock()
  
      local textBox = InviteWindow:getChildById('textBox')
      textBox:setText("Está oferecendo " .. MarketSendMessage .. " " .. MarketSendOfferType .. " \npor seu " .. MakerSendOfferName)
      textBox:setTextWrap(true)
      textBox:resizeToText()

      local logoNameInvite = InviteWindow:getChildById('logoNameInvite')
      logoNameInvite:setText(MarketSendBuyer)

      local okButton = InviteWindow:getChildById('buttonOk')
      local okFunc = function()
		
			local checkBuy = {
				protocol = "BuyMarket",
				MarketSendBuyer = MarketSendBuyer,
				MarketSendMessage = MarketSendMessage,
				MarketSendOfferId = MarketSendOfferId, 
				MakerSendOfferName = MakerSendOfferName, 
				MarketSendOfferType = MarketSendOfferType, 
				MarketSendExpireTime = MarketSendExpireTime,
				MarketSendSeller = MarketSendSeller,
			}
				
			local checkBuyJson = json.encode(checkBuy)
			g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, checkBuyJson)
			destroyAmountWindow()
      end

      local cancelButton = InviteWindow:getChildById('buttonCancel')
      local cancelFunc = function()
	  
			local checkBuy = {
				protocol = "DeclineMarket",
				MarketSendBuyer = MarketSendBuyer,
				MarketSendMessage = MarketSendMessage,
				MarketSendOfferId = MarketSendOfferId, 
				MakerSendOfferName = MakerSendOfferName, 
				MarketSendOfferType = MarketSendOfferType, 
				MarketSendExpireTime = MarketSendExpireTime,
				MarketSendSeller = MarketSendSeller,
			}
				
			local checkBuyJson = json.encode(checkBuy)
			g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, checkBuyJson)
        destroyAmountWindow()
      end

      InviteWindow.onEnter = okFunc
      InviteWindow.onEscape = cancelFunc

      okButton.onClick = okFunc
      cancelButton.onClick = cancelFunc
  
      MyOfferTable:clearData()
end


function sendOffer()
  if not Market.isOfferSelected(MarketAction.Buy) then
    return
  end

  msgWindow = g_ui.createWidget('MsgWindow', rootWidget)
  msgWindow:lock()

  local offer = selectedOffer[MarketAction.Buy]
  local textBox = msgWindow:getChildById('textBox')

  local okButton = msgWindow:getChildById('buttonOk')
  local okFunc = function()
    if not tonumber(textBox:getText()) then
      displayErrorBox(tr("Market Offer"), "Apenas números são permitidos.")
      return
    end
    
    local data = {
      protocol = "sendOffer",
      playerName = offer:getPlayer(),
      newOffer = textBox:getText(),
      offerName = offer.itemname,
      offerTimeStamp = offer:getTimeStamp(),
      offerCounter = offer:getCounter(),
      offerPremium = offer:getPremium(),
      Buyer = g_game.getCharacterName()
    }
	local json_data = json.encode(data)
    g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, json_data)
		
    destroyAmountWindow()
  end

  local cancelButton = msgWindow:getChildById('buttonCancel')
  local cancelFunc = function()
    destroyAmountWindow()
  end

  msgWindow.onEnter = okFunc
  msgWindow.onEscape = cancelFunc

  okButton.onClick = okFunc
  cancelButton.onClick = cancelFunc
end

function sendMarketInfo(protocol, opcode, buffer)
	local receive = json.decode(buffer)
	local send = json.encode(buffer)
		
    if receive.protocol == "premiumPoints" then
        local points = receive.premiumPoints
        local balance = receive.bankBalance
        local events = receive.eventsPoints
		local CheckHistory = receive.history
        getPremiumPoints = points
        getGoldCoins = balance
        getEventsPoints = events
		GetCheckHistory = CheckHistory
        
        premiumPointsLabel:setText("Premium Points: " .. points .. " ")
        premiumPointsLabel:resizeToText()

        balanceLabel:setText("Balance: " .. balance .. " ")
        balanceLabel:resizeToText()

        eventsPointsLabel:setText("Events Points: " .. events .. " ")
        eventsPointsLabel:resizeToText()
	elseif receive.protocol == "refresh" then
		updateMyHist(protocol, opcode, buffer)
	elseif receive.protocol == "updaterMyOffer" then
		updateMyOffer(protocol, opcode, buffer)
	elseif receive.protocol == "sendInvite" then
		sendMarketDetails(protocol, opcode, buffer)
    end
end

function init()
  g_ui.importStyle('market')
  g_ui.importStyle('ui/general/markettabs')
  g_ui.importStyle('ui/general/marketbuttons')
  g_ui.importStyle('ui/general/marketcombobox')
  g_ui.importStyle('ui/general/amountwindow')
  g_ui.importStyle('ui/general/msgwindow')
  g_ui.importStyle('ui/general/InviteWindow')

  offerExhaust[MarketAction.Sell] = 10
  offerExhaust[MarketAction.Buy] = 20
  
  mouseGrabberWidget = g_ui.createWidget('UIWidget')
  mouseGrabberWidget:setVisible(false)
  mouseGrabberWidget:setFocusable(false)
  mouseGrabberWidget.onMouseRelease = onChooseItemMouseRelease

  registerMessageMode(MessageModes.Market, onMarketMessage)
  protocol.initProtocol()
  connect(g_game, { onGameEnd = Market.reset })
  connect(g_game, { onGameEnd = Market.close })
  marketWindow = g_ui.createWidget('MarketWindow', rootWidget)
  marketWindow:hide()
  actualPage = 1
  initInterface() 
	ProtocolGame.registerExtendedOpcode(MARKET_OPCODE, sendMarketDetails)
	
end


function updateMyOffer(protocol, opcode, buffer)
    local data = json.decode(buffer)
    MyOfferTable:clearData()
	
    for _, v in ipairs(data.updaterMyOffer) do
        local row = MyOfferTable:addRow({
            { text = v.sender_name },
            { text = v.message }
        })
        row.sender = v.sender_name
        row.message = v.message
    end
end

function updateMyHist(protocol, opcode, buffer)
    local data = json.decode(buffer)
    
    histTable:clearData()
    
    for i, entry in ipairs(data.history) do
        histTable:addRow({
            { text = entry[1] },
            { text = entry[2] },
            { text = tostring(entry[3]) },
            { text = tostring(entry[4]) },
            { text = entry[5] },
            { text = entry[6] },
        })
    end
end


function terminate()
  Market.close()

  unregisterMessageMode(MessageModes.Market, onMarketMessage)
  ProtocolGame.unregisterExtendedOpcode(MARKET_OPCODE)

  protocol.terminateProtocol()
  disconnect(g_game, { onGameEnd = Market.reset })
  disconnect(g_game, { onGameEnd = Market.close })

  destroyAmountWindow()
  marketWindow:destroy()
  actualPage = 1

  Market = nil
end

function Market.reset()
  balanceLabel:setColor('#bbbbbb')
  premiumPointsLabel:setColor('#bbbbbb')
  eventsPointsLabel:setColor('#bbbbbb')
  clearMyOffers()
  if not table.empty(information) then
    Market.updateCurrentItems()
  end
end

function Market.displayMessage(message)
  if marketWindow:isHidden() then return end

  local infoBox = displayInfoBox(tr('Market Error'), message)
  infoBox:lock()
end

function Market.clearSelectedItem()
  if Market.isItemSelected() then
    Market.resetCreateOffer(true)
    clearOffers()
    selectedItem:setItem(nil)
    selectedItem.item = nil
	if selectedItem.ref then
		selectedItem.ref:setChecked(false)
		selectedItem.ref = nil
	end

    detailsTable:clearData()
    buyStatsTable:clearData()
    sellStatsTable:clearData()
	MyOfferTable:clearData()
    Market.enableCreateOffer(false)
  end
end

function Market.isItemSelected()
  return selectedItem and selectedItem.item
end

function Market.isOfferSelected(type)
  return selectedOffer[type] and not selectedOffer[type]:isNull()
end

function Market.enableCreateOffer(enable)
  totalPriceEdit:setEnabled(enable)
  piecePriceEdit:setEnabled(enable)
  amountEdit:setEnabled(enable)
  anonymous:setEnabled(enable)

  local prevAmountButton = marketOffersPanel:recursiveGetChildById('prevAmountButton')
  local nextAmountButton = marketOffersPanel:recursiveGetChildById('nextAmountButton')

  prevAmountButton:setEnabled(enable)
  nextAmountButton:setEnabled(enable)
end

function Market.close(notify)
  if notify == nil then notify = true end
  if not marketWindow:isHidden() then
    marketWindow:hide()
    marketWindow:unlock()
    modules.game_interface.getRootPanel():focus()
    Market.clearSelectedItem()
    Market.reset()
    if notify then
      MarketProtocol.sendMarketLeave()
    end
  end
end

function Market.incrementAmount()
  amountEdit:setValue(amountEdit:getValue() + 1)
end

function Market.decrementAmount()
  amountEdit:setValue(amountEdit:getValue() - 1)
end

function Market.updateCurrentItems()
	MarketProtocol.sendMarketBrowse(5000)
	LOADED = false
end

function Market.resetCreateOffer(resetFee)
  piecePriceEdit:setValue(1)
  totalPriceEdit:setValue(1)
  amountEdit:setValue(1)

  if resetFee then
    clearFee()
  else
    updateFee(0, 0)
  end
end

function Market.refreshOffers()
    Market.refreshMyOffers()
end

function Market.refreshMyOffers()
  clearMyOffers()
  MarketProtocol.sendMarketBrowseMyOffers()
end

function Market.refreshMyOffersHistory()
  clearMyOffers()
  MarketProtocol.sendMarketBrowseMyHistory()
 histTable:clearData()
end

function Market.refreshMyHist()
	histTable:clearData()
    clearMyOffers()
	g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, json.encode({ protocol = "refresh" }))
end


local function updateSelectedItemSelecte(item)
  Market.resetCreateOffer()
  selectedItem.item = item:getId()
  selectedItem.pos = item:getPosition()
  selectedItem:setItemId(item:getId())
  selectedItem.count = item:getCount()
  selectedItem.stackPos = item:getStackPos() 
  Market.enableCreateOffer(true)
  onlyoffer:enable()
  premiumPoints:enable()
  eventsPoints:enable()
end

function startChooseItem()
  if g_ui.isMouseGrabbed() then return end
  mouseGrabberWidget:grabMouse()
  g_mouse.pushCursor('target')
end

function onChooseItemMouseRelease(self, mousePosition, mouseButton)
  local item = nil
  if mouseButton == MouseLeftButton then
    local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
    if clickedWidget then
      if clickedWidget:getClassName() == 'UIItem' and not clickedWidget:isVirtual() then
        item = clickedWidget:getItem()
      end
    end
  end

  if item then
	updateSelectedItemSelecte(item)
	createOfferButton:setEnabled(true)
  end
  g_mouse.popCursor('target')
  self:ungrabMouse()
  return true
end

function Market.createNewOffer()
  local type = MarketAction.Sell
  local pos = selectedItem.pos
  local spriteId = selectedItem.item
  local stackpos = selectedItem.stackPos
  local piecePrice = piecePriceEdit:getValue()
  local amount = amountEdit:getValue()
  local anonymous = anonymous:isChecked() and 1 or 0
  local premium = premiumPoints:isChecked() and 1 or 0
  local events = eventsPoints:isChecked() and 2 or 0
     
  -- error checking
  local errorMsg = ''
  if type == MarketAction.Buy then
    if getGoldCoins < ((piecePrice * amount) + fee) then
      errorMsg = errorMsg..'Not enough balance to create this offer.\n'
    end
  elseif type == MarketAction.Sell then
    if getGoldCoins < fee then
      errorMsg = errorMsg..'Not enough balance to create this offer.\n'
    end
  end

  if piecePrice > piecePriceEdit.maximum then
    errorMsg = errorMsg..'Price is too high.\n'
  end
  
  if amount > selectedItem.count then
	errorMsg = errorMsg..'Amount is too high.\n'
  end

  if amount > amountEdit.maximum then
    errorMsg = errorMsg..'Amount is too high.\n'
  elseif amount < amountEdit.minimum then
    errorMsg = errorMsg..'Amount is too low.\n'
  end

  if amount * piecePrice > MarketMaxPrice then
    errorMsg = errorMsg..'Total price is too high.\n'
  end

  if information.totalOffers >= MarketMaxOffers then
    errorMsg = errorMsg..'You cannot create more offers.\n'
  end

  local timeCheck = os.time() - lastCreatedOffer
  if timeCheck < offerExhaust[type] then
    local waitTime = math.ceil(offerExhaust[type] - timeCheck)
    errorMsg = errorMsg..'You must wait '.. waitTime ..' seconds before creating a new offer.\n'
  end

  if errorMsg ~= '' then
    Market.displayMessage(errorMsg)
    return
  end
    

  MarketProtocol.sendMarketCreateOffer(type, pos, spriteId, stackpos, amount, piecePrice, anonymous, premium + events)
  sellOfferTable:clearData()
  Market.refreshOffers()
  lastCreatedOffer = os.time()
  Market.refreshMyHist()
  Market.resetCreateOffer()
  refresh()
  createOfferButton:disable()
  onlyoffer:setChecked(false)
  premiumPoints:setChecked(false)
  eventsPoints:setChecked(false)
  piecePriceEdit:enable()  
end

function Market.acceptMarketOffer(amount, timestamp, counter)
  if timestamp > 0 and amount > 0 then
    MarketProtocol.sendMarketAcceptOffer(timestamp, counter, amount)
    Market.refreshOffers()
  end
end

function Market.onMarketEnter(depotItems, offers, balance, vocation)
  if not loaded then
    loaded = true
  end
  actualPage = 1
  itemDescTable:setText('')
  selectedItemOffer:setItemId(0)
  onlyoffer:disable()
  premiumPoints:disable()
  eventsPoints:disable()
  selectedItem:setItemId(0)
  averagePrice = 0

  information.totalOffers = offers
  local player = g_game.getLocalPlayer()
  if player then
    information.player = player
  end
  if vocation == -1 then
    if player then
      information.vocation = player:getVocation()
    end
  else
    information.vocation = vocation
  end

  information.depotItems = depotItems

  if Market.isItemSelected() then
    local spriteId
    MarketProtocol.silent(true)
    MarketProtocol.silent(false)
  end


  if g_game.isOnline() then
    marketWindow:show()
	clearOffers()
	Market.refreshMyOffers()
    MarketProtocol.sendMarketBrowse(5000)
	LOADED = false
	Market.refreshMyHist()
	g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, json.encode({ protocol = "premiumPoints" }))
  end
end

local refreshCooldown = false

function refresh()
	local refreshDelay = 20

    -- if refreshCooldown then
	-- displayErrorBox(tr("Refresh"),  "Aguerde mais um pouco para atualizar o Market.")
        -- return
    -- end
        


	refreshCooldown = true
	clearOffers()
	Market.refreshMyOffers()
    MarketProtocol.sendMarketBrowse(5000)
	LOADED = false
	Market.refreshMyHist()
	histTable:clearData()
	g_game.getProtocolGame():sendExtendedOpcode(MARKET_OPCODE, json.encode({ protocol = "premiumPoints" }))
	
    -- scheduleEvent(function()
        -- refreshCooldown = false
    -- end, refreshDelay * 1000)
end

function Market.onMarketLeave()
  Market.close(false)
end

function Market.onMarketDetail(itemId, descriptions, purchaseStats, saleStats)
  updateDetails(itemId, descriptions, purchaseStats, saleStats)
end

function Market.onMarketBrowse(offers)
  updateOffers(offers)
end

function Market.onMarketItemDesc(desc, itemId)
  updateDesc(desc, itemId)
end