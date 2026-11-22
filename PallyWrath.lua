-- Pally Wrath: aviso visual para el talento Unsealed Wrath (Paladín Reprensión, WoW Forever)
-- Media luna a la derecha del personaje que se rellena por tercios con cada carga
-- del eco que se esté acumulando. Con 3 cargas se envuelve en llamas y muestra el tiempo.

local ADDON = ...
local PREFIX = "|cffF58CBAPally Wrath|r: "

-- IDs de objetos, iconos y apariencias comprobados en los datos de Forever.
-- Para las dos hachas sin modelo compatible, se usan ilustraciones propias.
local CORRUPTED_ITEM = 22691
local ASHBRINGER_ITEM = 13262
local WEAPONS = {
    { id = ASHBRINGER_ITEM, category = "sword", en = "Ashbringer", es = "Crematoria", icon = 135358, appearance = 66955, zoom = 1,
      effect = { seal = true, aura = "model_ashbringer", light = { 1, 0.84, 0.54 }, glow = 0.40 } },
    { id = CORRUPTED_ITEM, category = "sword", en = "Corrupted Ashbringer", es = "Crematoria corrupta", icon = 135331, appearance = 69249,
      effect = { seal = true, aura = "model_corrupted", light = { 0.79, 1, 0.65 }, glow = 0.42 } },
    { id = 19019, category = "sword", en = "Thunderfury", es = "Trueno Furioso", icon = 135349,
      enFull = "Thunderfury, Blessed Blade of the Windseeker", esFull = "Trueno Furioso, Espada Bendita del Hijo del Viento",
      appearance = 68530, zoom = 1.10, subclass = 7,
      effect = { aura = "model_thunderfury", light = { 0.59, 0.81, 1 }, glow = 0.56 } },
    { id = 13505, category = "sword", en = "Runeblade", es = "Hoja rúnica", icon = 135273,
      enFull = "Runeblade of Baron Rivendare", esFull = "Hoja rúnica del Barón Rivendare",
      appearance = 63795, subclass = 8,
      effect = { itemVisual = 32, aura = "model_rivendare", light = { 0.74, 0.79, 1 }, glow = 0.56 } },
    { id = "eldruin", category = "sword", en = "El’druin", es = "El’druin", art = "eldruin" },
    { id = "azurewrath", category = "sword", en = "Azurewrath", es = "Ira celeste", art = "azurewrath" },
    { id = 49623, category = "axe", en = "Shadowmourne", es = "Agonía de Sombras", art = "shadowmourne" },
    { id = 206448, category = "axe", en = "Fyr’alath", es = "Fyr’alath", art = "fyralath" },
    { id = 17182, category = "mace", en = "Sulfuras", es = "Sulfuras", icon = 133066, appearance = 68303, zoom = 1.10, subclass = 5,
      effect = { aura = "sulfuras", light = { 1, 0.70, 0.47 }, glow = 0.72 },
      enFull = "Sulfuras, Hand of Ragnaros", esFull = "Sulfuras, Mano de Ragnaros" },
}
local CLASSIC_SWORD = { category = "sword", en = "Classic sword", es = "Espada clásica",
                        art = "sword_art", classic = true }
local WEAPON_BY_ITEM = {}
for _, weapon in ipairs(WEAPONS) do WEAPON_BY_ITEM[weapon.id] = weapon end

------------------------------------------------------------
-- Configuración por defecto
------------------------------------------------------------
local DEFAULTS = {
    point = { "CENTER", "UIParent", "CENTER", 120, -20 },
    scale = 1.0,
    sound = true,
    minStacks = 1,   -- a partir de cuántas cargas se ve el indicador
    style = "espada",  -- "luna", "espada" o "modelo"
    sealIcons = {},  -- iconos de sello aprendidos de tus buffs
    countHook = "RefreshApplications",
    modelItem = CORRUPTED_ITEM,
    useEquipped = false,
    modelZoom = 1.0,
    alpha = 0.25,
    fillDir = "arriba",  -- arriba | abajo (vertical) · derecha | izquierda (horizontal)
    modelFacing = 180,   -- giro del modelo 3D en grados
    modelPitch = 285,    -- inclinación
    fog2 = 0.6,          -- densidad de la niebla con 2 cargas (menor = tapa más)
    modelRoll = 270,     -- rotación (grados)
    modelX = 0, modelY = 0.1,  -- desplazamiento del modelo dentro de su marco
    showIcon = true,     -- mostrar el icono del sello
    hideViewer = false,   -- dejar invisible (pero activo) el visor de beneficios de Blizzard
    coverOn = true, coverX = -22, coverY = 48, coverSize = 34,
    holeShape = "cuadrado",  -- forma del hueco: "cuadrado" o "circulo"
    mirror = false,          -- copia simétrica al otro lado del personaje
    mirrorFacing = 180,      -- giro extra del modelo 3D en la copia  -- tapa de la calavera (modelo 3D)
    -- iconOffset = {x, y}  -- posición propia del icono respecto al centro (si lo mueves)         -- opacidad del indicador (0.2 - 1)  -- qué actualización del icono de Blizzard cuenta como carga
    spellIds = {},   -- IDs aprendidos automáticamente: [spellId] = tipo de sello
    colors = {},     -- colores personalizados con /pw color
}

-- Los 6 ecos que puede guardar Unsealed Wrath. Cada uno con:
--   en / es  : palabra clave del sello en inglés y castellano (para reconocer el buff)
--   alias    : nombres que puedes usar en los comandos /pw
--   color    : color del indicador (sacado del icono del sello)
-- Si el nombre del buff en tu cliente es otro, usa /pw buffs para verlo y /pw add <sello> <ID>.
local SEALS = {
    command       = { en = "command",       es = { "orden", "mando" }, alias = { "orden", "command", "mando" },
                      color = { 1.00, 0.50, 0.15 } },  -- naranja
    righteousness = { en = "righteous",     es = { "rectitud" },        alias = { "rectitud", "righteousness" },
                      color = { 0.62, 0.72, 0.88 } },  -- gris azulado
    wisdom        = { en = "wisdom",        es = { "sabidur" },         alias = { "sabiduria", "mana", "wisdom" },
                      color = { 0.25, 0.55, 1.00 } },  -- azul
    light         = { en = "light",         es = { "luz" },             alias = { "luz", "light" },
                      color = { 1.00, 0.90, 0.45 } },  -- amarillo claro
    justice       = { en = "justice",       es = { "justicia" },        alias = { "justicia", "justice" },
                      color = { 0.80, 0.40, 1.00 } },  -- violeta
    fury          = { en = "fury",          es = { "furia" },           alias = { "furia", "fury" },
                      color = { 1.00, 0.22, 0.18 } },  -- rojo
}

-- Icono de cada sello: primero el que aprendemos de tu buff de sello activo,
-- luego el del hechizo por ID y, si no, una ruta de icono clásica.
local SEAL_SPELL = {
    command = 20375, righteousness = 20154, wisdom = 20166,
    light = 20165, justice = 20164,
    fury = 1311649,   -- Seal of Fury de Forever (visto en el visor de Blizzard)
}
local SEAL_ICON_FALLBACK = {
    command       = "Interface\\Icons\\Ability_Warrior_InnerRage",
    righteousness = "Interface\\Icons\\Ability_ThunderBolt",
    wisdom        = "Interface\\Icons\\Spell_Holy_RighteousnessAura",
    light         = "Interface\\Icons\\Spell_Holy_HealingAura",
    justice       = "Interface\\Icons\\Spell_Holy_SealOfWrath",
}

