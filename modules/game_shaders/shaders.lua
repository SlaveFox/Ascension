-- Cache para shaders já carregados
local shaderCache = {}
local shadersLoaded = false

-- Função para carregar shader sob demanda
local function loadShaderIfNeeded(name, vertex, fragment)
  if not shaderCache[name] then
    g_shaders.createOutfitShader(name, vertex, fragment)
    shaderCache[name] = true
  end
end

-- Função para carregar shaders essenciais primeiro
local function loadEssentialShaders()
  -- Apenas shaders essenciais na inicialização
  g_shaders.createShader("map_default", "/shaders/map_default_vertex", "/shaders/map_default_fragment")
  
  -- Shaders básicos de upgrade (mais usados)
  loadShaderIfNeeded("+1", "/shaders/map_default_vertex", "/shaders/upgrade/+1")
  loadShaderIfNeeded("+2", "/shaders/map_default_vertex", "/shaders/upgrade/+2")
  loadShaderIfNeeded("+3", "/shaders/map_default_vertex", "/shaders/upgrade/+3")
  
  -- Shaders especiais básicos
  loadShaderIfNeeded("Epico", "/shaders/map_default_vertex", "/shaders/epico")
  loadShaderIfNeeded("Lendario", "/shaders/map_default_vertex", "/shaders/lendario")
end

-- Função para carregar shaders restantes sob demanda
local function loadRemainingShaders()
  if shadersLoaded then return end
  
  -- Upgrades restantes
  for i = 4, 12 do
    loadShaderIfNeeded("+" .. i, "/shaders/map_default_vertex", "/shaders/upgrade/+" .. i)
  end
  
  -- Shaders especiais restantes
  loadShaderIfNeeded("Mitico", "/shaders/map_default_vertex", "/shaders/mitico")
  loadShaderIfNeeded("Especial", "/shaders/map_default_vertex", "/shaders/especial")
  
  -- Shaders de output
  loadShaderIfNeeded("ShaderOutBlue", "/shaders/padrao", "/shaders/ShaderOutBlue")
  loadShaderIfNeeded("ShaderOutRed", "/shaders/padrao", "/shaders/ShaderOutRed")
  loadShaderIfNeeded("ShaderOutPurple", "/shaders/padrao", "/shaders/ShaderOutPurple")
  loadShaderIfNeeded("ShaderOutBlack", "/shaders/padrao", "/shaders/ShaderOutBlack")
  loadShaderIfNeeded("ShaderOutMultiColors", "/shaders/padrao", "/shaders/ShaderOutMultiColors")
  
  -- Shaders de charge
  loadShaderIfNeeded("ShaderChargeBlue", "/shaders/padrao", "/shaders/ShaderChargeBlue")
  loadShaderIfNeeded("ShaderChargeLightPink", "/shaders/padrao", "/shaders/ShaderChargeLightPink")
  loadShaderIfNeeded("ShaderChargeGreen", "/shaders/padrao", "/shaders/ShaderChargeGreen")
  loadShaderIfNeeded("ShaderChargeYellow", "/shaders/padrao", "/shaders/ShaderChargeYellow")
  loadShaderIfNeeded("ShaderChargeMultiColors", "/shaders/padrao", "/shaders/ShaderChargeMultiColors")
  loadShaderIfNeeded("outfit_black", "/shaders/padrao", "/shaders/outfit_black")

  -- Shader estático
  loadShaderIfNeeded("ShaderEstaticYellow", "/shaders/padrao", "/shaders/ShaderEstaticYellow")
  
  shadersLoaded = true
end

function init()
  -- Carregar apenas shaders essenciais na inicialização
  loadEssentialShaders()
  
  -- Carregar shaders restantes após 2 segundos (não bloqueia inicialização)
  scheduleEvent(loadRemainingShaders, 2000)
end

function terminate()
end