local function SpellIcon(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        if ok and t then return t end
    end
    if GetSpellTexture then
        local ok, t = pcall(GetSpellTexture, id)
        if ok and t then return t end
    end
end

-- ¿Es este buff un sello (no un eco)? Devuelve el tipo.
local function ClassifySeal(name)
    if type(name) ~= "string" then return nil end
    local okL, n = pcall(string.lower, name)
    if not okL or type(n) ~= "string" then return nil end
    if not (n:find("seal of", 1, true) or n:find("sello de", 1, true)) then return nil end
    for kind, info in pairs(SEALS) do
        if n:find(info.en, 1, true) then return kind end
        for _, w in ipairs(info.es) do
            if n:find(w, 1, true) then return kind end
        end
    end
end

local function KindFromAlias(word)
    if not word then return nil end
    for kind, info in pairs(SEALS) do
        for _, al in ipairs(info.alias) do
            if word == al then return kind end
        end
    end
end

local db
local equippedItem
local MAIN_HAND = INVSLOT_MAINHAND or 16

------------------------------------------------------------
-- Idioma: castellano si el juego está en esES/esMX; si no, inglés
------------------------------------------------------------
local LOCALE = GetLocale and GetLocale() or "enUS"
local IS_ES = (LOCALE == "esES" or LOCALE == "esMX")
-- frases completas primero (más largas), luego fragmentos
local EN = {
    { "En combate las cargas se cuentan con el icono de Unsealed Wrath del visor de buffs de Blizzard: no lo quites de allí. /pw ayuda: lista de comandos.",
      "In combat, stacks are counted from the Unsealed Wrath icon in Blizzard's buff tracker: keep it there. /pw help: command list." },
    { "El tamaño del hueco y el zoom son los de la espada principal.", "Hole size and zoom are shared with the main sword." },
    { "Indicador de cargas de Unsealed Wrath. También con /pw.", "Unsealed Wrath stack indicator. Also with /pw." },
    { "Desbloqueado. Arrastra el indicador y escribe /pw fijar.", "Unlocked. Drag the indicator and type /pw lock." },
    { "Desbloqueado, el icono se arrastra por separado.", "Unlocked: the icon can be dragged on its own." },
    { "Copia simétrica al otro lado del personaje", "Mirrored copy on the other side of the character" },
    { "Desbloquear para moverlo (arrastrar)", "Unlock to move it (drag)" },
    { "Clic: cambiar color\nClic derecho: color original", "Click: change color\nRight-click: default color" },
    { "Comandos (/pw solo abre el menú de opciones):", "Commands (/pw alone opens the options menu):" },
    { "Tus buffs actuales (nombre / ID / cargas):", "Your current buffs (name / ID / stacks):" },
    { "  /pw mover  |  /pw fijar   - colocar el indicador", "  /pw unlock  |  /pw lock   - place the indicator" },
    { "  /pw test [sello]           - ver una prueba (orden, rectitud, sabiduria...)", "  /pw test [seal]            - preview (command, righteousness, wisdom...)" },
    { "  /pw estilo luna|espada|modelo - cambiar el dibujo del indicador", "  /pw style moon|sword|model - change the indicator look" },
    { "  /pw escala 1.2             - tamaño", "  /pw scale 1.2              - size" },
    { "  /pw opacidad 25            - transparencia (20-100)", "  /pw opacity 25             - transparency (20-100)" },
    { "  /pw direccion arriba|abajo|derecha|izquierda - sentido de carga", "  /pw dir up|down|right|left - fill direction" },
    { "  /pw giro 90                - girar el modelo 3D (grados)", "  /pw rotate 90              - rotate the 3D model (degrees)" },
    { "  /pw espejo si|no           - copia simétrica al otro lado", "  /pw mirror on|off          - mirrored copy on the other side" },
    { "  /pw sonido                 - activar/desactivar sonido", "  /pw sound                  - toggle sound" },
    { "  /pw minimo 1               - cargas para que aparezca (1-3)", "  /pw min 1                  - stacks needed to show (1-3)" },
    { "  /pw buffs                  - listar tus buffs con su ID", "  /pw buffs                  - list your buffs with their ID" },
    { "  /pw add <sello> <ID>       - asignar un buff a mano", "  /pw add <seal> <ID>        - assign a buff manually" },
    { "  /pw color <sello> R G B    - cambiar el color (0-1)", "  /pw color <seal> R G B     - change color (0-1)" },
    { "  /pw log [borrar]           - ver el registro de diagnóstico", "  /pw log [clear]            - show the debug log" },
    { "Uso: /pw add <sello> <ID>   (orden, rectitud, sabiduria, luz, justicia, furia)", "Usage: /pw add <seal> <ID>   (command, righteousness, wisdom, light, justice, fury)" },
    { "Uso: /pw color <sello> R G B   (valores 0-1)   o   /pw color <sello> reset", "Usage: /pw color <seal> R G B   (values 0-1)   or   /pw color <seal> reset" },
    { "Uso: /pw direccion arriba | abajo | derecha | izquierda", "Usage: /pw dir up | down | right | left" },
    { "Uso: /pw estilo luna | espada | modelo", "Usage: /pw style moon | sword | model" },
    { "Uso: /pw icono si | no | recolocar", "Usage: /pw icon on | off | reset" },
    { "Uso: /pw objeto <ID de objeto>", "Usage: /pw item <item ID>" },
    { "Uso: /pw opacidad 20-100", "Usage: /pw opacity 20-100" },
    { "Uso: /pw giro <grados>", "Usage: /pw rotate <degrees>" },
    { "Uso: /pw escala 0.5-3", "Usage: /pw scale 0.5-3" },
    { "Uso: /pw minimo 1-3", "Usage: /pw min 1-3" },
    { "Uso: /pw zoom 0.5-3", "Usage: /pw zoom 0.5-3" },
    { "El indicador aparece a partir de ", "The indicator shows from " },
    { "En combate cuento cargas con: ", "In combat, stacks are counted with: " },
    { "Registro de diagnóstico (", "Debug log (" },
    { "Configuración restablecida.", "Settings reset." },
    { "Prueba: 1, 2 y 3 cargas.", "Preview: 1, 2 and 3 stacks." },
    { "Sonido al llegar a 3 cargas", "Sound at 3 stacks" },
    { "Mostrar el icono del sello", "Show the seal icon" },
    { "Ocultar el visor de beneficios de Blizzard (sigue activo)", "Hide Blizzard's buff tracker (stays active)" },
    { "En combate no encuentro el icono de Unsealed Wrath. Abre el Cooldown Manager > Beneficios rastreados y añade Unsealed Wrath.", "Can't find the Unsealed Wrath icon in combat. Open Cooldown Manager > Tracked Buffs and add Unsealed Wrath." },
    { "Visor de Blizzard: ", "Blizzard tracker: " },
    { "Aparece desde (cargas)", "Shows from (stacks)" },
    { "Colores de cada sello", "Color of each seal" },
    { "Modelo 3D (encuadre)", "3D model (framing)" },
    { "Recorte del sello: tamaño", "Seal cutout: size" },
    { "Recorte del sello: horizontal", "Seal cutout: horizontal" },
    { "Recorte del sello: vertical", "Seal cutout: vertical" },
    { "Dirección de carga", "Fill direction" },
    { "Hacia la izquierda", "Leftwards" },
    { "Hacia la derecha", "Rightwards" },
    { "hacia la izquierda", "leftwards" },
    { "hacia la derecha", "rightwards" },
    { "Hacia arriba", "Upwards" },
    { "Hacia abajo", "Downwards" },
    { "hacia arriba", "upwards" },
    { "hacia abajo", "downwards" },
    { "Copia simétrica: ", "Mirrored copy: " },
    { "Copia simétrica", "Mirrored copy" },
    { "Espada principal", "Main sword" },
    { "Recolocar icono", "Reset icon" },
    { "Abrir opciones", "Open options" },
    { "Posición guardada.", "Position saved." },
    { "Registro borrado.", "Log cleared." },
    { " (posición propia)", " (custom position)" },
    { "Icono del sello: ", "Seal icon: " },
    { "Giro del modelo: ", "Model rotation: " },
    { "Zoom del modelo: ", "Model zoom: " },
    { "Modelo 3D: objeto ", "3D model: item " },
    { "Ilustración de arma: objeto ", "Weapon illustration: item " },
    { " restablecido.", " reset." },
    { " asignado a ", " assigned to " },
    { " carga(s).", " stack(s)." },
    { " líneas):", " lines):" },
    { ". Opciones:", ". Options:" },
    { "(actual: ", "(current: " },
    { "Subir / bajar", "Up / down" },
    { "Media luna", "Crescent" },
    { "Modelo 3D", "3D model" },
    { "Espada", "Sword" },
    { "Opciones", "Options" },
    { "Indicador", "Indicator" },
    { "Estilo: ", "Style: " },
    { "Estilo", "Style" },
    { "Tamaño", "Size" },
    { "Opacidad: ", "Opacity: " },
    { "Opacidad", "Opacity" },
    { "Escala: ", "Scale: " },
    { "Sonido: ", "Sound: " },
    { "Carga hacia ", "Filling " },
    { "Color de ", "Color of " },
    { "Inclinación", "Pitch" },
    { "Rotación", "Roll" },
    { "Giro", "Turn" },
    { "Probar", "Preview" },
    { "Centrar", "Center" },
    { "Restablecer", "Reset" },
    { "Hueco: ", "Hole: " },
    { "círculo", "circle" },
    { "cuadrado", "square" },
    { "desactivada", "disabled" },
    { "desactivado", "disabled" },
    { "activada", "enabled" },
    { "activado", "enabled" },
    { "oculto", "hidden" },
    { "Actual: ", "Current: " },
    { "Uso: ", "Usage: " },
    { "Sabiduría", "Wisdom" },
    { "Rectitud", "Righteousness" },
    { "Justicia", "Justice" },
    { "Orden", "Command" },
    { "Furia", "Fury" },
    { "Luz", "Light" },
    { "cargado, por", "loaded, by" },
    { "abre las opciones", "opens the options" },
    { "/pw ayuda", "/pw help" },
}
local TR_CACHE = {}
local function TR(text)
    if IS_ES or type(text) ~= "string" then return text end
    local c = TR_CACHE[text]
    if c then return c end
    local out = text
    for _, p in ipairs(EN) do
        local a, b = p[1], p[2]
        local i = out:find(a, 1, true)
        while i do
            out = out:sub(1, i - 1) .. b .. out:sub(i + #a)
            i = out:find(a, i + #b, true)
        end
    end
    TR_CACHE[text] = out
    return out
end
local Log, D   -- se definen más abajo
local PlacePiecesRef
local MirrorValRef = function(k) return 0 end   -- se sustituye por MirrorVal más abajo
local function IsHoriz() return db and (db.fillDir == "derecha" or db.fillDir == "izquierda") end

local function ModelItem()
    if db.useEquipped then return equippedItem end
    return db.modelItem or CORRUPTED_ITEM
end

local function ActiveWeapon()
    return WEAPON_BY_ITEM[ModelItem()]
end

local function ActiveWeaponArt()
    if db.useEquipped then return nil end
    local weapon = ActiveWeapon()
    return weapon and weapon.art
end

local function ActiveWeaponEffect()
    local weapon = ActiveWeapon()
    return weapon and weapon.effect
end

local function SealCutoutEnabled()
    local effect = ActiveWeaponEffect()
    if not effect or not effect.seal then return false end
    if ModelItem() == ASHBRINGER_ITEM then return db.ashbringerCoverOn ~= false end
    return db.coverOn ~= false
end

local function SealCutoutSize(frame)
    local savedSize = db.coverSize or 34
    if ModelItem() ~= ASHBRINGER_ITEM then return savedSize end
    local pixel = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or 1
    local filterMargin = math.min(4, pixel / frame:GetEffectiveScale())
    -- Margen radial para el sello y el redondeo de los límites de recorte en pantalla.
    return savedSize + 2 * (3 + filterMargin)
end

local function ColorAura(texture, sealColor)
    texture:SetVertexColor(sealColor[1], sealColor[2], sealColor[3])
end

------------------------------------------------------------
-- Utilidades
------------------------------------------------------------
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function ClassifyByName(name)
    if type(name) ~= "string" then return nil end
    local okL, n = pcall(string.lower, name)
    if not okL or type(n) ~= "string" then return nil end
    local isEcho = n:find("echo", 1, true) or n:find("eco", 1, true)
    if not isEcho then return nil end
    for kind, info in pairs(SEALS) do
        if n:find(info.en, 1, true) then return kind end
        for _, w in ipairs(info.es) do
            if n:find(w, 1, true) then return kind end
        end
    end
end

-- Recorre los buffs del jugador con la API moderna o la clásica
local function ForEachBuff(callback)
    for i = 1, 40 do
        local name, icon, count, spellId, expirationTime, duration
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not a then break end
            name, icon, count, spellId = a.name, a.icon, a.applications, a.spellId
            expirationTime, duration = a.expirationTime, a.duration
        else
            local n, ic, c, _, dur, exp, _, _, _, sid = UnitBuff("player", i)
            if not n then break end
            name, icon, count, spellId, expirationTime, duration = n, ic, c, sid, exp, dur
        end
        if callback(name, icon, count or 0, spellId, expirationTime or 0, duration or 0) then
            break
        end
    end
end

------------------------------------------------------------
-- Marco visual: media luna en 3 secciones a la derecha del personaje
------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

-- Estilos del indicador: misma lógica, distinto dibujo
-- Estilos del indicador: misma lógica, distinto dibujo
--   luna       : media luna con marco dorado en 3 secciones
--   espada     : espada de paladín que se rellena de la empuñadura a la punta
local STYLES = {
    luna   = { iconX = 46, timerX = 152, name = "Media luna" },
    espada = { iconX = 14, timerX = 112, name = "Espada" },
    modelo = { iconX = 4,  timerX = 160, name = "Modelo 3D" },
}
-- filas (0-1) donde empieza y acaba la espada dentro de su textura
local SWORD_TOP, SWORD_BOTTOM = 0.0059, 0.9961

local f = CreateFrame("Frame", "PallyWrathFrame", UIParent)
f:SetSize(128, 256)
f:SetFrameStrata("MEDIUM")
f:Hide()

-- Capas: fondo (f) < llamas (f) < relleno (lit) < marco, icono y tiempo (top)
local lit = CreateFrame("Frame", nil, f)
lit:SetAllPoints()
local top = CreateFrame("Frame", nil, f)
top:SetAllPoints()
top:SetFrameLevel(lit:GetFrameLevel() + 2)

-- Llamas animadas (16 fotogramas en una tira de 2048x256)
local FLAME_FRAMES, FLAME_FPS = 16, 20
local flame = f:CreateTexture(nil, "BORDER")
flame:SetSize(256, 512)
flame:SetPoint("CENTER", f, "CENTER", 0, 0)
flame:SetBlendMode("ADD")
flame:SetTexCoord(0, 1 / FLAME_FRAMES, 0, 1)
flame:Hide()
local flameTime = 0

---------------- Media luna
local moonBg = f:CreateTexture(nil, "BACKGROUND")
moonBg:SetAllPoints()
moonBg:SetTexture(MEDIA .. "moon_bg")
local fill = {}
for i = 1, 3 do
    local t = lit:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(MEDIA .. "moon" .. i)
    t:SetBlendMode("BLEND")   -- mantiene el color del sello tal cual
    t:Hide()
    fill[i] = t
end
local moonFrame = top:CreateTexture(nil, "ARTWORK")
moonFrame:SetAllPoints()
moonFrame:SetTexture(MEDIA .. "moon_frame")

---------------- Modelo 3D del juego (lo dibuja tu cliente): un solo modelo, la carga se ve en su luz
local model = CreateFrame("PlayerModel", nil, f)          -- base, apagada
model:Hide()
local modelClip = CreateFrame("Frame", nil, lit)           -- (ya no se usa para recortar; guarda el último estado de luz)
modelClip:Hide()
local modelInfoLogged = false

-- Tapa de la calavera: parche de acero que se pone encima del modelo con 1 y 2 cargas
local cover = CreateFrame("Frame", nil, top)
cover:SetFrameLevel(top:GetFrameLevel() + 2)
cover:SetMovable(true)
cover:RegisterForDrag("LeftButton")
cover.tex = cover:CreateTexture(nil, "OVERLAY")
cover.tex:SetAllPoints()
cover.tex:SetTexture(MEDIA .. "hole_ring")
cover.sq = cover:CreateTexture(nil, "OVERLAY")        -- marcador cuadrado
cover.sq:SetAllPoints()
cover.sq:SetColorTexture(1, 0.85, 0.3, 0.35)
cover:Hide()
cover:SetScript("OnDragStart", function(self) if f.unlocked then self:StartMoving() end end)
cover:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local s1, s2 = self:GetEffectiveScale(), f:GetEffectiveScale()
    local ix, iy = self:GetCenter()
    local fx, fy = f:GetCenter()
    if ix and fx then
        local x, y = (ix * s1 - fx * s2) / s2, (iy * s1 - fy * s2) / s2
        if IsHoriz() then x, y = y, -x end
        db.coverX, db.coverY = x, y
    end
    self:ClearAllPoints()
    local x, y = db.coverX, db.coverY
    if IsHoriz() then x, y = -y, x end
    self:SetPoint("CENTER", f, "CENTER", x, y)
    if PlacePiecesRef then PlacePiecesRef() end
end)

local function PlaceCover()
    cover:ClearAllPoints()
    local x, y = db.coverX or -22, db.coverY or 48
    if IsHoriz() then x, y = -y, x end            -- en horizontal el modelo se tumba 90º
    cover:SetPoint("CENTER", f, "CENTER", x, y)
    local size = SealCutoutSize(f)
    cover:SetSize(size, size)
end


local function ModelHasFile(m)
    if not m.GetModelFileID then return m._loadedId ~= nil end
    local ok, fid = pcall(m.GetModelFileID, m)
    return ok and fid ~= nil and fid ~= 0
end

local ModelAuraProfile
local function NativeFireVisual(color)
    local r, g, b = color[1], color[2], color[3]
    if math.max(r, g, b) - math.min(r, g, b) < 0.23 then return 126 end -- claro
    if b > g and r > g then return 128 end  -- violeta
    if b > r and b > g then return 27 end   -- azul
    if g > r then return 127 end           -- verde
    return g > 0.67 * r and 129 or 25       -- dorado o rojo
end

local function SetupModel(m, level, col, mirror, alpha)
    -- cargar el objeto solo si cambia o si el modelo se ha quedado vacío (recargar = parpadeo)
    local id = ModelItem()
    if not id then
        if m._loadedId and m.ClearModel then m:ClearModel() end
        m._loadedId, m._loadedVisual, m._camKey = nil, nil, nil
        return false, "sin arma equipada"
    end
    local weapon = ActiveWeapon()
    local effect = ActiveWeaponEffect()
    local full = level and level >= 3 or false
    col = col or { 1, 1, 1 }
    local itemVisual = 0
    if full then
        if effect and effect.itemVisual then
            itemVisual = effect.itemVisual
        elseif not ModelAuraProfile(effect, mirror) then
            itemVisual = NativeFireVisual(col)
        end
    end
    local ok, err = true, nil
    if m._loadedId ~= id or m._loadedVisual ~= itemVisual or not ModelHasFile(m) then
        if m._loadedId ~= id and m.ClearModel then m:ClearModel() end
        ok, err = pcall(m.SetItem, m, id, 0, itemVisual)
        if err == false then ok = false end
        if not ok and m.SetItemAppearance and (not db.useEquipped or (weapon and weapon.appearance)) then
            ok, err = pcall(m.SetItemAppearance, m, weapon and weapon.appearance or id, itemVisual, weapon and weapon.subclass)
            if err == false then ok = false end
        end
        if not ok and not db.useEquipped and not weapon and m.SetDisplayInfo and db.modelDisplay then
            ok, err = pcall(m.SetDisplayInfo, m, db.modelDisplay)
        end
        if ok then m._loadedId, m._loadedVisual = id, itemVisual end
        m._camKey = nil
    end
    -- cámara: solo cuando cambia algún ajuste del encuadre
    local facing = mirror and MirrorValRef("mFacing") or (db.modelFacing or 0)
    local pitch  = mirror and MirrorValRef("mPitch")  or (db.modelPitch or 255)
    local roll   = mirror and MirrorValRef("mRoll")   or (db.modelRoll or 90)
    local camKey = table.concat({ db.modelZoom or 1, db.modelX or 0, db.modelY or 0.1, facing,
        pitch, roll, IsHoriz() and 1 or 0 }, ":")
    if m._camKey ~= camKey then
        m._camKey = camKey
        pcall(m.SetPortraitZoom, m, 0)
        pcall(m.SetCamDistanceScale, m, db.modelZoom or 1.0)
        pcall(m.SetPosition, m, 0, db.modelX or 0, db.modelY or 0.1)
        pcall(m.SetFacing, m, math.rad(facing))
        if m.SetPitch then pcall(m.SetPitch, m, math.rad(pitch)) end
        if m.SetRoll then pcall(m.SetRoll, m, math.rad(roll + (IsHoriz() and -90 or 0))) end
    end
    -- Base legible sin emisores. Al completar las cargas entra la luz propia del arma.
    level = tonumber(level) or 0
    local r, g, b, amb, dif, desat
    if effect and full then
        r, g, b = effect.light[1], effect.light[2], effect.light[3]
        amb, dif, desat = 1, 1, 0
    elseif level < 2 then
        r, g, b = 0.72, 0.72, 0.72
        amb, dif, desat = 0.62, 0.48, 1
    elseif level == 2 then
        r, g, b = 0.52 + 0.43 * col[1], 0.52 + 0.43 * col[2], 0.52 + 0.43 * col[3]
        amb, dif, desat = 0.92, 0.84, 0
    else
        local glow = math.min(3, level) / 3
        r, g, b = 0.60 + 0.40 * col[1] * glow, 0.60 + 0.40 * col[2] * glow, 0.60 + 0.40 * col[3] * glow
        amb, dif, desat = 0.30 + 0.70 * glow, 0.20 + 0.80 * glow, 1 - glow
    end
    local okL = pcall(m.SetLight, m, true, { omnidirectional = false, point = CreateVector3D and CreateVector3D(-1, 1, -1) or nil,
        ambientIntensity = amb, ambientColor = CreateColor and CreateColor(r, g, b) or nil,
        diffuseIntensity = dif, diffuseColor = CreateColor and CreateColor(r, g, b) or nil })
    if not okL then okL = pcall(m.SetLight, m, true, false, -1, 1, -1, amb, r, g, b, dif, r, g, b) end
    if m.SetDesaturation then pcall(m.SetDesaturation, m, desat) end
    -- la niebla no hace efecto en Forever: se quita por si quedó puesta
    if m.ClearFog then pcall(m.ClearFog, m) end
    -- Los efectos nativos acompañan al arma al cambiar su cámara.
    if m.SetParticlesEnabled then pcall(m.SetParticlesEnabled, m, full) end
    if m.SetGlow then pcall(m.SetGlow, m, full and effect and effect.glow or 0) end
    -- los modelos 3D no heredan la opacidad del marco: se aplica aparte
    alpha = alpha or db.alpha or 0.25
    if m.SetModelAlpha then pcall(m.SetModelAlpha, m, alpha) end
    pcall(m.SetAlpha, m, alpha)
    return ok, err, okL
end

-- 4 trozos del modelo recortados alrededor del hueco de la calavera (misma cámara que el modelo)
local HOLE_ROWS = 8                       -- franjas para redondear el hueco
local pieces = {}
for i = 1, 2 + 2 * HOLE_ROWS do
    local clip = CreateFrame("Frame", nil, f)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    local m = CreateFrame("PlayerModel", nil, clip)
    m:SetAllPoints(model)
    clip:Hide()
    pieces[i] = { clip = clip, m = m }
end
local curLevel, curCol = 0, { 1, 1, 1 }
local function SetupPieces(level, col)
    curLevel, curCol = level or curLevel, col or curCol
    for _, p in ipairs(pieces) do SetupModel(p.m, curLevel, curCol) end
end
for _, p in ipairs(pieces) do
    -- un modelo cargado mientras estaba oculto puede salir vacío: se recarga al mostrarse
    p.m:SetScript("OnShow", function(self) SetupModel(self, curLevel, curCol) end)
end
local function ModelHoleRects(W, H, x, y, diameter)
    local hs = diameter / 2
    -- hueco en coordenadas del modelo (origen arriba a la izquierda)
    local cx, cy = W / 2 + x, H / 2 - y
    local t = math.max(0, math.min(H, cy - hs))
    local b = math.max(0, math.min(H, cy + hs))
    -- hueco circular: arriba y abajo enteros; en medio, franjas cortadas a la anchura del círculo
    local rects = { { 0, 0, W, t }, { 0, b, W, H - b } }
    local rowH = (b - t) / HOLE_ROWS
    local coverEntireBand = ModelItem() == ASHBRINGER_ITEM
    for k = 0, HOLE_ROWS - 1 do
        local y0 = t + k * rowH
        local ym = y0 + rowH / 2
        local dy = math.abs(ym - cy)
        local half
        if db.holeShape == "circulo" then
            -- Cubre todo el arco dentro de la franja, no solo su punto medio.
            if coverEntireBand then dy = math.max(0, dy - rowH / 2) end
            half = (dy < hs) and math.sqrt(hs * hs - dy * dy) or 0
        else
            half = hs
        end
        local hl = math.max(0, math.min(W, cx - half))
        local hr = math.max(0, math.min(W, cx + half))
        rects[#rects + 1] = { 0, y0, hl, rowH }          -- a la izquierda del círculo
        rects[#rects + 1] = { hr, y0, W - hr, rowH }     -- a la derecha del círculo
    end
    return rects
end

local piecesKey
local function PlacePieces(force)
    local W, H = model:GetWidth(), model:GetHeight()
    local size = SealCutoutSize(model)
    local key = table.concat({ ModelItem(), W, H, db.coverX or -22, db.coverY or 48, size,
        db.holeShape or "cuadrado", IsHoriz() and 1 or 0 }, ":")
    if not force and key == piecesKey then return end
    piecesKey = key
    local x, y = db.coverX or -22, db.coverY or 48
    if IsHoriz() then x, y = -y, x end
    local rects = ModelHoleRects(W, H, x, y, size)
    for i, p in ipairs(pieces) do
        local rx, ry, rw, rh = unpack(rects[i])
        p.clip:ClearAllPoints()
        p.clip:SetPoint("TOPLEFT", model, "TOPLEFT", rx, -ry)
        p.clip:SetSize(math.max(rw, 0.01), math.max(rh, 0.01))
        p.m:ClearAllPoints()
        p.m:SetAllPoints(model)
    end
end
PlacePiecesRef = PlacePieces
local function ShowPieces(show)
    for _, p in ipairs(pieces) do
        if p.clip:IsShown() ~= show then p.clip:SetShown(show) end
    end
end

local function LoadModel(col, level)
    local ok, err, okL = SetupModel(model, level or 0, col)
    if SealCutoutEnabled() then SetupPieces(level or 0, col) end
    if not modelInfoLogged then
        modelInfoLogged = true
        Log("modelo 3D objeto " .. tostring(ModelItem()) .. ": " .. (ok and "cargado" or ("ERROR " .. D(err))) ..
            " | luz=" .. tostring(okL) .. 
            " | recorte=" .. tostring(modelClip.SetClipsChildren ~= nil) ..
            " | SetPitch=" .. tostring(model.SetPitch ~= nil) .. " | SetRoll=" .. tostring(model.SetRoll ~= nil) ..
            " | SetDesaturation=" .. tostring(model.SetDesaturation ~= nil) ..
            " | partículas=" .. tostring(model.SetParticlesEnabled ~= nil))
    end
end
model:SetScript("OnShow", function() SetupModel(model, curLevel or 0, curCol) end)


local moonParts = { moonBg, moonFrame }

-- Icono del sello que se está acumulando
-- va en su propio marco para poder ocultarlo o moverlo aparte
local iconHolder = CreateFrame("Frame", nil, top)
iconHolder:SetSize(34, 34)
iconHolder:SetFrameLevel(top:GetFrameLevel() + 1)
iconHolder:SetMovable(true)
iconHolder:RegisterForDrag("LeftButton")
local iconBorder = iconHolder:CreateTexture(nil, "BACKGROUND")
iconBorder:SetAllPoints()
iconBorder:SetColorTexture(0, 0, 0, 0.9)
local icon = iconHolder:CreateTexture(nil, "BORDER")
icon:SetSize(30, 30)
icon:SetPoint("CENTER", iconBorder, "CENTER")
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local iconRing = iconHolder:CreateTexture(nil, "ARTWORK")
iconRing:SetSize(42, 42)
iconRing:SetPoint("CENTER", iconBorder, "CENTER")
iconRing:SetTexture(MEDIA .. "ash_frame")

-- Temporizador (solo con 3 cargas)
local timer = top:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
timer:Hide()

-- Aparición suave
local fadeIn = f:CreateAnimationGroup()
local fi = fadeIn:CreateAnimation("Alpha")
fi:SetFromAlpha(0)
fi:SetToAlpha(1)
fi:SetDuration(0.2)

-- Arrastrar cuando está desbloqueado
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self) if self.unlocked then self:StartMoving() end end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    db.point = { p, "UIParent", rp, x, y }
end)

-- En horizontal el indicador se gira 90º en sentido horario: lo de abajo queda a la izquierda

-- Coloca una textura que ocupa todo el indicador, mostrando solo el tramo [a0,a1] de su eje
-- largo (0-1, de arriba abajo en vertical; de izquierda a derecha en horizontal).
local function CropTexture(frame, tex, a0, a1, mirrored)
    a0, a1 = a0 or 0, a1 or 1
    tex:ClearAllPoints()
    local W, H = frame:GetWidth(), frame:GetHeight()
    if IsHoriz() then
        if mirrored then a0, a1 = 1 - a1, 1 - a0 end
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", W * a0, 0)
        tex:SetSize(math.max(W * (a1 - a0), 0.01), H)
        if mirrored then
            tex:SetTexCoord(0, a0, 1, a0, 0, a1, 1, a1)
        else
            tex:SetTexCoord(0, 1 - a0, 1, 1 - a0, 0, 1 - a1, 1, 1 - a1)
        end
    else
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -H * a0)
        tex:SetSize(W, math.max(H * (a1 - a0), 0.01))
        if mirrored then tex:SetTexCoord(1, 0, a0, a1) else tex:SetTexCoord(0, 1, a0, a1) end
    end
end

local function PlaceCrop(tex, a0, a1)
    CropTexture(f, tex, a0, a1, false)
end

-- Las ilustraciones comparten un lienzo de 256 × 512 con 18 px libres arriba y abajo.
local ART_TOP, ART_BOTTOM = 18 / 512, 494 / 512
local function DrawWeaponSections(frame, sections, asset, count, color, mirrored, classic)
    local forward = db.fillDir == "abajo" or db.fillDir == "izquierda"
    local horizontal = IsHoriz()
    local topEdge = classic and SWORD_TOP or ART_TOP
    local bottomEdge = classic and SWORD_BOTTOM or ART_BOTTOM
    local span = (bottomEdge - topEdge) / 3
    local seam = count < 3 and 1.5 / 256 or 0
    for i, section in ipairs(sections) do
        section:SetShown(i <= count)
        if i <= count then
            local band = forward and i or 4 - i
            local first = band == 1 and 0 or topEdge + (band - 1) * span + seam
            local last = band == 3 and 1 or topEdge + band * span - seam
            section:SetTexture(asset)
            section:SetVertexColor(0.76 + 0.24 * color[1], 0.76 + 0.24 * color[2], 0.76 + 0.24 * color[3])
            if horizontal then
                CropTexture(frame, section, 1 - last, 1 - first, mirrored)
            else
                CropTexture(frame, section, first, last, mirrored)
            end
        end
    end
end

local function BuildWeaponArt(frame, parent, mirrored)
    local body = parent:CreateTexture(nil, "ARTWORK")
    body:SetDesaturated(true)
    body:SetVertexColor(0.48, 0.48, 0.48)
    local sections = {}
    for i = 1, 3 do sections[i] = parent:CreateTexture(nil, "ARTWORK", nil, 1) end
    local layers = {}
    function layers:Hide()
        body:Hide()
        for _, section in ipairs(sections) do section:Hide() end
    end

    function layers:Draw(count, color)
        local weapon = db.style == "espada" and CLASSIC_SWORD or ActiveWeapon()
        local texture = MEDIA .. weapon.art
        body:SetTexture(texture)
        CropTexture(frame, body, 0, 1, mirrored)
        body:Show()
        DrawWeaponSections(frame, sections, texture, count, color, mirrored, weapon.classic)
    end

    layers:Hide()
    return layers
end

local weaponArt = BuildWeaponArt(f, top, false)

iconHolder:SetScript("OnDragStart", function(self) if f.unlocked then self:StartMoving() end end)
iconHolder:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local s1, s2 = self:GetEffectiveScale(), f:GetEffectiveScale()
    local ix, iy = self:GetCenter()
    local fx, fy = f:GetCenter()
    if ix and fx then
        db.iconOffset = { (ix * s1 - fx * s2) / s2, (iy * s1 - fy * s2) / s2 }
    end
    self:ClearAllPoints()
    self:SetPoint("CENTER", f, "CENTER", db.iconOffset[1], db.iconOffset[2])
end)

-- Encuadre por arma y dirección. La copia conserva su propio giro e inclinación.
local PROFILE_KEYS = { "modelFacing", "modelPitch", "modelRoll", "modelZoom", "modelX", "modelY",
                       "coverSize", "coverX", "coverY", "holeShape",
                       "mFacing", "mPitch", "mRoll", "mCoverX", "mCoverY" }   -- m* = copia simétrica
-- un encuadre por dirección de carga (valores elegidos por Julen)
local PROFILE_DEFAULTS = {
    arriba    = { modelFacing = 180, modelPitch = 285, modelRoll = 270, modelZoom = 1.0, modelY = 0.1,
                  coverSize = 36, coverX = -24, coverY = 48,  holeShape = "cuadrado" },
    abajo     = { modelFacing = 180, modelPitch = 120, modelRoll = 270, modelZoom = 1.0, modelY = 0.2,
                  coverSize = 36, coverX = -22, coverY = -46, holeShape = "cuadrado" },
    derecha   = { modelFacing = 90,  modelPitch = 0,   modelRoll = 75,  modelZoom = 1.0, modelY = 0.2,
                  coverSize = 36, coverX = 30,  coverY = -52, holeShape = "cuadrado" },
    izquierda = { modelFacing = 270, modelPitch = 180, modelRoll = 255, modelZoom = 1.0, modelY = 0.2,
                  coverSize = 36, coverX = 30,  coverY = -54, holeShape = "cuadrado" },
}
-- El encuadre hacia arriba se afinó en el cliente. Los demás son puntos de partida.
-- Se ajustan por dirección en Avanzado si se cambia la cámara.
local ASHBRINGER_CUTOUT = {
    arriba    = { coverX = -14, coverY =  53, coverSize = 26, holeShape = "circulo" },
    abajo     = { coverX = -14, coverY = -50, coverSize = 32, holeShape = "circulo" },
    derecha   = { coverX =  19, coverY = -56, coverSize = 32, holeShape = "circulo" },
    izquierda = { coverX =  19, coverY = -58, coverSize = 32, holeShape = "circulo" },
}
-- valores de la copia: si no están ajustados, se deducen de los de la principal
local function MirrorVal(k)
    if db[k] ~= nil then return db[k] end
    if k == "mFacing" then return ((db.modelFacing or 0) + 180) % 360 end
    if k == "mPitch"  then return (360 - (db.modelPitch or 0)) % 360 end   -- inclinación invertida
    if k == "mRoll"   then return db.modelRoll or 0 end
    if k == "mCoverX" then return -(db.coverX or 0) end
    if k == "mCoverY" then return db.coverY or 0 end
end

MirrorValRef = MirrorVal
local function SyncProfile()
    local item = ModelItem()
    if not item then return end
    db.weaponProfiles = db.weaponProfiles or {}
    if db._prof and not db._profItem then
        -- Los ajustes anteriores compartían una sola tabla para cualquier arma.
        db.weaponProfiles[item] = db.prof or {}
        db._profItem = item
    end
    db.prof = nil
    if not db.ashbringerMaskV then
        -- Las versiones anteriores guardaban coordenadas de la calavera incluso para Crematoria.
        for direction, profile in pairs(db.weaponProfiles[ASHBRINGER_ITEM] or {}) do
            for key in pairs(ASHBRINGER_CUTOUT[direction] or {}) do profile[key] = nil end
            profile.mCoverX, profile.mCoverY = nil, nil
        end
        local mask = db._profItem == ASHBRINGER_ITEM and ASHBRINGER_CUTOUT[db._prof]
        if mask then
            for key, value in pairs(mask) do db[key] = value end
            db.mCoverX, db.mCoverY = nil, nil
        end
        db.ashbringerMaskV = 1
    end
    local want = PROFILE_DEFAULTS[db.fillDir] and db.fillDir or "arriba"
    if db._prof == want and db._profItem == item then return end
    if db._prof and db._profItem then
        local previous = db.weaponProfiles[db._profItem] or {}
        local profile = {}
        for _, key in ipairs(PROFILE_KEYS) do profile[key] = db[key] end
        previous[db._prof] = profile
        db.weaponProfiles[db._profItem] = previous
    end
    local profiles = db.weaponProfiles[item]
    local profile = profiles and profiles[want]
    local weapon = ActiveWeapon()
    local mask = item == ASHBRINGER_ITEM and ASHBRINGER_CUTOUT[want] or nil
    for _, key in ipairs(PROFILE_KEYS) do
        local value = profile and profile[key]
        if value == nil then
            value = (mask and mask[key]) or (key == "modelZoom" and weapon and weapon.zoom) or PROFILE_DEFAULTS[want][key]
            if value == nil and key == "modelX" then value = DEFAULTS.modelX end
        end
        db[key] = value
    end
    db._prof, db._profItem = want, item
end

local SULFURAS_HEAD = {
    arriba = { -12, 51 }, abajo = { -12, -49 },
    derecha = { 54, 25 }, izquierda = { 54, 25 },
}

ModelAuraProfile = function(effect, mirrored)
    if not effect or not effect.aura then return end
    local direction = PROFILE_DEFAULTS[db.fillDir] and db.fillDir or "arriba"
    local camera = PROFILE_DEFAULTS[direction]
    local facing = mirrored and MirrorVal("mFacing") or db.modelFacing
    local pitch = mirrored and MirrorVal("mPitch") or db.modelPitch
    local roll = mirrored and MirrorVal("mRoll") or db.modelRoll
    local baseFacing = (camera.modelFacing + (mirrored and 180 or 0)) % 360
    local basePitch = (mirrored and -camera.modelPitch or camera.modelPitch) % 360
    -- El contorno es una proyección del arma. Al cambiar la cámara se usa fuego 3D en el modelo.
    if facing ~= baseFacing or pitch ~= basePitch or (db.modelX or 0) ~= DEFAULTS.modelX
        or db.modelY ~= camera.modelY then return end
    local rollOffset = (roll or camera.modelRoll) - camera.modelRoll
    if effect.aura ~= "sulfuras" and rollOffset ~= 0 then return end
    local zoom = ActiveWeapon().zoom or camera.modelZoom
    return direction, zoom / math.max(0.25, db.modelZoom or zoom), rollOffset
end

local function SetAuraFrame(texture, frameIndex, mirrored)
    local left = (frameIndex + 0.5 / 128) / FLAME_FRAMES
    local right = (frameIndex + 1 - 0.5 / 128) / FLAME_FRAMES
    if texture.auraRotated then
        local first, last = 1, 0
        if mirrored then
            if texture.modelContour then
                left, right = right, left
            else
                first, last = last, first
            end
        end
        texture:SetTexCoord(left, first, right, first, left, last, right, last)
    else
        if mirrored then left, right = right, left end
        if texture.auraInverted then
            texture:SetTexCoord(left, right, 1, 0)
        else
            texture:SetTexCoord(left, right, 0, 1)
        end
    end
end

local function ConfigureAura(texture, frame, mirrored)
    local horizontal = IsHoriz()
    local artwork = db.style == "espada" and CLASSIC_SWORD.art or (db.style == "modelo" and ActiveWeaponArt())
    local effect = db.style == "modelo" and ActiveWeaponEffect()
    local direction, scale, rollOffset = ModelAuraProfile(effect, mirrored)
    local x, y, width, height = 0, 0, 256, 512
    local asset
    local modelContour = direction ~= nil and effect.aura ~= "sulfuras"
    if artwork then
        asset, width, height = "aura_" .. artwork, 176, 352
    elseif direction then
        if modelContour then
            asset, width, height = "aura_" .. effect.aura, 176 * scale, 352 * scale
        else
            local head = SULFURAS_HEAD[direction]
            x, y = head[1], head[2]
            if mirrored then
                if horizontal then y = -y else x = -x end
            end
            local angle = math.rad(rollOffset)
            local sine, cosine = math.sin(angle), math.cos(angle)
            x, y = (x * cosine - y * sine) * scale, (x * sine + y * cosine) * scale
            asset, width, height = "aura_sulfuras", 128 * scale, 128 * scale
        end
    elseif db.style == "luna" then
        asset = "flame_moon" .. (horizontal and "_h" or "")
    end
    texture.auraEnabled = asset ~= nil
    texture.modelContour = modelContour
    texture.auraRotated = (artwork or modelContour) and horizontal
    texture.auraInverted = modelContour and direction == "abajo"
    texture:SetTexture(asset and MEDIA .. asset or nil)
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", frame, "CENTER", x, y)
    if horizontal then texture:SetSize(height, width) else texture:SetSize(width, height) end
    SetAuraFrame(texture, 0, mirrored)
end

local function ApplyStyle()
    if db.style == "ashbringer" then db.style = "espada" end
    if db.style == "espada" then db.useEquipped = false end
    SyncProfile()
    if not STYLES[db.style] then db.style = "luna" end
    if db.style ~= "luna" and not db.useEquipped then db.weaponStyle = db.style end
    local st = STYLES[db.style]
    local isModel = db.style == "modelo" and ModelItem() ~= nil and not ActiveWeaponArt()
    weaponArt:Hide()
    for _, p in ipairs(moonParts) do p:SetShown(db.style == "luna") end
    if db.style ~= "luna" then for i = 1, 3 do fill[i]:Hide() end end
    local horiz = IsHoriz()
    f:SetSize(horiz and 256 or 128, horiz and 128 or 256)
    for _, t in ipairs({ moonBg, moonFrame, fill[1], fill[2], fill[3] }) do PlaceCrop(t, 0, 1) end
    model:ClearAllPoints()
    model:SetSize(horiz and 270 or 150, horiz and 150 or 270)
    model:SetPoint("CENTER", f, "CENTER", 0, 0)
    model:SetShown(isModel)
    modelClip:SetShown(false)
    PlaceCover()
    cover:Hide()
    if isModel and SealCutoutEnabled() then PlacePieces(true) else ShowPieces(false) end
    if isModel then LoadModel() end
    ConfigureAura(flame, f, false)
    iconHolder:ClearAllPoints()
    timer:ClearAllPoints()
    local off = db.iconOffset            -- posición propia del icono (si lo has movido)
    if off then
        iconHolder:SetPoint("CENTER", f, "CENTER", off[1], off[2])
    elseif horiz then
        iconHolder:SetPoint("CENTER", f, "LEFT", -22, 0)
    else
        iconHolder:SetPoint("CENTER", f, "TOPLEFT", st.iconX, -128)
    end
    iconHolder:SetShown(db.showIcon ~= false)
    if horiz then
        timer:SetPoint("LEFT", f, "RIGHT", 10, 0)
    else
        timer:SetPoint("LEFT", f, "TOPLEFT", st.timerX, -128)
    end
end

local function SealIcon(kind)
    return (db.sealIcons and db.sealIcons[kind])
        or SpellIcon(SEAL_SPELL[kind])
        or SEAL_ICON_FALLBACK[kind]
        or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ApplyPosition()
    f:ClearAllPoints()
    local p = db.point
    f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    f:SetScale(db.scale)
    if db.style == "modelo" and ModelItem() == ASHBRINGER_ITEM then
        local size = SealCutoutSize(f)
        cover:SetSize(size, size)
    end
    f:SetAlpha(db.alpha or 0.25)
    fi:SetToAlpha(db.alpha or 0.25)
    if model.SetModelAlpha then pcall(model.SetModelAlpha, model, db.alpha or 0.25) end
end

------------------------------------------------------------
-- Lógica
------------------------------------------------------------
local shownStacks = 0
local shownSeal
local expiresAt = 0
local testMode = false

local function ShowMoon(kind, tex, count, exp)
    count = math.min(count, 3)
    if count < 1 then
        shownStacks, expiresAt = 0, 0
        f:Hide()
        return
    end
    local c = (db.colors and db.colors[kind]) or SEALS[kind].color
    if db.style == "espada" or (db.style == "modelo" and ActiveWeaponArt()) then
        weaponArt:Draw(count, c)
    elseif db.style == "modelo" then
        local key = kind .. ":" .. count
        if modelClip.lastColor ~= key then
            modelClip.lastColor = key
            SetupModel(model, count, c)
            if SealCutoutEnabled() then SetupPieces(count, c) end
        end
        -- hueco transparente en la calavera hasta tener 3 cargas: el modelo se dibuja en 4 trozos
        local hole = SealCutoutEnabled() and count < 3
        if hole then PlacePieces() end
        curLevel, curCol = count, c
        if hole then
            if model:IsShown() then model:Hide() end
            ShowPieces(true)
        else
            model:SetShown(ModelItem() ~= nil)   -- primero el entero, luego quitar trozos: sin hueco intermedio
            ShowPieces(false)
        end
        -- desbloqueado: un marco tenue marca dónde está el hueco para poder arrastrarlo
        if f.unlocked and SealCutoutEnabled() then
            local circ = db.holeShape == "circulo"
            cover.tex:SetShown(circ); cover.sq:SetShown(not circ)
            cover.tex:SetVertexColor(1, 1, 1); cover:SetAlpha(0.8); cover:Show()
        else
            cover:Hide()
        end
        modelClip:Hide()
    else
        local rev = db.fillDir == "abajo" or db.fillDir == "izquierda"
        for i = 1, 3 do
            local seg = rev and (4 - i) or i
            fill[seg]:SetVertexColor(c[1], c[2], c[3])
            fill[seg]:SetShown(i <= count)
        end
    end
    ColorAura(flame, c)
    icon:SetTexture(SealIcon(kind))
    expiresAt = exp or 0

    if not f:IsShown() then
        f:Show()
        fadeIn:Play()
    end

    local full = count >= 3
    flame:SetShown(full and flame.auraEnabled)
    timer:SetShown(full)
    if full and shownStacks < 3 then
        if db.sound then
            if SOUNDKIT and SOUNDKIT.RAID_WARNING then
                PlaySound(SOUNDKIT.RAID_WARNING, "Master")
            else
                PlaySound(8959, "Master")
            end
        end
    end
    shownStacks = count
    shownSeal = kind
end

local function HideMoon()
    if f.unlocked or testMode then return end
    shownStacks = 0
    f:Hide()
end

------------------------------------------------------------
-- Copia en espejo al otro lado del personaje (opcional, todos los estilos)
------------------------------------------------------------
local M = CreateFrame("Frame", "PallyWrathMirror", UIParent)
M:SetSize(128, 256)
M:SetFrameStrata("MEDIUM")
M:Hide()
local mLit = CreateFrame("Frame", nil, M); mLit:SetAllPoints()
local mTop = CreateFrame("Frame", nil, M); mTop:SetAllPoints(); mTop:SetFrameLevel(mLit:GetFrameLevel() + 2)
local mWeaponArt = BuildWeaponArt(M, mTop, true)
local mFlame = M:CreateTexture(nil, "BORDER"); mFlame:SetBlendMode("ADD"); mFlame:SetPoint("CENTER", M, "CENTER"); mFlame:Hide()
local mMoonBg = M:CreateTexture(nil, "BACKGROUND"); mMoonBg:SetTexture(MEDIA .. "moon_bg")
local mFill = {}
for i = 1, 3 do
    local t = mLit:CreateTexture(nil, "ARTWORK"); t:SetTexture(MEDIA .. "moon" .. i); t:Hide(); mFill[i] = t
end
local mMoonFrame = mTop:CreateTexture(nil, "ARTWORK"); mMoonFrame:SetTexture(MEDIA .. "moon_frame")
local mModel = CreateFrame("PlayerModel", nil, M); mModel:Hide()
local mPieces = {}
for i = 1, 2 + 2 * HOLE_ROWS do
    local clip = CreateFrame("Frame", nil, M)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    local pm = CreateFrame("PlayerModel", nil, clip)
    pm:SetAllPoints(mModel)
    clip:Hide()
    mPieces[i] = { clip = clip, m = pm }
end
local mLevel, mCol, mKey, mPiecesKey = 0, { 1, 1, 1 }, nil, nil
local mMarker = mTop:CreateTexture(nil, "OVERLAY")
mMarker:SetColorTexture(1, 0.85, 0.3, 0.35)
mMarker:Hide()
mModel:SetScript("OnShow", function(self) SetupModel(self, mLevel, mCol, true) end)
for _, p in ipairs(mPieces) do p.m:SetScript("OnShow", function(self) SetupModel(self, mLevel, mCol, true) end) end

-- como PlaceCrop, pero dando la vuelta de izquierda a derecha
local function MirrorCrop(tex, a0, a1)
    CropTexture(M, tex, a0, a1, true)
end

local function MirrorPlacePieces(force)
    local W, H = mModel:GetWidth(), mModel:GetHeight()
    local size = SealCutoutSize(mModel)
    local key = table.concat({ ModelItem(), W, H, MirrorVal("mCoverX"), MirrorVal("mCoverY"), size,
        db.holeShape or "cuadrado", IsHoriz() and 1 or 0 }, ":")
    if not force and key == mPiecesKey then return end
    mPiecesKey = key
    local x, y = MirrorVal("mCoverX"), MirrorVal("mCoverY")   -- hueco propio de la copia
    if IsHoriz() then x, y = -y, x end
    local rects = ModelHoleRects(W, H, x, y, size)
    for i, p in ipairs(mPieces) do
        local rx, ry, rw, rh = unpack(rects[i])
        p.clip:ClearAllPoints()
        p.clip:SetPoint("TOPLEFT", mModel, "TOPLEFT", rx, -ry)
        p.clip:SetSize(math.max(rw, 0.01), math.max(rh, 0.01))
    end
end

local function MirrorShowPieces(show)
    for _, p in ipairs(mPieces) do if p.clip:IsShown() ~= show then p.clip:SetShown(show) end end
end

local function MirrorPosition()
    local fx, fy = f:GetCenter()
    if not fx then return end
    local fe, me, ue = f:GetEffectiveScale(), M:GetEffectiveScale(), UIParent:GetEffectiveScale()
    local cx = UIParent:GetWidth() * ue / 2
    local mx = 2 * cx - fx * fe
    M:ClearAllPoints()
    M:SetPoint("CENTER", UIParent, "BOTTOMLEFT", mx / me, fy * fe / me)
end

local function MirrorApplyStyle()
    local horiz = IsHoriz()
    M:SetScale(db.scale or 1)
    M:SetAlpha(db.alpha or 0.25)
    M:SetSize(horiz and 256 or 128, horiz and 128 or 256)
    for _, t in ipairs({ mMoonBg, mMoonFrame, mFill[1], mFill[2], mFill[3] }) do MirrorCrop(t, 0, 1) end
    local isLuna = db.style == "luna"
    local isModel = db.style == "modelo" and ModelItem() ~= nil and not ActiveWeaponArt()
    mWeaponArt:Hide()
    mMoonBg:SetShown(isLuna); mMoonFrame:SetShown(isLuna)
    if not isLuna then for i = 1, 3 do mFill[i]:Hide() end end
    mModel:ClearAllPoints()
    mModel:SetSize(horiz and 270 or 150, horiz and 150 or 270)
    mModel:SetPoint("CENTER", M, "CENTER", 0, 0)
    mModel:SetShown(isModel)
    if isModel and SealCutoutEnabled() then MirrorPlacePieces(true) else MirrorShowPieces(false) end
    mMarker:Hide()
    mKey = nil
    ConfigureAura(mFlame, M, true)
end

local function MirrorShow(kind, count)
    if not db.mirror or not count or count < 1 then
        M:Hide()
        return
    end
    count = math.min(count or 0, 3)
    local c = (db.colors and db.colors[kind]) or SEALS[kind].color
    if db.style == "espada" or (db.style == "modelo" and ActiveWeaponArt()) then
        mWeaponArt:Draw(count, c)
    elseif db.style == "modelo" then
        mLevel, mCol = count, c
        local key = kind .. ":" .. count
        if mKey ~= key then
            mKey = key
            SetupModel(mModel, count, c, true)
            if SealCutoutEnabled() then
                for _, p in ipairs(mPieces) do SetupModel(p.m, count, c, true) end
            end
        end
        if mModel.SetModelAlpha then pcall(mModel.SetModelAlpha, mModel, db.alpha or 0.25) end
        local hole = SealCutoutEnabled() and count < 3
        if hole then MirrorPlacePieces() end
        local showMarker = f.unlocked == true and SealCutoutEnabled()
        if showMarker then
            local mx, my = MirrorVal("mCoverX"), MirrorVal("mCoverY")
            if IsHoriz() then mx, my = -my, mx end
            mMarker:ClearAllPoints()
            mMarker:SetPoint("CENTER", M, "CENTER", mx, my)
            local size = SealCutoutSize(mModel)
            mMarker:SetSize(size, size)
        end
        mMarker:SetShown(showMarker)
        if hole then
            if mModel:IsShown() then mModel:Hide() end
            MirrorShowPieces(true)
        else
            mModel:SetShown(ModelItem() ~= nil)
            MirrorShowPieces(false)
        end
    else
        local rev = db.fillDir == "abajo" or db.fillDir == "izquierda"
        for i = 1, 3 do
            local seg = rev and (4 - i) or i
            mFill[seg]:SetVertexColor(c[1], c[2], c[3])
            mFill[seg]:SetShown(i <= count)
        end
    end
    ColorAura(mFlame, c)
    mFlame:SetShown(count >= 3 and mFlame.auraEnabled)
    MirrorPosition()
    M:Show()
end

local mFlameT, mPosT = 0, 0
M:SetScript("OnUpdate", function(self, elapsed)
    if mFlame:IsShown() then
        mFlameT = mFlameT + elapsed
        local fr = math.floor(mFlameT * FLAME_FPS) % FLAME_FRAMES
        SetAuraFrame(mFlame, fr, true)
    end
    mPosT = mPosT + elapsed
    if mPosT > 0.1 then mPosT = 0; MirrorPosition() end      -- sigue a la principal si la mueves
end)

-- enganchar la copia a las funciones de la principal
do
    local _apply, _show, _hide, _pos = ApplyStyle, ShowMoon, HideMoon, ApplyPosition
    ApplyStyle = function(...)
        _apply(...)
        MirrorApplyStyle()
        modelClip.lastColor = nil
    end
    ShowMoon = function(kind, tex, count, exp) _show(kind, tex, count, exp); MirrorShow(kind, count) end
    HideMoon = function(...) _hide(...); if not f:IsShown() then M:Hide() end end
    ApplyPosition = function(...) _pos(...); M:SetScale(db.scale or 1); M:SetAlpha(db.alpha or 0.25); MirrorPosition() end
end

local UWSetSeal, UWSync   -- se definen más abajo
local RegisterSettingsPanel
local Print, ApplyViewer, UpdateAppearance, opt

-- Registro de diagnóstico (se guarda en PallyWrathDB.log al hacer /reload o salir)
local logSeen = {}
Log = function(msg)
    if not db then return end
    if issecretvalue and issecretvalue(msg) then msg = "(mensaje secreto)" end
    db.log = db.log or {}
    if logSeen[msg] then return end
    logSeen[msg] = true
    table.insert(db.log, date("%H:%M:%S") .. (InCombatLockdown and InCombatLockdown() and " [combate] " or " ") .. msg)
    while #db.log > 250 do table.remove(db.log, 1) end
end

-- IDs de los ecos ya conocidos (vistos en tu cliente de Forever)
local KNOWN_ECHO = { [1311703] = "command", [1311704] = "righteousness", [1328198] = "light",
                     [1311701] = "fury", [1311705] = "justice", [1328206] = "wisdom" }
local ECHO_DUR = 15

local function IsSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local equipmentReadPending
local function RefreshEquipment()
    local ok, id = pcall(GetInventoryItemID, "player", MAIN_HAND)
    if not ok or IsSecret(id) then equipmentReadPending = true; return false end
    equipmentReadPending = false
    if equippedItem == id then return false end
    equippedItem = id
    return true
end

local function EchoKindById(id)
    if id == nil or IsSecret(id) then return nil end
    return KNOWN_ECHO[id] or (db and db.spellIds[id])
end

-- Fuente 3: registro de combate (por si en combate no se pueden leer los buffs)
local cle = {}   -- cle[kind] = { cargas, expira }
local playerGUID
local function OnCombatLog()
    local ok, err = pcall(function()
        local _, sub, _, _, _, _, _, destGUID, _, _, _, spellId, spellName, _, _, amount = CombatLogGetCurrentEventInfo()
        playerGUID = playerGUID or UnitGUID("player")
        if destGUID ~= playerGUID then return end
        local kind = EchoKindById(spellId) or ClassifyByName(spellName)
        if not kind then return end
        local now = GetTime()
        if sub == "SPELL_AURA_APPLIED" then
            cle[kind] = { 1, now + ECHO_DUR }
        elseif sub == "SPELL_AURA_APPLIED_DOSE" then
            cle[kind] = { amount or ((cle[kind] and cle[kind][1] or 0) + 1), now + ECHO_DUR }
        elseif sub == "SPELL_AURA_REFRESH" then
            if cle[kind] then cle[kind][2] = now + ECHO_DUR else cle[kind] = { 1, now + ECHO_DUR } end
        elseif sub == "SPELL_AURA_REMOVED_DOSE" then
            cle[kind] = { amount or math.max((cle[kind] and cle[kind][1] or 1) - 1, 1), (cle[kind] and cle[kind][2]) or now + ECHO_DUR }
        elseif sub == "SPELL_AURA_REMOVED" then
            cle[kind] = nil
        end
        Log("registro de combate OK: " .. tostring(sub) .. " " .. tostring(spellName))
    end)
    if not ok then Log("ERROR registro de combate: " .. tostring(err)) end
end

-- Diagnóstico: ¿aparece el eco en el visor de reutilizaciones de Blizzard?
local function SafeName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and n and not IsSecret(n) then return n end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok and n and not IsSecret(n) then return n end
    end
    return "?"
end

local function DiagCatalog()
    if not C_CooldownViewer then Log("visor: no existe C_CooldownViewer") return end
    local total = 0
    for cat = 0, 8 do
        local ok, set = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, cat, true)
        if ok and type(set) == "table" then
            for _, cid in ipairs(set) do
                local ok2, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cid)
                if ok2 and type(info) == "table" then
                    local ids = { info.spellID, info.overrideSpellID }
                    if type(info.linkedSpellIDs) == "table" then
                        for _, x in ipairs(info.linkedSpellIDs) do ids[#ids + 1] = x end
                    end
                    local parts = {}
                    for _, id in ipairs(ids) do
                        if id and not IsSecret(id) and id ~= 0 then
                            parts[#parts + 1] = id .. ":" .. SafeName(id)
                        end
                    end
                    total = total + 1
                    Log(string.format("visor cat=%d cid=%s aura=%s %s", cat, tostring(cid),
                        tostring(info.hasAura), table.concat(parts, ", ")))
                end
            end
        elseif not ok then
            Log("visor ERROR cat " .. cat .. ": " .. tostring(set))
        end
    end
    Log("visor: " .. total .. " entradas en el catálogo")
end

-- Describe un valor sin tocarlo si es secreto
D = function(v)
    if IsSecret(v) then return "SECRETO(" .. type(v) .. ")" end
    if v == nil then return "nil" end
    return type(v) .. ":" .. tostring(v)
end

local UW_CID = 200341   -- entrada "Unsealed Wrath" del visor de Blizzard
local probeBar = CreateFrame("StatusBar", nil, UIParent)
probeBar:SetSize(1, 1)
probeBar:SetMinMaxValues(0, 3)
probeBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
probeBar:SetAlpha(0)

local function FindAppsFS(it)
    local cands = {
        { "Applications.Applications", it.Applications and it.Applications.Applications },
        { "Applications", it.Applications },
        { "Icon.Applications", it.Icon and it.Icon.Applications },
        { "Count", it.Count },
    }
    for _, c in ipairs(cands) do
        local o = c[2]
        if type(o) == "table" and o.GetText then return c[1], o end
    end
end

local function ProbeItem(vname, i, it)
    local cid = it.cooldownID
    if cid == nil and it.GetCooldownID then cid = select(2, pcall(it.GetCooldownID, it)) end
    local isUW = (not IsSecret(cid)) and cid == UW_CID
    Log(string.format("%s icono %d: cid=%s%s", vname, i, D(cid), isUW and " <- UNSEALED WRATH" or ""))
    if not isUW then return end
    -- campos del icono
    local keys = {}
    for k, v in pairs(it) do
        if type(k) == "string" and #keys < 40 then keys[#keys + 1] = k .. "=" .. (IsSecret(v) and "S" or type(v):sub(1, 3)) end
    end
    table.sort(keys)
    Log("  campos: " .. table.concat(keys, " "))
    Log("  auraInstanceID=" .. D(it.auraInstanceID) .. " spellID=" .. D(it.spellID) .. " auraSpellID=" .. D(it.auraSpellID))
    if it.IsActive then Log("  IsActive=" .. D(select(2, pcall(it.IsActive, it)))) end
    -- texto de cargas
    local path, fs = FindAppsFS(it)
    if fs then
        local txt = select(2, pcall(fs.GetText, fs))
        Log("  cargas (" .. path .. ") texto=" .. D(txt) .. " visible=" .. D(select(2, pcall(fs.IsShown, fs))))
        local okN, n = pcall(tonumber, txt)
        Log("  tonumber: ok=" .. tostring(okN) .. " -> " .. D(n))
        local okB, errB = pcall(probeBar.SetValue, probeBar, n)
        Log("  StatusBar:SetValue(cargas): ok=" .. tostring(okB) .. (okB and "" or (" " .. D(errB))))
        if okB then Log("  StatusBar:GetValue -> " .. D(select(2, pcall(probeBar.GetValue, probeBar)))) end
        local okT, errT = pcall(probeBar.SetValue, probeBar, txt)
        Log("  StatusBar:SetValue(texto): ok=" .. tostring(okT) .. (okT and "" or (" " .. D(errT))))
    else
        Log("  no encuentro el texto de cargas")
    end
    -- APIs con el aura
    local inst = it.auraInstanceID
    if inst ~= nil and C_UnitAuras then
        if C_UnitAuras.GetAuraApplicationDisplayCount then
            local ok, r = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "player", inst)
            Log("  GetAuraApplicationDisplayCount: ok=" .. tostring(ok) .. " -> " .. D(r))
        end
        if C_UnitAuras.GetAuraDataByAuraInstanceID then
            local ok, r = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", inst)
            Log("  GetAuraDataByAuraInstanceID: ok=" .. tostring(ok) .. " -> " .. D(r) .. ((ok and type(r) == "table" and not IsSecret(r)) and (" cargas=" .. D(r.applications) .. " id=" .. D(r.spellId)) or ""))
        end
        if C_UnitAuras.GetAuraDuration then
            local ok, r = pcall(C_UnitAuras.GetAuraDuration, "player", inst)
            Log("  GetAuraDuration: ok=" .. tostring(ok) .. " -> " .. D(r))
        end
    end
    if C_CurveUtil and C_CurveUtil.CreateCurve then Log("  existe C_CurveUtil.CreateCurve") end
end

local function DiagViewerFrames()
    for _, vname in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
        local v = _G[vname]
        if v then
            local ok, err = pcall(function()
                local frames = (v.GetItemFrames and v:GetItemFrames()) or { v:GetChildren() }
                for i, it in ipairs(frames) do
                    if i > 10 then break end
                    local ok2, err2 = pcall(ProbeItem, vname, i, it)
                    if not ok2 then Log("  ERROR sonda " .. vname .. " " .. i .. ": " .. D(err2)) end
                end
            end)
            if not ok then Log("visor ERROR " .. vname .. ": " .. D(err)) end
        end
    end
end

local function Consider(best, kind, tex, count, exp, source)
    if not kind then return best end
    local c = math.max(count or 0, 1)
    if not best or c > best[3] then return { kind, tex, c, exp, source } end
    return best
end

------------------------------------------------------------
-- Seguimiento en combate a través del icono de Blizzard (Unsealed Wrath)
-- En combate el juego oculta las cargas, pero deja saber si el icono está
-- activo y cuándo se actualiza: contamos las actualizaciones (máx. 3).
------------------------------------------------------------
local uw = { count = 0, exp = 0, lastT = 0, kind = nil, seal = nil, reset = false }
local hookedItems = setmetatable({}, { __mode = "k" })
local hookLogN = 0

UWSetSeal = function(kind)
    if kind and kind ~= uw.seal then
        uw.seal = kind
        uw.reset = true          -- el siguiente golpe empieza un eco nuevo
    end
end

UWSync = function(best)       -- datos exactos (fuera de combate)
    if db and db.debug then
        local real = best and (tostring(best[1]) .. " x" .. tostring(best[3])) or "ninguno"
        if real ~= uw.lastReal then
            uw.lastReal = real
            Log(string.format("fuera de combate: eco real %s (yo contaba %d) t=%.2f", real, uw.count or -1, GetTime() % 1000))
        end
    end
    if best then
        uw.count, uw.kind, uw.exp = best[3], best[1], best[4] or 0
        -- si el eco que queda es de otro sello (has cambiado de sello),
        -- el siguiente eco que aparezca en combate empieza de cero
        uw.reset = (uw.seal ~= nil and best[1] ~= uw.seal)
    else
        uw.count = 0
        uw.reset = false
    end
end

local function ItemActive(item)
    if not item or not item.IsActive then return nil end
    local ok, act = pcall(item.IsActive, item)
    if ok and not IsSecret(act) then return act == true end
end

local function OnUWUpdate(item, tag)
    if not db or not (InCombatLockdown and InCombatLockdown()) then return end
    local now = GetTime()
    local act = ItemActive(item)
    if db.debug and hookLogN < 400 then
        hookLogN = hookLogN + 1
        local shown, w
        pcall(function()
            local _, fs = FindAppsFS(item)
            if fs then
                shown = D(select(2, pcall(fs.IsShown, fs)))
                w = D(select(2, pcall(fs.GetStringWidth, fs)))
            end
        end)
        Log(string.format("gancho %s t=%.2f activo=%s cuenta=%d sello=%s numVisible=%s ancho=%s",
            tag, now % 1000, tostring(act), uw.count or -1, tostring(uw.seal), tostring(shown), tostring(w)))
    end
    if tag == db.countHook and act ~= true then
        -- el eco acaba de aparecer: Blizzard actualiza las cargas antes de
        -- marcar el icono como activo; lo contamos al activarse (mismo instante)
        uw.pendT = now
        return
    end
    if tag ~= db.countHook then
        if not (act == true and uw.pendT and now - uw.pendT < 0.1) then return end
        uw.pendT = nil
        if db.debug then Log(string.format("  (carga al activarse el icono, %s)", tag)) end
    end
    if act ~= true then return end
    if now - uw.lastT < 0.35 then return end   -- varias llamadas del mismo golpe
    uw.lastT = now
    if uw.reset or uw.count <= 0 then
        uw.count = 1
        uw.kind = uw.seal or uw.kind
        uw.reset = false
    else
        uw.count = math.min(uw.count + 1, 3)
    end
    uw.exp = now + ECHO_DUR
    if db.debug then Log(string.format("  -> cuenta %d (%s) t=%.2f", uw.count, tostring(uw.kind), now % 1000)) end
end

local function HookUWItem(item)
    if hookedItems[item] then return end
    hookedItems[item] = true
    for _, m in ipairs({ "RefreshApplications", "OnActiveStateChanged", "RefreshActive" }) do
        if type(item[m]) == "function" then
            hooksecurefunc(item, m, function(self)
                if not IsSecret(self.cooldownID) and self.cooldownID == UW_CID then OnUWUpdate(self, m) end
            end)
        end
    end
    local cd = item.Cooldown
    if type(cd) == "table" then
        for _, m in ipairs({ "SetCooldown", "SetCooldownFromDurationObject", "SetCooldownDuration" }) do
            if type(cd[m]) == "function" then
                hooksecurefunc(cd, m, function()
                    if not IsSecret(item.cooldownID) and item.cooldownID == UW_CID then OnUWUpdate(item, "Cooldown." .. m) end
                end)
            end
        end
    end
end

local function FindUWItem()
    for _, vname in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
        local v = _G[vname]
        if v then
            local ok, frames = pcall(function() return (v.GetItemFrames and v:GetItemFrames()) or { v:GetChildren() } end)
            if ok and type(frames) == "table" then
                for _, it in ipairs(frames) do
                    if type(it) == "table" then
                        pcall(HookUWItem, it)
                        local cid = it.cooldownID
                        if not IsSecret(cid) and cid == UW_CID then return it end
                    end
                end
            end
        end
    end
end

local function CombatScan()
    local item = FindUWItem()
    if not item then
        Log("combate: no encuentro el icono de Unsealed Wrath en el visor de Blizzard")
        if not uw.warned and Print then
            uw.warned = true
            Print("En combate no encuentro el icono de Unsealed Wrath. Abre el Cooldown Manager > Beneficios rastreados y añade Unsealed Wrath.")
        end
        HideMoon()
        return
    end
    local act = ItemActive(item)
    if act == true then
        if uw.count <= 0 then
            uw.count, uw.exp = 1, GetTime() + ECHO_DUR
            uw.kind = uw.seal or uw.kind
            uw.reset = false     -- este eco ya es el nuevo: el siguiente golpe suma
        end
        if uw.count >= db.minStacks then
            ShowMoon(uw.kind or uw.seal or "command", nil, uw.count, uw.exp)
        else
            HideMoon()
        end
    else
        uw.count = 0
        HideMoon()
    end
end

local function ScanInner()
    local best

    -- Fuente 1: recorrer los buffs (funciona fuera de combate)
    ForEachBuff(function(name, tex, count, spellId, exp, dur)
        local ok, err = pcall(function()
            if IsSecret(name) or IsSecret(spellId) or IsSecret(count) then
                Log("buffs ocultos en combate (valores secretos)")
                return
            end
            local seal = ClassifySeal(name)
            if seal and tex and not IsSecret(tex) then db.sealIcons[seal] = tex end
            if seal then UWSetSeal(seal) end
            local kind = EchoKindById(spellId) or ClassifyByName(name)
            if kind then
                if spellId and not db.spellIds[spellId] then db.spellIds[spellId] = kind end
                if dur and dur > 0 then ECHO_DUR = dur end
                best = Consider(best, kind, tex, count, exp, "buffs")
            end
        end)
        if not ok then Log("ERROR leyendo buff: " .. tostring(err)) end
    end)

    -- Fuente 2: pedir el eco directamente por su ID
    if not best and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ids = {}
        for id in pairs(KNOWN_ECHO) do ids[id] = true end
        for id in pairs(db.spellIds) do ids[id] = true end
        for id in pairs(ids) do
            local ok, err = pcall(function()
                local a = C_UnitAuras.GetPlayerAuraBySpellID(id)
                if a then
                    if IsSecret(a.applications) then
                        Log("por ID: eco visible pero cargas secretas")
                        best = Consider(best, EchoKindById(id), nil, 1, nil, "porID")
                    else
                        best = Consider(best, EchoKindById(id), nil, a.applications,
                            (not IsSecret(a.expirationTime)) and a.expirationTime or nil, "porID")
                    end
                end
            end)
            if not ok then Log("ERROR por ID: " .. tostring(err)) end
        end
    end

    -- Fuente 3: lo que hayamos contado con el registro de combate
    if not best then
        local now = GetTime()
        for kind, st in pairs(cle) do
            if st[2] > now then
                best = Consider(best, kind, nil, st[1], st[2], "registro")
            else
                cle[kind] = nil
            end
        end
    end

    if best then Log("detectado por: " .. best[5]) end
    UWSync(best)
    if best and best[3] >= db.minStacks then
        ShowMoon(best[1], best[2], best[3], best[4])
    else
        HideMoon()
    end
end

local function Scan()
    if not db or testMode or f.unlocked then return end
    if InCombatLockdown and InCombatLockdown() then
        local okC, errC = pcall(CombatScan)
        if not okC then Log("ERROR en combate: " .. D(errC)) end
        return
    end
    pcall(FindUWItem)   -- engancha el icono de Blizzard antes de entrar en combate
    local ok, err = pcall(ScanInner)
    if not ok then Log("ERROR en Scan: " .. tostring(err)) end
end

local diagDone, diagCombatT = false, 0
local diagFrame = CreateFrame("Frame")
diagFrame:SetScript("OnUpdate", function(_, elapsed)
    if not db then return end
    if not diagDone and not (InCombatLockdown and InCombatLockdown()) then
        diagDone = true  -- el catálogo ya está estudiado (Unsealed Wrath = 200341)
    end
    do
        diagCombatT = diagCombatT + elapsed
        if diagCombatT > 2 then
            diagCombatT = 0
            -- sonda del visor desactivada (ya estudiado)
        end
    end
end)

-- Plan B: además del evento UNIT_AURA, revisamos los buffs 5 veces por segundo
local poll = CreateFrame("Frame")
local pollT = 0
poll:SetScript("OnUpdate", function(_, elapsed)
    pollT = pollT + elapsed
    if pollT < 0.2 then return end
    pollT = 0
    Scan()
end)

f:SetScript("OnUpdate", function(self, elapsed)
    if flame:IsShown() then
        flameTime = flameTime + elapsed
        local fr = math.floor(flameTime * FLAME_FPS) % FLAME_FRAMES
        SetAuraFrame(flame, fr, false)
    end
    self.t = (self.t or 0) + elapsed
    if self.t < 0.1 then return end
    self.t = 0
    if not timer:IsShown() then return end
    local left = (expiresAt or 0) - GetTime()
    if left > 0 then
        timer:SetText(string.format("%.1f", left))
        if left < 3 then timer:SetTextColor(1, 0.25, 0.25) else timer:SetTextColor(1, 1, 1) end
    else
        timer:SetText("")
    end
end)

------------------------------------------------------------
-- Eventos
------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:RegisterUnitEvent("UNIT_AURA", "player")
ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

local welcomed = false
local function Welcome()
    if welcomed then return end
    welcomed = true
    local ver
    if C_AddOns and C_AddOns.GetAddOnMetadata then ver = C_AddOns.GetAddOnMetadata(ADDON, "Version")
    elseif GetAddOnMetadata then ver = GetAddOnMetadata(ADDON, "Version") end
    DEFAULT_CHAT_FRAME:AddMessage("|cffF58CBAPally Wrath|r |cffffd100v" .. tostring(ver or "?") ..
        TR("|r cargado, por |cff00ccffApocSteel|r. |cffffd100/pw|r abre las opciones - |cffffd100/pw ayuda|r"))
end

local function RedrawEquipment()
    if db.style == "modelo" and db.useEquipped then UpdateAppearance() end
    if opt then opt:Refresh() end
end

ev:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        PallyWrathDB = PallyWrathDB or {}
        db = PallyWrathDB
        CopyDefaults(DEFAULTS, db)
        RefreshEquipment()
        db.log = {}   -- registro nuevo en cada carga
        pcall(RegisterSettingsPanel)
        ApplyStyle()
        ApplyPosition()
        local _, class = UnitClass("player")
        if class ~= "PALADIN" then
            self:UnregisterEvent("UNIT_AURA")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Welcome()
        if db then
            if RefreshEquipment() then RedrawEquipment() end
            Scan()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        local refresh = event == "PLAYER_EQUIPMENT_CHANGED" and arg1 == MAIN_HAND
            or event == "PLAYER_REGEN_ENABLED" and equipmentReadPending
        if db and refresh and RefreshEquipment() then RedrawEquipment() end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if db and equippedItem and not IsSecret(arg1) and arg1 == equippedItem and ... == true then RedrawEquipment() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not db then return end
        local spellID = select(2, ...)   -- unit, castGUID, spellID
        pcall(function()
            if spellID == nil or IsSecret(spellID) then return end
            local kind = ClassifySeal(SafeName(spellID))
            if kind then
                UWSetSeal(kind)
                local tex = SpellIcon(spellID)
                if tex and not IsSecret(tex) then db.sealIcons[kind] = tex end
                Log("sello lanzado: " .. kind .. " id=" .. D(spellID) .. " nombre=" .. D(SafeName(spellID)))
            end
        end)
    elseif db then
        Scan()
    end
end)

------------------------------------------------------------
-- Menú de opciones (/pw)
------------------------------------------------------------
-- cada prueba lleva su número: los temporizadores de una prueba anterior se ignoran
local testId = 0
local function TestTimer(delay, fn)
    local myId = testId
    C_Timer.After(delay, function() if myId == testId then fn() end end)
end
local function EndTest() testMode = false; HideMoon(); Scan() end

local function RunTest(kind)
    kind = kind or "command"
    testId = testId + 1
    testMode = true
    shownStacks = 0
    ShowMoon(kind, nil, 1, 0)
    TestTimer(1.2, function() ShowMoon(kind, nil, 2, 0) end)
    TestTimer(2.4, function() ShowMoon(kind, nil, 3, GetTime() + 15) end)
    TestTimer(7.0, EndTest)
end

local function SetLocked(locked)
    if locked then
        f.unlocked = false
        f:EnableMouse(false)
        iconHolder:EnableMouse(false)
        cover:EnableMouse(false)
        HideMoon()
        Scan()
    else
        f.unlocked = true
        f:EnableMouse(true)
        iconHolder:EnableMouse(true)
        cover:EnableMouse(true)
        ShowMoon("command", nil, db.style == "modelo" and 1 or 3, GetTime() + 15)
    end
end

local SEAL_ORDER = { "command", "righteousness", "wisdom", "light", "justice", "fury" }
local SEAL_LABEL = { command = "Orden", righteousness = "Rectitud", wisdom = "Sabiduría",
                     light = "Luz", justice = "Justicia", fury = "Furia" }

local function SealColor(kind) return (db.colors and db.colors[kind]) or SEALS[kind].color end

local function OpenColorPicker(kind, changed)
    local c = SealColor(kind)
    local old = db.colors[kind]
    local function onChange()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        db.colors[kind] = { r, g, b }
        changed()
    end
    local function onCancel()
        db.colors[kind] = old
        changed()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({ r = c[1], g = c[2], b = c[3], hasOpacity = false,
            swatchFunc = onChange, cancelFunc = onCancel })
    else
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc = onChange, onCancel
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
        ColorPickerFrame:Hide(); ColorPickerFrame:Show()
    end
end

UpdateAppearance = function()
    ApplyStyle()
    ApplyPosition()
    if f:IsShown() and shownSeal then
        ShowMoon(shownSeal, nil, shownStacks, expiresAt)
    end
end

local function PreviewTexture(parent, asset, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer, nil, sublevel)
    texture:SetTexture(MEDIA .. asset)
    return texture
end

local function BuildPreview(parent, mirrored)
    local view = CreateFrame("Frame", nil, parent)
    local art = CreateFrame("Frame", nil, view)
    art:SetAllPoints()
    art:SetFrameLevel(view:GetFrameLevel() + 3)

    local flame = art:CreateTexture(nil, "BORDER")
    flame:SetPoint("CENTER")
    flame:SetBlendMode("ADD")
    local moonBg = PreviewTexture(art, "moon_bg", "BACKGROUND")
    local moonFrame = PreviewTexture(art, "moon_frame", "OVERLAY")
    local moonFill = {}
    for i = 1, 3 do moonFill[i] = PreviewTexture(art, "moon" .. i, "ARTWORK") end

    local seal = art:CreateTexture(nil, "OVERLAY", nil, 1)
    seal:SetSize(30, 30)
    seal:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local ring = PreviewTexture(art, "ash_frame", "OVERLAY", 2)
    ring:SetSize(42, 42)
    ring:SetPoint("CENTER", seal, "CENTER")
    local timer = art:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
    local weaponLayers = BuildWeaponArt(view, art, mirrored)

    local model, clips
    local function DrawModel(count, color, alpha, horizontal)
        if not model then
            model = CreateFrame("PlayerModel", nil, view)
            model:SetPoint("CENTER")
            clips = {}
        end
        local width, height = horizontal and 270 or 150, horizontal and 150 or 270
        model:SetSize(width, height)
        local hole = SealCutoutEnabled() and count < 3
        model:SetShown(not hole)
        if not hole then
            SetupModel(model, count, color, mirrored, alpha)
            for _, clip in ipairs(clips) do clip:Hide() end
            return
        end
        local x = mirrored and MirrorVal("mCoverX") or db.coverX
        local y = mirrored and MirrorVal("mCoverY") or db.coverY
        if horizontal then x, y = -y, x end
        for i, rect in ipairs(ModelHoleRects(width, height, x, y, SealCutoutSize(model))) do
            local clip = clips[i]
            if not clip then
                clip = CreateFrame("Frame", nil, view)
                if clip.SetClipsChildren then clip:SetClipsChildren(true) end
                clip.weapon = CreateFrame("PlayerModel", nil, clip)
                clip.weapon:SetAllPoints(model)
                clips[i] = clip
            end
            clip:ClearAllPoints()
            clip:SetPoint("TOPLEFT", model, "TOPLEFT", rect[1], -rect[2])
            clip:SetSize(math.max(rect[3], 0.01), math.max(rect[4], 0.01))
            clip:Show()
            SetupModel(clip.weapon, count, color, mirrored, alpha)
        end
    end

    local elapsed, full = 0, false
    view:SetScript("OnUpdate", function(_, delta)
        if not flame:IsShown() then return end
        elapsed = (elapsed + delta) % (FLAME_FRAMES / FLAME_FPS)
        local fr = math.floor(elapsed * FLAME_FPS)
        SetAuraFrame(flame, fr, mirrored)
    end)

    function view:Draw(kind, count)
        local style = STYLES[db.style]
        local color, horizontal = SealColor(kind), IsHoriz()
        local alpha = db.alpha or DEFAULTS.alpha
        self:SetSize(horizontal and 256 or 128, horizontal and 128 or 256)
        art:SetAlpha(alpha)
        local isMoon = db.style == "luna"
        moonBg:SetShown(isMoon)
        moonFrame:SetShown(isMoon)
        if isMoon then
            CropTexture(self, moonBg, 0, 1, mirrored)
            CropTexture(self, moonFrame, 0, 1, mirrored)
        end
        local reverse = db.fillDir == "abajo" or db.fillDir == "izquierda"
        for i, segment in ipairs(moonFill) do
            local active = isMoon and (reverse and 4 - i or i) <= count
            segment:SetShown(active)
            if active then
                CropTexture(self, segment, 0, 1, mirrored)
                segment:SetVertexColor(color[1], color[2], color[3])
            end
        end
        local isWeapon = db.style == "modelo"
        local useArt = db.style == "espada" or (isWeapon and ActiveWeaponArt())
        if useArt then weaponLayers:Draw(count, color) else weaponLayers:Hide() end
        if isWeapon and ModelItem() and not useArt then
            DrawModel(count, color, alpha, horizontal)
        elseif model then
            model:Hide()
            for _, clip in ipairs(clips) do clip:Hide() end
        end

        full = count == 3
        ConfigureAura(flame, self, mirrored)
        flame:SetShown(full and flame.auraEnabled)
        ColorAura(flame, color)
        local showIcon = not mirrored and db.showIcon ~= false
        seal:SetShown(showIcon)
        ring:SetShown(showIcon)
        timer:SetShown(full and not mirrored)
        if not mirrored then
            seal:ClearAllPoints()
            timer:ClearAllPoints()
            if db.iconOffset then
                seal:SetPoint("CENTER", self, "CENTER", db.iconOffset[1], db.iconOffset[2])
            elseif horizontal then
                seal:SetPoint("CENTER", self, "LEFT", -22, 0)
            else
                seal:SetPoint("CENTER", self, "TOPLEFT", style.iconX, -128)
            end
            if horizontal then
                timer:SetPoint("LEFT", self, "RIGHT", 10, 0)
            else
                timer:SetPoint("LEFT", self, "TOPLEFT", style.timerX, -128)
            end
            seal:SetTexture(SealIcon(kind))
            timer:SetText("15")
        end
    end

    return view
end


local function BuildOptions()
    local function L(es, en) return IS_ES and es or en end
    local function Plate(parent, layer, r, g, b, a)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetAllPoints()
        texture:SetColorTexture(r, g, b, a)
        return texture
    end

    opt = CreateFrame("Frame", "PallyWrathOptions", UIParent)
    opt:Hide()
    opt:SetSize(820, 530)
    opt:SetPoint("CENTER")
    opt:SetFrameStrata("DIALOG")
    opt:SetClampedToScreen(true)
    opt:SetMovable(true)
    opt:EnableMouse(true)
    tinsert(UISpecialFrames, "PallyWrathOptions")
    Plate(opt, "BACKGROUND", 0.068, 0.056, 0.076, 1)

    local function Text(parent, text, font, x, y, width)
        local label = parent:CreateFontString(nil, "OVERLAY", font)
        label:SetPoint("TOPLEFT", x, y)
        if width then label:SetWidth(width) end
        label:SetJustifyH("LEFT")
        label:SetText(text)
        return label
    end

    local function Button(parent, text, x, y, width, height, click)
        local button = CreateFrame("Button", nil, parent)
        button:SetPoint("TOPLEFT", x, y)
        button:SetSize(width, height)
        button.bg = Plate(button, "BACKGROUND", 0.16, 0.12, 0.16, 1)
        Plate(button, "HIGHLIGHT", 1, 0.74, 0.40, 0.13)
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("CENTER")
        label:SetText(text)
        button.label = label
        button:SetScript("OnClick", click)
        return button
    end

    local function Selected(button, active)
        if active then
            button.bg:SetColorTexture(0.34, 0.19, 0.22, 1)
            button.label:SetTextColor(1, 0.83, 0.53)
        else
            button.bg:SetColorTexture(0.16, 0.12, 0.16, 1)
            button.label:SetTextColor(0.91, 0.87, 0.90)
        end
    end

    local titleBar = CreateFrame("Frame", nil, opt)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(63)
    Plate(titleBar, "BACKGROUND", 0.13, 0.09, 0.13, 1)
    local titleIcon = PreviewTexture(titleBar, "icon", "ARTWORK")
    titleIcon:SetSize(32, 32)
    titleIcon:SetPoint("TOPLEFT", 18, -15)
    local title = Text(titleBar, "Pally Wrath", "GameFontNormalLarge", 62, -14)
    title:SetTextColor(1, 0.83, 0.62)
    Text(titleBar, "Unsealed Wrath", "GameFontHighlightSmall", 63, -37)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() opt:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() opt:StopMovingOrSizing() end)
    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -10, -12)
    close:SetScript("OnClick", function() opt:Hide() end)

    local slots = {}
    local function RefreshWith(fn) slots[#slots + 1] = fn end
    local function ChangeAppearance()
        UpdateAppearance()
        opt:Refresh()
    end

    local tabs, pages, selectedTab = {}, {}, 1
    for i, name in ipairs({ L("Apariencia", "Appearance"), L("Posición", "Position"),
                            L("Alertas", "Alerts"), L("Avanzado", "Advanced") }) do
        tabs[i] = Button(opt, name, 18 + (i - 1) * 122, -76, 116, 28, function()
            selectedTab = i
            opt:Refresh()
        end)
        local page = CreateFrame("Frame", nil, opt)
        page:SetPoint("TOPLEFT", 18, -116)
        page:SetSize(482, 396)
        Plate(page, "BACKGROUND", 0.10, 0.084, 0.106, 1)
        pages[i] = page
    end

    local function Header(parent, name, y)
        return Text(parent, name, "GameFontNormal", 16, y)
    end

    local function Check(parent, label, y, get, set)
        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 14, y)
        check:SetSize(26, 26)
        Text(check, label, "GameFontHighlight", 29, -7, 410)
        check:SetScript("OnClick", function(self)
            set(not not self:GetChecked())
            opt:Refresh()
        end)
        RefreshWith(function() check:SetChecked(get()) end)
        return check
    end

    local function Slider(parent, label, x, y, width, min, max, step, fmt, get, set)
        Text(parent, label, "GameFontHighlight", x, y)
        local value = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)
        local slider = CreateFrame("Slider", nil, parent)
        slider:SetPoint("TOPLEFT", x + 26, y - 17)
        slider:SetSize(width - 52, 18)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
        local track = slider:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
        track:SetHeight(5)
        track:SetColorTexture(0.39, 0.28, 0.34, 1)
        local thumb = slider:CreateTexture(nil, "ARTWORK")
        thumb:SetSize(24, 24)
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        slider:SetThumbTexture(thumb)
        local updating
        local function adjust(delta)
            slider:SetValue(math.max(min, math.min(max, slider:GetValue() + delta * step)))
        end
        Button(parent, "−", x, y - 17, 19, 18, function() adjust(-1) end)
        Button(parent, "+", x + width - 19, y - 17, 19, 18, function() adjust(1) end)
        slider:EnableMouseWheel(true)
        slider:SetScript("OnMouseWheel", function(_, delta) adjust(delta) end)
        slider:SetScript("OnValueChanged", function(_, v)
            if not updating then set(math.floor(v / step + 0.5) * step) end
        end)
        RefreshWith(function()
            updating = true
            slider:SetValue(get())
            value:SetText(string.format(fmt, get()))
            updating = false
        end)
    end

    local preview = CreateFrame("Frame", nil, opt)
    preview:SetPoint("TOPRIGHT", -18, -76)
    preview:SetSize(284, 436)
    Plate(preview, "BACKGROUND", 0.12, 0.095, 0.123, 1)
    Header(preview, L("Vista previa", "Preview"), -16)
    local stage = CreateFrame("Frame", nil, preview)
    stage:SetPoint("TOPLEFT", 12, -43)
    stage:SetSize(260, 196)
    if stage.SetClipsChildren then stage:SetClipsChildren(true) end
    Plate(stage, "BACKGROUND", 0.057, 0.054, 0.068, 1)
    local emptyHand = Text(stage, L("Sin arma en mano principal", "No main-hand weapon equipped"), "GameFontHighlightSmall", 12, -92, 236)
    emptyHand:SetJustifyH("CENTER")
    local mainView, copyView = BuildPreview(stage, false), BuildPreview(stage, true)
    local previewSeal, previewCount = uw.seal or "command", 2
    local function ShowPreview()
        local noWeapon = db.style == "modelo" and db.useEquipped and not equippedItem
        emptyHand:SetShown(noWeapon and previewCount > 0)
        mainView:SetShown(previewCount > 0 and not noWeapon)
        if previewCount == 0 or noWeapon then
            copyView:Hide()
            return
        end
        local mirror = db.mirror == true
        local scale = math.min((mirror and 0.55 or 0.64) * db.scale, mirror and 0.63 or 0.68)
        local effect = db.style == "modelo" and ActiveWeaponEffect()
        if ModelAuraProfile(effect, false) and effect.aura ~= "sulfuras" then
            scale = math.min(scale, 0.55)
        end
        if mirror and IsHoriz() then scale = math.min(scale, 0.44) end
        local offset = mirror and (IsHoriz() and 65 or 59) or -12
        mainView:SetScale(scale)
        copyView:SetScale(scale)
        mainView:ClearAllPoints()
        copyView:ClearAllPoints()
        mainView:SetPoint("CENTER", stage, "CENTER", offset / scale, 0)
        copyView:SetPoint("CENTER", stage, "CENTER", -offset / scale, 0)
        copyView:SetShown(mirror)
        mainView:Draw(previewSeal, previewCount)
        if mirror then copyView:Draw(previewSeal, previewCount) end
    end

    Header(preview, L("Cargas", "Stacks"), -249)
    for count = 0, 3 do
        local button = Button(preview, tostring(count), 14 + count * 65, -269, 61, 26, function()
            previewCount = count
            opt:Refresh()
        end)
        RefreshWith(function() Selected(button, count == previewCount) end)
    end
    local sealLabel = Header(preview, "", -313)
    for i, kind in ipairs(SEAL_ORDER) do
        local button = Button(preview, "", 14 + (i - 1) * 43, -333, 39, 31, function()
            previewSeal = kind
            opt:Refresh()
        end)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(22, 22)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        RefreshWith(function()
            icon:SetTexture(SealIcon(kind))
            Selected(button, previewSeal == kind)
        end)
    end
    local test = Button(preview, L("Probar en pantalla", "Test on screen"), 14, -389, 256, 29, function()
        if not InCombatLockdown() then RunTest(previewSeal) end
    end)
    test:SetScript("OnEnter", function(self)
        if InCombatLockdown() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L("Disponible fuera de combate.", "Available out of combat."))
            GameTooltip:Show()
        end
    end)
    test:SetScript("OnLeave", GameTooltip_Hide)

    local appearance, position, alerts, advanced = unpack(pages)
    Header(appearance, TR("Estilo"), -15)
    local function EquippedName()
        if not equippedItem then return L("Sin arma en mano principal", "No main-hand weapon equipped") end
        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(equippedItem)
        return not IsSecret(name) and name or tostring(equippedItem)
    end
    local styles = {
        { key = "luna", name = TR(STYLES.luna.name), thumbnail = "moon_frame" },
        { key = "modelo", name = L("Arma fija", "Fixed weapon") },
        { key = "equipada", name = L("Arma equipada", "Equipped weapon") },
    }
    for i, card in ipairs(styles) do
        local button = Button(appearance, card.name, 16 + (i - 1) * 152, -37, 144, 63, function()
            db.useEquipped = card.key == "equipada"
            if db.useEquipped then
                RefreshEquipment()
                db.style = "modelo"
            else
                db.style = card.key == "luna" and "luna" or (db.weaponStyle or "espada")
            end
            ChangeAppearance()
        end)
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", 49, 0)
        button.label:SetWidth(89)
        button.label:SetJustifyH("LEFT")
        local thumbnail = button:CreateTexture(nil, "ARTWORK")
        thumbnail:SetPoint("LEFT", 10, 0)
        if card.key == "equipada" then
            thumbnail:SetSize(29, 29)
            RefreshWith(function()
                local texture = equippedItem and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(equippedItem)
                thumbnail:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            end)
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(EquippedName())
                GameTooltip:AddLine(L("Sigue automáticamente tu arma de mano principal.", "Automatically follows your main-hand weapon."))
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", GameTooltip_Hide)
        elseif card.key == "modelo" then
            thumbnail:SetSize(29, 29)
            RefreshWith(function()
                local weapon = WEAPON_BY_ITEM[db.modelItem]
                if db.weaponStyle == "espada" then
                    thumbnail:SetSize(23, 46)
                    thumbnail:SetTexture(MEDIA .. "sword_art")
                elseif weapon and weapon.art then
                    thumbnail:SetSize(23, 46)
                    thumbnail:SetTexture(MEDIA .. weapon.art)
                else
                    local itemIcon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(db.modelItem)
                    thumbnail:SetSize(29, 29)
                    thumbnail:SetTexture(weapon and weapon.icon or itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
                end
            end)
        else
            thumbnail:SetSize(23, 46)
            thumbnail:SetTexture(MEDIA .. card.thumbnail)
            local overlay = PreviewTexture(button, "moon2", "ARTWORK", -1)
            overlay:SetAllPoints(thumbnail)
            overlay:SetVertexColor(0.94, 0.62, 0.30)
        end
        RefreshWith(function()
            local active = db.style == "luna" and "luna" or (db.useEquipped and "equipada" or "modelo")
            Selected(button, card.key == active)
        end)
    end

    Header(appearance, L("Armas de Reprensión", "Retribution weapons"), -116)
    local categories = {
        { key = "sword", label = L("Espadas", "Swords") },
        { key = "axe", label = L("Hachas", "Axes") },
        { key = "mace", label = L("Mazas", "Maces") },
    }
    local selectedWeapon = WEAPON_BY_ITEM[db.modelItem]
    local category = db.weaponStyle ~= "espada" and selectedWeapon and selectedWeapon.category or "sword"
    local lastItem, lastWeaponStyle = db.modelItem, db.weaponStyle
    RefreshWith(function()
        if db.modelItem ~= lastItem or db.weaponStyle ~= lastWeaponStyle then
            local weapon = WEAPON_BY_ITEM[db.modelItem]
            category = db.weaponStyle ~= "espada" and weapon and weapon.category or "sword"
            lastItem, lastWeaponStyle = db.modelItem, db.weaponStyle
        end
    end)
    for i, entry in ipairs(categories) do
        local tab = Button(appearance, entry.label, 219 + (i - 1) * 82, -109, 77, 24, function()
            category = entry.key
            opt:Refresh()
        end)
        RefreshWith(function() Selected(tab, category == entry.key) end)
    end

    local cardColumns = {}
    local gallery = { CLASSIC_SWORD, unpack(WEAPONS) }
    local categoryCounts = {}
    for _, weapon in ipairs(gallery) do
        categoryCounts[weapon.category] = (categoryCounts[weapon.category] or 0) + 1
    end
    for _, weapon in ipairs(gallery) do
        local column = cardColumns[weapon.category] or 0
        cardColumns[weapon.category] = column + 1
        local name = L(weapon.es, weapon.en)
        local stride = math.min(76, math.floor((appearance:GetWidth() - 22) / categoryCounts[weapon.category]))
        local width = stride - 5
        local button = Button(appearance, name, 16 + column * stride, -138, width, 91, function()
            db.useEquipped = false
            if weapon.classic then
                db.style = "espada"
            else
                db.modelItem = weapon.id
                db.style = "modelo"
            end
            ChangeAppearance()
        end)
        button.label:ClearAllPoints()
        button.label:SetPoint("TOP", 0, -49)
        button.label:SetWidth(width - 2)
        button.label:SetJustifyH("CENTER")
        local icon = button:CreateTexture(nil, "ARTWORK")
        if weapon.art then
            icon:SetSize(21, 42)
            icon:SetPoint("TOP", 0, -3)
            icon:SetTexture(MEDIA .. weapon.art)
        else
            icon:SetSize(34, 34)
            icon:SetPoint("TOP", 0, -8)
            icon:SetTexture(weapon.icon)
        end
        local format = Text(button, weapon.art and "2D" or "3D", "GameFontHighlightSmall", 0, -75, width)
        format:SetJustifyH("CENTER")
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L(weapon.esFull or weapon.es, weapon.enFull or weapon.en))
            GameTooltip:AddLine(weapon.art and L("Ilustración 2D", "2D illustration") or TR("Modelo 3D"))
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        RefreshWith(function()
            button:SetShown(category == weapon.category)
            Selected(button, (weapon.classic and db.style == "espada")
                or (db.style == "modelo" and not db.useEquipped and db.modelItem == weapon.id))
        end)
    end

    Header(appearance, TR("Colores de cada sello"), -249)
    for i, kind in ipairs(SEAL_ORDER) do
        local x = 16 + ((i - 1) % 3) * 153
        local y = -272 - math.floor((i - 1) / 3) * 35
        local chip
        local button = Button(appearance, TR(SEAL_LABEL[kind]), x, y, 144, 30, function(_, mouse)
            previewSeal = kind
            if mouse == "RightButton" then
                db.colors[kind] = nil
                ChangeAppearance()
            else
                opt:Refresh()
                OpenColorPicker(kind, ChangeAppearance)
            end
        end)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", 34, 0)
        chip = button:CreateTexture(nil, "ARTWORK")
        chip:SetPoint("LEFT", 9, 0)
        chip:SetSize(15, 15)
        RefreshWith(function()
            local color = SealColor(kind)
            chip:SetColorTexture(color[1], color[2], color[3], 1)
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(TR("Clic: cambiar color\nClic derecho: color original"))
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
    end
    Check(appearance, TR("Mostrar el icono del sello"), -348,
        function() return db.showIcon ~= false end,
        function(v) db.showIcon = v; UpdateAppearance() end)

    Header(position, TR("Dirección de carga"), -15)
    local directions = { { "arriba", TR("Hacia arriba") }, { "abajo", TR("Hacia abajo") },
                         { "derecha", TR("Hacia la derecha") }, { "izquierda", TR("Hacia la izquierda") } }
    for i, direction in ipairs(directions) do
        local button = Button(position, direction[2], 16 + ((i - 1) % 2) * 228,
            -38 - math.floor((i - 1) / 2) * 34, 220, 28, function()
                db.fillDir = direction[1]
                ChangeAppearance()
            end)
        RefreshWith(function() Selected(button, db.fillDir == direction[1]) end)
    end
    Slider(position, TR("Tamaño"), 16, -120, 212, 0.5, 3, 0.05, "%.2f",
        function() return db.scale end,
        function(v) db.scale = v; ChangeAppearance() end)
    Slider(position, TR("Opacidad"), 244, -120, 220, 0.2, 1, 0.05, "%.2f",
        function() return db.alpha end,
        function(v) db.alpha = v; ChangeAppearance() end)
    Check(position, TR("Copia simétrica al otro lado del personaje"), -173,
        function() return db.mirror == true end,
        function(v) db.mirror = v; if not v then M:Hide() end; UpdateAppearance() end)
    Check(position, TR("Desbloquear para moverlo (arrastrar)"), -210,
        function() return f.unlocked == true end, function(v) SetLocked(not v) end)
    Text(position, TR("Desbloqueado, el icono se arrastra por separado."), "GameFontHighlightSmall", 44, -243, 418)
    Button(position, L("Recolocar indicador", "Reset indicator position"), 16, -280, 220, 29, function()
        db.point = { unpack(DEFAULTS.point) }
        ApplyPosition()
    end)
    Button(position, TR("Recolocar icono"), 244, -280, 220, 29, function()
        db.iconOffset = nil
        ChangeAppearance()
    end)

    Slider(alerts, TR("Aparece desde (cargas)"), 16, -20, 240, 1, 3, 1, "%d",
        function() return db.minStacks end,
        function(v) db.minStacks = v; Scan(); opt:Refresh() end)
    Check(alerts, TR("Sonido al llegar a 3 cargas"), -80,
        function() return db.sound end, function(v) db.sound = v end)
    Check(alerts, TR("Ocultar el visor de beneficios de Blizzard (sigue activo)"), -119,
        function() return db.hideViewer == true end,
        function(v) db.hideViewer = v; ApplyViewer() end)
    Text(alerts, TR("En combate las cargas se cuentan con el icono de Unsealed Wrath del visor de buffs de Blizzard: no lo quites de allí. /pw ayuda: lista de comandos."),
        "GameFontHighlightSmall", 44, -157, 405)

    local framing = CreateFrame("Frame", nil, advanced)
    framing:SetAllPoints()
    local noModel = Text(advanced, "", "GameFontHighlight", 16, -50, 448)
    Header(advanced, TR("Modelo 3D (encuadre)"), -15)
    local profile = Text(framing, "", "GameFontHighlightSmall", 16, -33, 450)
    local framePages, frameButtons, copy = {}, {}, false
    for i, label in ipairs({ TR("Espada principal"), TR("Copia simétrica") }) do
        local isCopy = i == 2
        frameButtons[i] = Button(framing, label, 16 + (i - 1) * 228, -57, 220, 26, function()
            copy = isCopy
            opt:Refresh()
        end)
        local group = CreateFrame("Frame", nil, framing)
        group:SetAllPoints()
        framePages[i] = group
        local sealMask = CreateFrame("Frame", nil, group)
        sealMask:SetAllPoints()
        RefreshWith(function()
            local effect = ActiveWeaponEffect()
            sealMask:SetShown(effect ~= nil and effect.seal == true)
        end)

        local function ModelSlider(label, index, min, max, step, fmt, key, cutout)
            local x = index % 2 == 1 and 16 or 244
            local y = -99 - math.floor((index - 1) / 2) * 45
            local function get()
                if isCopy then return MirrorVal(key) end
                return db[key]
            end
            Slider(cutout and sealMask or group, label, x, y, 212, min, max, step, fmt, get, function(v)
                db[key] = v
                ChangeAppearance()
            end)
        end
        ModelSlider(TR("Giro"), 1, 0, 360, 5, "%d°", isCopy and "mFacing" or "modelFacing")
        ModelSlider(TR("Inclinación"), 2, 0, 360, 5, "%d°", isCopy and "mPitch" or "modelPitch")
        ModelSlider(TR("Rotación"), 3, 0, 360, 5, "%d°", isCopy and "mRoll" or "modelRoll")
        if isCopy then
            ModelSlider(TR("Recorte del sello: horizontal"), 4, -120, 120, 1, "%d", "mCoverX", true)
            ModelSlider(TR("Recorte del sello: vertical"), 5, -150, 150, 1, "%d", "mCoverY", true)
            Text(group, L("La copia comparte el zoom de la espada principal.",
                "The mirrored copy shares the main weapon’s zoom."), "GameFontHighlightSmall", 16, -250, 448)
            local showCopy = Button(group, L("Activar copia simétrica", "Enable mirrored copy"), 16, -277, 220, 27, function()
                db.mirror = true
                ChangeAppearance()
            end)
            RefreshWith(function() showCopy:SetShown(not db.mirror) end)
        else
            ModelSlider("Zoom", 4, 0.3, 4, 0.1, "%.1f", "modelZoom")
            ModelSlider(TR("Subir / bajar"), 5, -3, 3, 0.05, "%.2f", "modelY")
            ModelSlider(L("Desplazamiento lateral", "Lateral offset"), 6, -3, 3, 0.05, "%.2f", "modelX")
            ModelSlider(TR("Recorte del sello: tamaño"), 7, 10, 120, 1, "%d", "coverSize", true)
            ModelSlider(TR("Recorte del sello: horizontal"), 8, -120, 120, 1, "%d", "coverX", true)
            ModelSlider(TR("Recorte del sello: vertical"), 9, -150, 150, 1, "%d", "coverY", true)
            local shape = Button(sealMask, "", 244, -282, 220, 27, function()
                db.holeShape = db.holeShape == "circulo" and "cuadrado" or "circulo"
                ChangeAppearance()
            end)
            Check(sealMask, L("Ocultar sello con 0–2 cargas", "Hide seal at 0–2 stacks"), -316,
                SealCutoutEnabled, function(v)
                    if ModelItem() == ASHBRINGER_ITEM then db.ashbringerCoverOn = v else db.coverOn = v end
                    UpdateAppearance()
                end)
            RefreshWith(function()
                shape.label:SetText(TR("Hueco: " .. (db.holeShape == "circulo" and "círculo" or "cuadrado")))
            end)
        end
    end

    StaticPopupDialogs["PALLY_WRATH_STUDIO_RESET_SETTINGS"] = {
        text = L("¿Restablecer los ajustes de Pally Wrath?", "Reset Pally Wrath settings?"),
        button1 = TR("Restablecer"),
        button2 = CANCEL,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function()
            local log = db.log
            wipe(db)
            CopyDefaults(DEFAULTS, db)
            db.log = log
            M:Hide()
            ApplyViewer()
            ChangeAppearance()
        end,
    }
    Button(advanced, TR("Restablecer"), 16, -348, 175, 28, function()
        StaticPopup_Show("PALLY_WRATH_STUDIO_RESET_SETTINGS")
    end)

    function opt:Refresh()
        if not self:IsVisible() then return end
        for i, page in ipairs(pages) do
            page:SetShown(i == selectedTab)
            Selected(tabs[i], i == selectedTab)
        end
        local isModel = db.style == "modelo" and ModelItem() ~= nil and not ActiveWeaponArt()
        framing:SetShown(isModel)
        noModel:SetShown(not isModel)
        if db.style == "modelo" and db.useEquipped and not equippedItem then
            noModel:SetText(EquippedName())
        elseif db.style == "modelo" and ActiveWeaponArt() then
            noModel:SetText(L("Esta arma usa una ilustración 2D. En Posición puedes ajustar el tamaño, la opacidad y la dirección de carga.",
                "This weapon uses a 2D illustration. Use Position to adjust size, opacity, and fill direction."))
        else
            noModel:SetText(L("Selecciona un arma 3D en Apariencia para ajustar el encuadre.",
                "Select a 3D weapon in Appearance to adjust its framing."))
        end
        framePages[1]:SetShown(not copy)
        framePages[2]:SetShown(copy)
        Selected(frameButtons[1], not copy)
        Selected(frameButtons[2], copy)
        local weapon = ActiveWeapon()
        local name = db.useEquipped and EquippedName() or (weapon and L(weapon.es, weapon.en) or tostring(db.modelItem))
        profile:SetText(name .. L(" · Encuadre guardado por dirección", " · Framing saved per direction"))
        for _, refresh in ipairs(slots) do refresh() end
        sealLabel:SetText(L("Sello · ", "Seal · ") .. TR(SEAL_LABEL[previewSeal]))
        ShowPreview()
    end

    local function Fit()
        opt:SetScale(math.min(1, (UIParent:GetWidth() - 24) / 820, (UIParent:GetHeight() - 24) / 530))
    end
    opt:RegisterEvent("DISPLAY_SIZE_CHANGED")
    opt:RegisterEvent("UI_SCALE_CHANGED")
    opt:SetScript("OnEvent", Fit)
    opt:SetScript("OnShow", function(self) Fit(); self:Refresh() end)
    opt:SetScript("OnHide", function(self) self:StopMovingOrSizing() end)
end

local function ToggleOptions()
    if not opt then BuildOptions() end
    if opt:IsShown() then opt:Hide() else opt:Show() end
end

-- Entrada en Esc > Opciones > AddOns
RegisterSettingsPanel = function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "Pally Wrath"
    local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("|cffF58CBAPally Wrath|r")
    local d = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetText(TR("Indicador de cargas de Unsealed Wrath. También con /pw."))
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(180, 24)
    b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
    b:SetText(TR("Abrir opciones"))
    b:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel.Hide then pcall(SettingsPanel.Hide, SettingsPanel) end
        if not opt then BuildOptions() end
        opt:Show()
    end)
    local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Pally Wrath")
    if ok and cat then pcall(Settings.RegisterAddOnCategory, cat) end
end

------------------------------------------------------------
-- Comandos: /pw, /pallywrath, /eco, /pws y /pallywrathstudio
------------------------------------------------------------
Print = function(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. TR(msg)) end

-- El icono del visor de Blizzard es la fuente de cargas en combate.
-- Pally Wrath solo cambia su opacidad si se activa ese ajuste.
local VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
local viewerHooked, viewerAlpha, viewerGuard = {}, {}, false

local function CanTouch(v)
    if not v then return false end
    if InCombatLockdown and InCombatLockdown() and v.IsProtected and v:IsProtected() then return false end
    return true
end

ApplyViewer = function()
    if not db then return end
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        if CanTouch(viewer) then
            if db.hideViewer then
                if not viewerHooked[viewer] then
                    viewerHooked[viewer] = true
                    hooksecurefunc(viewer, "SetAlpha", function(self, alpha)
                        if viewerGuard or not db.hideViewer then return end
                        if IsSecret(alpha) or alpha == 0 or not CanTouch(self) then return end
                        viewerAlpha[self] = alpha
                        viewerGuard = true
                        pcall(self.SetAlpha, self, 0)
                        viewerGuard = false
                    end)
                end
                if viewerAlpha[viewer] == nil then
                    local alpha = viewer:GetAlpha()
                    if not IsSecret(alpha) then viewerAlpha[viewer] = alpha end
                end
                viewerGuard = true
                pcall(viewer.SetAlpha, viewer, 0)
                viewerGuard = false
            elseif viewerAlpha[viewer] ~= nil then
                pcall(viewer.SetAlpha, viewer, viewerAlpha[viewer])
                viewerAlpha[viewer] = nil
            end
        end
    end
end

local viewerEv = CreateFrame("Frame")
viewerEv:RegisterEvent("PLAYER_ENTERING_WORLD")
viewerEv:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(viewerEv.RegisterEvent, viewerEv, "EDIT_MODE_LAYOUTS_UPDATED")
pcall(viewerEv.RegisterEvent, viewerEv, "CVAR_UPDATE")
viewerEv:SetScript("OnEvent", function(_, event)
    if not db then return end
    C_Timer.After(0.5, function() pcall(ApplyViewer) end)
end)

------------------------------------------------------------
-- SONDA: probar en combate vías que no dependan del Cooldown Manager
-- (/pw sonda). Escribe los resultados en el registro y muestra un
-- pequeño panel de prueba con el número "a ciegas".
------------------------------------------------------------
local ToggleProbe = (function()
local sonda = { armed = false, t = 0, runs = 0 }
local sp = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
sp:SetSize(220, 70)
sp:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
if sp.SetBackdrop then
    sp:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    sp:SetBackdropColor(0, 0, 0, 0.6); sp:SetBackdropBorderColor(1, 0.6, 0.2, 1)
end
sp:Hide()
sp.title = sp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sp.title:SetPoint("TOPLEFT", 6, -5); sp.title:SetText("Pally Wrath - sonda")
sp.label = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sp.label:SetPoint("TOPLEFT", 6, -20); sp.label:SetText("cargas:")
sp.txt = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
sp.txt:SetPoint("LEFT", sp.label, "RIGHT", 6, 0); sp.txt:SetText("-")
sp.txt2 = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
sp.txt2:SetPoint("LEFT", sp.txt, "RIGHT", 18, 0); sp.txt2:SetText("-")
sp.bar = CreateFrame("StatusBar", nil, sp)
sp.bar:SetPoint("BOTTOMLEFT", 6, 8); sp.bar:SetSize(150, 12)
sp.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
sp.bar:SetStatusBarColor(1, 0.55, 0.1)
sp.bar:SetMinMaxValues(0, 3); sp.bar:SetValue(0)
sp.barbg = sp.bar:CreateTexture(nil, "BACKGROUND"); sp.barbg:SetAllPoints(); sp.barbg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
sp.fire = sp:CreateTexture(nil, "OVERLAY")
sp.fire:SetSize(40, 40); sp.fire:SetPoint("RIGHT", -8, -4)
sp.fire:SetTexture(135808)  -- icono de llama
sp.fire:SetAlpha(0.15)

local function SLog(msg) Log("SONDA " .. msg) end

local function FindEchoAura()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil, nil end
    for id in pairs(KNOWN_ECHO) do
        local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if ok and a ~= nil then return a, id end
    end
end

local curve3   -- curva: 0 con menos de 3 cargas, 1 con 3
local function GetCurve()
    if curve3 ~= nil then return curve3 or nil end
    curve3 = false
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local ok, c = pcall(C_CurveUtil.CreateCurve)
        if ok and c then
            pcall(function() if c.SetType and Enum and Enum.LuaCurveType then c:SetType(Enum.LuaCurveType.Step) end end)
            local okA = pcall(function()
                c:AddPoint(0, 0); c:AddPoint(2.5, 0); c:AddPoint(2.6, 1); c:AddPoint(3, 1)
            end)
            SLog("curva creada, AddPoint ok=" .. tostring(okA))
            if okA then curve3 = c end
        else
            SLog("CreateCurve falla: " .. D(c))
        end
    end
    return curve3 or nil
end

local function Methods(o, filter)
    local out = {}
    local mt = type(o) == "table" and getmetatable(o)
    local idx = mt and type(mt.__index) == "table" and mt.__index or (type(o) == "table" and o) or {}
    for k in pairs(idx) do
        if type(k) == "string" and (not filter or k:find(filter)) then out[#out + 1] = k end
    end
    table.sort(out)
    return table.concat(out, ",")
end

local function SondaRun(full)
    local inCombat = InCombatLockdown and InCombatLockdown()
    local a, id = FindEchoAura()
    if full then
        SLog("---- combate=" .. tostring(inCombat) .. " eco=" .. tostring(a ~= nil) .. " id=" .. D(id))
        SLog("C_CurveUtil: " .. (C_CurveUtil and Methods(C_CurveUtil) or "no existe"))
        SLog("C_UnitAuras (Aura*/Dur*/Count*): " .. (C_UnitAuras and Methods(C_UnitAuras, "Aura") or "no"))
        SLog("textura *From*: " .. Methods(sp.fire, "From"))
        SLog("statusbar *From*/*Value*: " .. Methods(sp.bar, "Value") .. " " .. Methods(sp.bar, "From"))
        SLog("fontstring *From*/Text: " .. Methods(sp.txt, "Text"))
    end
    if full then
        -- ¿qué buffs ve el addon ahora mismo?
        local n, desc = 0, {}
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            for i = 1, 40 do
                local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
                if not ok then desc[#desc + 1] = i .. ":ERROR " .. D(d); break end
                if d == nil then break end
                n = n + 1
                local okS, txt = pcall(function()
                    return i .. ":" .. D(d.spellId) .. "/" .. D(d.name) .. "/x" .. D(d.applications)
                end)
                if i <= 20 then desc[#desc + 1] = okS and txt or (i .. ":?") end
            end
        end
        SLog("buffs visibles: " .. n .. " -> " .. table.concat(desc, "  "))
        for id, kind in pairs(KNOWN_ECHO) do
            local ok, r = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            SLog("porID " .. kind .. " " .. id .. ": ok=" .. tostring(ok) .. " -> " .. D(r))
        end
    end
    if not a then
        sp.txt:SetText("sin eco"); sp.txt2:SetText("-")
        return
    end
    local apps, inst
    pcall(function() apps = a.applications end)
    pcall(function() inst = a.auraInstanceID end)
    if full then
        SLog("aura secreta=" .. tostring(IsSecret(a)) .. " cargas=" .. D(apps) .. " instancia=" .. D(inst)
            .. " expira=" .. D(a.expirationTime) .. " icono=" .. D(a.icon))
    end
    -- 1) texto con el número a ciegas
    local okT, eT = pcall(sp.txt.SetText, sp.txt, apps)
    if full then SLog("SetText(cargas) ok=" .. tostring(okT) .. (okT and "" or " " .. D(eT))) end
    if not okT then sp.txt:SetText("X") end
    -- 2) texto oficial de cargas
    if inst ~= nil and C_UnitAuras.GetAuraApplicationDisplayCount then
        local ok, r = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "player", inst)
        local okS = ok and pcall(sp.txt2.SetText, sp.txt2, r)
        if full then SLog("DisplayCount ok=" .. tostring(ok) .. " -> " .. D(r) .. " SetText ok=" .. tostring(okS)) end
    elseif full then
        SLog("no hay GetAuraApplicationDisplayCount o instancia")
    end
    -- 3) barra con el número a ciegas
    local okB, eB = pcall(sp.bar.SetValue, sp.bar, apps)
    if full then
        SLog("StatusBar:SetValue(cargas) ok=" .. tostring(okB) .. (okB and "" or " " .. D(eB)))
        if okB then SLog("  GetValue -> " .. D(select(2, pcall(sp.bar.GetValue, sp.bar)))) end
    end
    -- 4) curva -> transparencia de la llama
    local c = GetCurve()
    if c then
        local okE, v = pcall(c.Evaluate, c, apps)
        if full then SLog("curva:Evaluate(cargas) ok=" .. tostring(okE) .. " -> " .. D(v)) end
        if okE then
            local okA, eA = pcall(sp.fire.SetAlpha, sp.fire, v)
            if full then SLog("textura:SetAlpha(resultado) ok=" .. tostring(okA) .. (okA and "" or " " .. D(eA))) end
        end
    elseif full then
        SLog("sin curva")
    end
    -- 5) comparaciones directas (deberían fallar en combate)
    if full then
        local okC, r = pcall(function() return apps >= 3 end)
        SLog("comparar cargas>=3 ok=" .. tostring(okC) .. " -> " .. D(r))
        if C_UnitAuras.GetAuraDuration and inst ~= nil then
            local okD, d = pcall(C_UnitAuras.GetAuraDuration, "player", inst)
            SLog("GetAuraDuration ok=" .. tostring(okD) .. " -> " .. D(d) .. (okD and type(d) == "table" and (" metodos: " .. Methods(d)) or ""))
        end
    end
end

local sondaFrame = CreateFrame("Frame")
sondaFrame:SetScript("OnUpdate", function(_, elapsed)
    if not sonda.armed then return end
    sonda.t = sonda.t + elapsed
    if sonda.t < 0.25 then return end
    sonda.t = 0
    local inCombat = InCombatLockdown and InCombatLockdown()
    -- registro completo: una vez fuera de combate y varias en combate (con eco)
    local full = false
    sonda.tick = (sonda.tick or 0) + 1
    if inCombat and sonda.runs < 6 and sonda.tick % 8 == 0 then
        sonda.runs = sonda.runs + 1; full = true
    elseif not inCombat and not sonda.outDone then
        sonda.outDone = true; full = true
    end
    local ok, err = pcall(SondaRun, full)
    if not ok then SLog("ERROR: " .. D(err)) end
end)

return function()
    sonda.armed = not sonda.armed
    if sonda.armed then
        sonda.runs, sonda.outDone, sonda.tick = 0, false, 0
        wipe(logSeen)
        sp:Show()
        Print("Sonda ACTIVADA: pega a un mob hasta tener 3 cargas, sal de combate y escribe /reload.")
    else
        sp:Hide()
        Print("Sonda desactivada.")
    end
end
end)()

SLASH_PALLYWRATH1 = "/pw"
SLASH_PALLYWRATH3 = "/eco"
SLASH_PALLYWRATH4 = "/pws"
SLASH_PALLYWRATH5 = "/pallywrathstudio"
SLASH_PALLYWRATH2 = "/pallywrath"

local function HandleCommand(msg)
    local cmd, a, b = strsplit(" ", string.lower(msg or ""))
    -- alias en inglés
    local CMD_EN = { options = "opciones", help = "ayuda", style = "estilo", scale = "escala", sound = "sonido",
        min = "minimo", mirror = "espejo", direction = "direccion", opacity = "opacidad", icon = "icono",
        rotate = "giro", item = "objeto", count = "cuenta", preview = "test" }
    local ARG_EN = { moon = "luna", sword = "espada", model = "modelo", up = "arriba", down = "abajo",
        right = "derecha", left = "izquierda", on = "si", off = "no", show = "si", hide = "no",
        clear = "borrar", command = "orden", righteousness = "rectitud", wisdom = "sabiduria",
        light = "luz", justice = "justicia", fury = "furia" }
    cmd = CMD_EN[cmd] or cmd
    if cmd == "icono" and a == "reset" then a = "recolocar" end
    a = ARG_EN[a] or a
    if cmd == "mover" or cmd == "unlock" then
        f.unlocked = true
        f:EnableMouse(true)
        ShowMoon("command", nil, 3, GetTime() + 15)
        Print("Desbloqueado. Arrastra el indicador y escribe /pw fijar.")
    elseif cmd == "fijar" or cmd == "lock" then
        f.unlocked = false
        f:EnableMouse(false)
        HideMoon()
        Scan()
        Print("Posición guardada.")
    elseif cmd == "test" or cmd == "prueba" then
        RunTest(KindFromAlias(a) or "command")
        Print("Prueba: 1, 2 y 3 cargas.")
    elseif cmd == "escala" or cmd == "scale" then
        local v = tonumber(a)
        if v and v >= 0.3 and v <= 3 then
            db.scale = v
            ApplyPosition()
            Print("Escala: " .. v)
        else
            Print("Uso: /pw escala 0.5-3")
        end
    elseif cmd == "sonido" or cmd == "sound" then
        db.sound = not db.sound
        Print("Sonido: " .. (db.sound and "activado" or "desactivado"))
    elseif cmd == "minimo" or cmd == "cargas" then
        local v = tonumber(a)
        if v and v >= 1 and v <= 3 then
            db.minStacks = v
            Print("El indicador aparece a partir de " .. v .. " carga(s).")
            Scan()
        else
            Print("Uso: /pw minimo 1-3")
        end
    elseif cmd == "buffs" then
        Print("Tus buffs actuales (nombre / ID / cargas):")
        ForEachBuff(function(name, _, count, spellId)
            local kind = (spellId and db.spellIds[spellId]) or ClassifyByName(name)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("   %s  |cff999999ID %s|r  x%d %s",
                name, tostring(spellId), count, kind and ("|cff00ff00<- " .. SEALS[kind].alias[1] .. "|r") or ""))
        end)
    elseif cmd == "add" then
        local id = tonumber(b)
        local kind = KindFromAlias(a)
        if id and kind then
            db.spellIds[id] = kind
            Print("ID " .. id .. " asignado a " .. SEALS[kind].alias[1] .. ".")
            Scan()
        else
            Print("Uso: /pw add <sello> <ID>   (orden, rectitud, sabiduria, luz, justicia, furia)")
        end
    elseif cmd == "opacidad" or cmd == "alpha" then
        local v = tonumber(a)
        if v and v > 1 then v = v / 100 end
        if v and v >= 0.2 and v <= 1 then
            db.alpha = v
            ApplyPosition()
            Print(string.format("Opacidad: %d%%", v * 100))
        else
            Print("Uso: /pw opacidad 20-100   (actual: " .. math.floor((db.alpha or 0.8) * 100) .. "%)")
        end
    elseif cmd == "direccion" or cmd == "dir" then
        local map = { arriba = "arriba", abajo = "abajo", derecha = "derecha", izquierda = "izquierda",
                      dcha = "derecha", izq = "izquierda" }
        if a and map[a] then
            db.fillDir = map[a]
            ApplyStyle()
            RunTest(uw and uw.seal or "command")
            Print(({ arriba = "Hacia arriba", abajo = "Hacia abajo", derecha = "Hacia la derecha", izquierda = "Hacia la izquierda" })[db.fillDir])
        else
            Print("Uso: /pw direccion arriba | abajo | derecha | izquierda   (actual: " .. db.fillDir .. ")")
        end
    elseif cmd == "inclinacion" or cmd == "rotacion" then
        local v = tonumber(a)
        if v then
            if cmd == "inclinacion" then db.modelPitch = v % 360 else db.modelRoll = v % 360 end
            if db.style == "modelo" and not ActiveWeaponArt() then UpdateAppearance() end
            Print(cmd .. ": " .. (v % 360) .. "º")
        else
            Print("Uso: /pw " .. cmd .. " <grados>")
        end
    elseif cmd == "icono" then
        if a == "no" or a == "ocultar" then db.showIcon = false
        elseif a == "si" or a == "mostrar" then db.showIcon = true
        elseif a == "recolocar" or a == "reset" then db.iconOffset = nil
        else Print("Uso: /pw icono si | no | recolocar"); return end
        UpdateAppearance()
        Print("Icono del sello: " .. (db.showIcon and "visible" or "oculto") .. (db.iconOffset and " (posición propia)" or ""))
    elseif cmd == "espejo" or cmd == "copia" then
        if a == "si" then db.mirror = true elseif a == "no" then db.mirror = false
        else db.mirror = not db.mirror end
        UpdateAppearance()
        if db.mirror then RunTest(uw and uw.seal or "command") else M:Hide() end
        Print("Copia simétrica: " .. (db.mirror and "activada" or "desactivada"))
    elseif cmd == "giro" then
        local v = tonumber(a)
        if v then
            db.modelFacing = v % 360
            if db.style == "modelo" and not ActiveWeaponArt() then UpdateAppearance() end
            Print("Giro del modelo: " .. db.modelFacing .. "º")
        else
            Print("Uso: /pw giro <grados>   (actual: " .. tostring(db.modelFacing) .. "º)")
        end
    elseif cmd == "objeto" then
        local id = tonumber(a)
        if id and id > 0 and id == math.floor(id) then
            db.useEquipped = false
            db.modelItem = id
            UpdateAppearance()
            Print((ActiveWeaponArt() and "Ilustración de arma: objeto " or "Modelo 3D: objeto ") .. id)
        else
            Print("Uso: /pw objeto <ID de objeto>   (actual: " .. tostring(db.modelItem) .. ")")
        end
    elseif cmd == "zoom" then
        local v = tonumber(a)
        if v and v > 0.2 and v < 5 then
            db.modelZoom = v
            if db.style == "modelo" and not ActiveWeaponArt() then UpdateAppearance() end
            Print("Zoom del modelo: " .. v)
        else
            Print("Uso: /pw zoom 0.5-3   (actual: " .. tostring(db.modelZoom) .. ")")
        end
    elseif cmd == "cuenta" then
        local opts = { "RefreshApplications", "OnActiveStateChanged", "RefreshActive",
                       "Cooldown.SetCooldown", "Cooldown.SetCooldownFromDurationObject", "Cooldown.SetCooldownDuration" }
        local n = tonumber(a)
        if n and opts[n] then
            db.countHook = opts[n]
            Print("En combate cuento cargas con: " .. db.countHook)
        else
            Print("Actual: " .. db.countHook .. ". Opciones:")
            for i, o in ipairs(opts) do Print("  /pw cuenta " .. i .. "  -> " .. o) end
        end
    elseif cmd == "visor" or cmd == "tracker" then
        if a == "si" or a == "mostrar" or a == "show" then db.hideViewer = false
        elseif a == "no" or a == "ocultar" or a == "hide" then db.hideViewer = true
        else db.hideViewer = (db.hideViewer == false) end
        ApplyViewer()
        Print("Visor de Blizzard: " .. (db.hideViewer ~= false and TR("oculto") or TR("visible")))
    elseif cmd == "sonda" or cmd == "probe" then
        ToggleProbe()
    elseif cmd == "debug" then
        db.debug = not db.debug
        Print("Debug: " .. (db.debug and "activado" or "desactivado"))
    elseif cmd == "log" then
        if a == "borrar" then
            db.log = {}
            wipe(logSeen)
            Print("Registro borrado.")
        else
            Print("Registro de diagnóstico (" .. #(db.log or {}) .. " líneas):")
            for _, l in ipairs(db.log or {}) do DEFAULT_CHAT_FRAME:AddMessage("   " .. l) end
        end
    elseif cmd == "estilo" or cmd == "style" then
        if a == "ashbringer" then a = "espada" end
        if a == "modelo" or a == "3d" then a = "modelo" end
        if a == "luna" or a == "espada" or a == "modelo" then
            db.style = a
            ApplyStyle()
            Print("Estilo: " .. STYLES[a].name)
            testMode = true
            ShowMoon("command", nil, 3, GetTime() + 15)
            testId = testId + 1; TestTimer(3, EndTest)
        else
            Print("Uso: /pw estilo luna | espada | modelo   (actual: " .. db.style .. ")")
        end
    elseif cmd == "color" then
        local kind = KindFromAlias(a)
        local _, _, rs, gs, bs = strsplit(" ", string.lower(msg or ""))
        local r, g, bl = tonumber(rs), tonumber(gs), tonumber(bs)
        if kind and b == "reset" then
            db.colors[kind] = nil
            Print("Color de " .. SEALS[kind].alias[1] .. " restablecido.")
        elseif kind and r and g and bl then
            db.colors[kind] = { r, g, bl }
            Print(string.format("Color de %s: %.2f %.2f %.2f", SEALS[kind].alias[1], r, g, bl))
        else
            Print("Uso: /pw color <sello> R G B   (valores 0-1)   o   /pw color <sello> reset")
            return
        end
        testMode = true
        ShowMoon(kind, nil, 3, GetTime() + 15)
        testId = testId + 1; TestTimer(3, EndTest)
    elseif cmd == "reset" then
        PallyWrathDB = {}
        db = PallyWrathDB
        CopyDefaults(DEFAULTS, db)
        M:Hide()
        ApplyViewer()
        UpdateAppearance()
        Print("Configuración restablecida.")
    elseif cmd == "" or cmd == nil or cmd == "opciones" or cmd == "menu" then
        ToggleOptions()
    else
        Print("Comandos (/pw solo abre el menú de opciones):")
        Print("  /pw mover  |  /pw fijar   - colocar el indicador")
        Print("  /pw test [sello]           - ver una prueba (orden, rectitud, sabiduria...)")
        Print("  /pw estilo luna|espada|modelo - cambiar el dibujo del indicador")
        Print("  /pw escala 1.2             - tamaño")
        Print("  /pw opacidad 25            - transparencia (20-100)")
        Print("  /pw direccion arriba|abajo|derecha|izquierda - sentido de carga")
        Print("  /pw giro 90                - girar el modelo 3D (grados)")
        Print("  /pw espejo si|no           - copia simétrica al otro lado")
        Print("  /pw sonido                 - activar/desactivar sonido")
        Print("  /pw minimo 1               - cargas para que aparezca (1-3)")
        Print("  /pw buffs                  - listar tus buffs con su ID")
        Print("  /pw add <sello> <ID>       - asignar un buff a mano")
        Print("  /pw color <sello> R G B    - cambiar el color (0-1)")
        Print("  /pw log [borrar]           - ver el registro de diagnóstico")
        Print("  /pw reset")
    end
end

SlashCmdList.PALLYWRATH = function(msg)
    HandleCommand(msg)
    if opt then opt:Refresh() end
end
