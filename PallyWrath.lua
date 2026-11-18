-- Pally Wrath: aviso visual para el talento Unsealed Wrath (Paladín Reprensión, WoW Forever)
-- Media luna a la derecha del personaje que se rellena por tercios con cada carga
-- del eco que se esté acumulando. Con 3 cargas se envuelve en llamas y muestra el tiempo.

local ADDON = ...
local PREFIX = "|cffF58CBAPally Wrath|r: "

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
    modelItem = 22691,   -- objeto cuyo modelo 3D se muestra (22691 = Corrupted Ashbringer)
    modelZoom = 1.0,
    alpha = 0.25,
    fillDir = "arriba",  -- arriba | abajo (vertical) · derecha | izquierda (horizontal)
    modelFacing = 180,   -- giro del modelo 3D en grados
    modelPitch = 285,    -- inclinación
    fog2 = 0.6,          -- densidad de la niebla con 2 cargas (menor = tapa más)
    modelRoll = 270,     -- rotación (grados)
    modelX = 0, modelY = 0.1,  -- desplazamiento del modelo dentro de su marco
    showIcon = true,     -- mostrar el icono del sello
    hideViewer = true,   -- dejar invisible (pero activo) el visor de beneficios de Blizzard
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

------------------------------------------------------------
-- Idioma: castellano si el juego está en esES/esMX; si no, inglés
------------------------------------------------------------
local LOCALE = GetLocale and GetLocale() or "enUS"
local IS_ES = (LOCALE == "esES" or LOCALE == "esMX")
-- frases completas primero (más largas), luego fragmentos
local EN = {
    { "En combate las cargas se cuentan con el icono de Unsealed Wrath del visor de buffs de Blizzard: no lo quites de allí. /pw ayuda: lista de comandos.",
      "In combat, stacks are counted from the Unsealed Wrath icon in Blizzard's buff tracker: keep it there. /pw help: command list." },
    { "Cada ventana guarda el encuadre de la dirección de carga elegida.", "Each window keeps the framing of the selected fill direction." },
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
    { "Cooldown Manager activado: Pally Wrath lo necesita para contar cargas en combate.", "Cooldown Manager enabled: Pally Wrath needs it to count stacks in combat." },
    { "Si no ves el indicador en combate, haz /reload.", "If the indicator doesn't show in combat, type /reload." },
    { "En combate no encuentro el icono de Unsealed Wrath. Abre el Cooldown Manager > Beneficios rastreados y añade Unsealed Wrath.", "Can't find the Unsealed Wrath icon in combat. Open Cooldown Manager > Tracked Buffs and add Unsealed Wrath." },
    { "Visor de Blizzard: ", "Blizzard tracker: " },
    { "Aparece desde (cargas)", "Shows from (stacks)" },
    { "Colores de cada sello", "Color of each seal" },
    { "Modelo 3D (encuadre)", "3D model (framing)" },
    { "Hueco calavera: tamaño", "Skull hole: size" },
    { "Hueco calavera: horizontal", "Skull hole: horizontal" },
    { "Hueco calavera: vertical", "Skull hole: vertical" },
    { "Dirección de carga", "Fill direction" },
    { "Hacia la izquierda", "Leftwards" },
    { "Hacia la derecha", "Rightwards" },
    { "hacia la izquierda", "leftwards" },
    { "hacia la derecha", "rightwards" },
    { "Hacia arriba", "Upwards" },
    { "Hacia abajo", "Downwards" },
    { "hacia arriba", "upwards" },
    { "hacia abajo", "downwards" },
    { "Espada principal...", "Main sword..." },
    { "Copia simétrica...", "Mirrored copy..." },
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
local ToggleModelWindow, RefreshModelWindows   -- ventanas de ajuste del modelo (más abajo)
local modelWins = {}
local function IsHoriz() return db and (db.fillDir == "derecha" or db.fillDir == "izquierda") end

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
    luna   = { flame = "flame_moon",   iconX = 46, timerX = 152, name = "Media luna" },
    espada = { flame = "flame_sword2", iconX = 14, timerX = 112, name = "Espada" },
    modelo = { flame = "flame_sword2", iconX = 4,  timerX = 160, name = "Modelo 3D" },
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

---------------- Espada
local swordBg = f:CreateTexture(nil, "BACKGROUND")          -- espada apagada (vacía)
swordBg:SetAllPoints()
swordBg:SetTexture(MEDIA .. "sword_art")
swordBg:SetDesaturated(true)
swordBg:SetVertexColor(0.38, 0.38, 0.40)
local swordFill = lit:CreateTexture(nil, "ARTWORK")          -- parte cargada, a todo color
swordFill:SetTexture(MEDIA .. "sword_art")
swordFill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
swordFill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
local swordTint = lit:CreateTexture(nil, "OVERLAY")          -- velo del color del sello
swordTint:SetTexture(MEDIA .. "sword_mask")
swordTint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
swordTint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
swordTint:SetBlendMode("ADD")
swordTint:SetAlpha(0.30)

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
    if ix and fx then db.coverX, db.coverY = (ix * s1 - fx * s2) / s2, (iy * s1 - fy * s2) / s2 end
    self:ClearAllPoints()
    self:SetPoint("CENTER", f, "CENTER", db.coverX, db.coverY)
    if PlacePiecesRef then PlacePiecesRef() end
end)

local function PlaceCover()
    cover:ClearAllPoints()
    local x, y = db.coverX or -22, db.coverY or 48
    if IsHoriz() then x, y = -y, x end            -- en horizontal el modelo se tumba 90º
    cover:SetPoint("CENTER", f, "CENTER", x, y)
    cover:SetSize(db.coverSize or 34, db.coverSize or 34)
end


local function ModelHasFile(m)
    if not m.GetModelFileID then return m._loadedId ~= nil end
    local ok, fid = pcall(m.GetModelFileID, m)
    return ok and fid ~= nil and fid ~= 0
end

local function SetupModel(m, level, col, mirror)
    -- cargar el objeto solo si cambia o si el modelo se ha quedado vacío (recargar = parpadeo)
    local id = db.modelItem or 22691
    local ok, err = true, nil
    if m._loadedId ~= id or not ModelHasFile(m) then
        ok, err = pcall(m.SetItem, m, id)
        if not ok and m.SetItemAppearance then ok, err = pcall(m.SetItemAppearance, m, id) end
        if not ok and m.SetDisplayInfo and db.modelDisplay then ok, err = pcall(m.SetDisplayInfo, m, db.modelDisplay) end
        if ok then m._loadedId = id end
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
    -- luz: apagada para la base, del color del sello para la parte cargada
    -- aspecto según las cargas:
    --   0-1: gris y tenue · 2: casi a oscuras para que destaquen sus brillos propios (la calavera)
    --   3: completamente iluminado
    level = tonumber(level) or 0
    col = col or { 1, 1, 1 }
    local r, g, b, amb, dif, desat
    if level >= 3 then
        r, g, b = 0.85 + 0.15 * col[1], 0.85 + 0.15 * col[2], 0.85 + 0.15 * col[3]
        amb, dif, desat = 1.0, 1.0, 0
    elseif level == 2 then
        r, g, b = 0.85 + 0.15 * col[1], 0.85 + 0.15 * col[2], 0.85 + 0.15 * col[3]
        amb, dif, desat = 0.85, 0.85, 0
    else
        r, g, b = 0.55, 0.55, 0.60
        amb, dif, desat = 0.25, 0.20, 1
    end
    local okL = pcall(m.SetLight, m, true, { omnidirectional = false, point = CreateVector3D and CreateVector3D(-1, 1, -1) or nil,
        ambientIntensity = amb, ambientColor = CreateColor and CreateColor(r, g, b) or nil,
        diffuseIntensity = dif, diffuseColor = CreateColor and CreateColor(r, g, b) or nil })
    if not okL then okL = pcall(m.SetLight, m, true, false, -1, 1, -1, amb, r, g, b, dif, r, g, b) end
    if m.SetDesaturation then pcall(m.SetDesaturation, m, desat) end
    -- la niebla no hace efecto en Forever: se quita por si quedó puesta
    if m.ClearFog then pcall(m.ClearFog, m) end
    -- efectos de partículas del modelo (el brillo de la calavera): solo con 3 cargas
    if m.SetParticlesEnabled then pcall(m.SetParticlesEnabled, m, level >= 3) end
    -- los modelos 3D no heredan la opacidad del marco: se aplica aparte
    if m.SetModelAlpha then pcall(m.SetModelAlpha, m, db.alpha or 0.25) end
    pcall(m.SetAlpha, m, db.alpha or 0.25)
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
local piecesKey
local function PlacePieces(force)
    local W, H = model:GetWidth(), model:GetHeight()
    local key = table.concat({ W, H, db.coverX or -22, db.coverY or 48, db.coverSize or 34,
        db.holeShape or "cuadrado", IsHoriz() and 1 or 0 }, ":")
    if not force and key == piecesKey then return end
    piecesKey = key
    local x, y = db.coverX or -22, db.coverY or 48
    if IsHoriz() then x, y = -y, x end
    local hs = (db.coverSize or 34) / 2
    -- hueco en coordenadas del modelo (origen arriba a la izquierda)
    local l, r = W / 2 + x - hs, W / 2 + x + hs
    local t, b = H / 2 - y - hs, H / 2 - y + hs
    l, r = math.max(0, l), math.min(W, r)
    t, b = math.max(0, t), math.min(H, b)
    -- hueco circular: arriba y abajo enteros; en medio, franjas cortadas a la anchura del círculo
    local cxh, cyh = (l + r) / 2, (t + b) / 2
    local rects = { { 0, 0, W, t }, { 0, b, W, H - b } }
    local rowH = (b - t) / HOLE_ROWS
    for k = 0, HOLE_ROWS - 1 do
        local y0 = t + k * rowH
        local ym = y0 + rowH / 2
        local dy = math.abs(ym - cyh)
        local half
        if db.holeShape == "circulo" then half = (dy < hs) and math.sqrt(hs * hs - dy * dy) or 0
        else half = hs end                                  -- cuadrado
        local hl, hr = math.max(0, cxh - half), math.min(W, cxh + half)
        rects[#rects + 1] = { 0, y0, hl, rowH }          -- a la izquierda del círculo
        rects[#rects + 1] = { hr, y0, W - hr, rowH }     -- a la derecha del círculo
    end
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
    SetupPieces(level or 0, col)
    if not modelInfoLogged then
        modelInfoLogged = true
        Log("modelo 3D objeto " .. tostring(db.modelItem) .. ": " .. (ok and "cargado" or ("ERROR " .. D(err))) ..
            " | luz=" .. tostring(okL) .. 
            " | recorte=" .. tostring(modelClip.SetClipsChildren ~= nil) ..
            " | SetPitch=" .. tostring(model.SetPitch ~= nil) .. " | SetRoll=" .. tostring(model.SetRoll ~= nil) ..
            " | SetDesaturation=" .. tostring(model.SetDesaturation ~= nil) ..
            " | partículas=" .. tostring(model.SetParticlesEnabled ~= nil))
    end
end
model:SetScript("OnShow", function() SetupModel(model, curLevel or 0, curCol) end)


local moonParts = { moonBg, moonFrame }
local swordParts = { swordBg, swordFill, swordTint }

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
local function PlaceCrop(tex, a0, a1)
    a0, a1 = a0 or 0, a1 or 1
    tex:ClearAllPoints()
    local W, H = f:GetWidth(), f:GetHeight()
    if IsHoriz() then
        tex:SetPoint("TOPLEFT", f, "TOPLEFT", W * a0, 0)
        tex:SetSize(math.max(W * (a1 - a0), 0.01), H)
        tex:SetTexCoord(0, 1 - a0, 1, 1 - a0, 0, 1 - a1, 1, 1 - a1)
    else
        tex:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -H * a0)
        tex:SetSize(W, math.max(H * (a1 - a0), 0.01))
        tex:SetTexCoord(0, 1, a0, a1)
    end
end

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

-- Encuadre del modelo 3D por orientación: uno para vertical y otro para horizontal
local PROFILE_KEYS = { "modelFacing", "modelPitch", "modelRoll", "modelZoom", "modelY",
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
    db.prof = db.prof or {}
    local want = PROFILE_DEFAULTS[db.fillDir] and db.fillDir or "arriba"
    if db._prof == want then return end
    if db._prof then                                   -- guardar lo que había en la orientación anterior
        db.prof[db._prof] = db.prof[db._prof] or {}
        for _, k in ipairs(PROFILE_KEYS) do db.prof[db._prof][k] = db[k] end
    end
    local p = db.prof[want] or PROFILE_DEFAULTS[want]
    for _, k in ipairs(PROFILE_KEYS) do
        local v = p[k]; if v == nil then v = PROFILE_DEFAULTS[want][k] end
        db[k] = v                                     -- (m* sin ajustar quedan en nil)
    end
    db._prof = want
end

local function ApplyStyle()
    if db.style == "ashbringer" then db.style = "espada" end
    SyncProfile()
    if not STYLES[db.style] then db.style = "luna" end
    local st = STYLES[db.style]
    local isSword = db.style == "espada"
    local isModel = db.style == "modelo"
    for _, p in ipairs(moonParts) do p:SetShown(db.style == "luna") end
    swordBg:SetShown(isSword)
    if not isSword then swordFill:Hide(); swordTint:Hide() end
    if db.style ~= "luna" then for i = 1, 3 do fill[i]:Hide() end end
    local horiz = IsHoriz()
    f:SetSize(horiz and 256 or 128, horiz and 128 or 256)
    for _, t in ipairs({ moonBg, moonFrame, fill[1], fill[2], fill[3], swordBg }) do PlaceCrop(t, 0, 1) end
    model:ClearAllPoints()
    model:SetSize(horiz and 270 or 150, horiz and 150 or 270)
    model:SetPoint("CENTER", f, "CENTER", 0, 0)
    model:SetShown(isModel)
    modelClip:SetShown(false)
    PlaceCover()
    cover:Hide()
    PlacePieces(true)
    if not isModel then ShowPieces(false) end
    if isModel then LoadModel() end
    flame:SetTexture(MEDIA .. st.flame .. (horiz and "_h" or ""))
    flame:SetSize(horiz and 512 or 256, horiz and 256 or 512)
    flame:SetTexCoord(0, 1 / FLAME_FRAMES, 0, 1)
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
    f:SetAlpha(db.alpha or 0.25)
    fi:SetToAlpha(db.alpha or 0.25)
    if model.SetModelAlpha then pcall(model.SetModelAlpha, model, db.alpha or 0.25) end
end

------------------------------------------------------------
-- Lógica
------------------------------------------------------------
local shownStacks = 0
local expiresAt = 0
local testMode = false

local function ShowMoon(kind, tex, count, exp)
    count = math.min(count, 3)
    local c = (db.colors and db.colors[kind]) or SEALS[kind].color
    if db.style == "modelo" then
        local key = kind .. ":" .. count
        if modelClip.lastColor ~= key then
            modelClip.lastColor = key
            SetupModel(model, count, c)
            SetupPieces(count, c)
        end
        -- hueco transparente en la calavera hasta tener 3 cargas: el modelo se dibuja en 4 trozos
        local hole = db.coverOn ~= false and count < 3
        PlacePieces()
        curLevel, curCol = count, c
        if hole then
            if model:IsShown() then model:Hide() end
            ShowPieces(true)
        else
            if not model:IsShown() then model:Show() end   -- primero el entero, luego quitar trozos: sin hueco intermedio
            ShowPieces(false)
        end
        -- desbloqueado: un marco tenue marca dónde está el hueco para poder arrastrarlo
        if f.unlocked and db.style == "modelo" then
            local circ = db.holeShape == "circulo"
            cover.tex:SetShown(circ); cover.sq:SetShown(not circ)
            cover.tex:SetVertexColor(1, 1, 1); cover:SetAlpha(0.8); cover:Show()
        else
            cover:Hide()
        end
        modelClip:Hide()
    elseif db.style == "espada" then
        local frac = count / 3
        local L = (SWORD_BOTTOM - SWORD_TOP) * frac
        local a0, a1
        if db.fillDir == "abajo" then          a0, a1 = 0, SWORD_TOP + L                 -- desde la punta
        elseif db.fillDir == "derecha" then    a0, a1 = 0, (1 - SWORD_BOTTOM) + L        -- empuñadura a la izquierda
        elseif db.fillDir == "izquierda" then  a0, a1 = (1 - SWORD_TOP) - L, 1           -- desde la punta (derecha)
        else                                   a0, a1 = SWORD_BOTTOM - L, 1 end          -- desde la empuñadura
        PlaceCrop(swordFill, a0, a1)
        PlaceCrop(swordTint, a0, a1)
        swordTint:SetVertexColor(c[1], c[2], c[3])
        swordFill:SetShown(count > 0)
        swordTint:SetShown(count > 0)
    else
        local rev = db.fillDir == "abajo" or db.fillDir == "izquierda"
        for i = 1, 3 do
            local seg = rev and (4 - i) or i
            fill[seg]:SetVertexColor(c[1], c[2], c[3])
            fill[seg]:SetShown(i <= count)
        end
    end
    flame:SetVertexColor(c[1], c[2], c[3])
    icon:SetTexture(SealIcon(kind))
    expiresAt = exp or 0

    if not f:IsShown() then
        f:Show()
        fadeIn:Play()
    end

    local full = count >= 3
    flame:SetShown(full)
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
local mFlame = M:CreateTexture(nil, "BORDER"); mFlame:SetBlendMode("ADD"); mFlame:SetPoint("CENTER", M, "CENTER"); mFlame:Hide()
local mMoonBg = M:CreateTexture(nil, "BACKGROUND"); mMoonBg:SetTexture(MEDIA .. "moon_bg")
local mFill = {}
for i = 1, 3 do
    local t = mLit:CreateTexture(nil, "ARTWORK"); t:SetTexture(MEDIA .. "moon" .. i); t:Hide(); mFill[i] = t
end
local mMoonFrame = mTop:CreateTexture(nil, "ARTWORK"); mMoonFrame:SetTexture(MEDIA .. "moon_frame")
local mSwordBg = M:CreateTexture(nil, "BACKGROUND"); mSwordBg:SetTexture(MEDIA .. "sword_art")
mSwordBg:SetDesaturated(true); mSwordBg:SetVertexColor(0.38, 0.38, 0.40)
local mSwordFill = mLit:CreateTexture(nil, "ARTWORK"); mSwordFill:SetTexture(MEDIA .. "sword_art")
local mSwordTint = mLit:CreateTexture(nil, "OVERLAY"); mSwordTint:SetTexture(MEDIA .. "sword_mask")
mSwordTint:SetBlendMode("ADD"); mSwordTint:SetAlpha(0.30)
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
    a0, a1 = a0 or 0, a1 or 1
    tex:ClearAllPoints()
    local W, H = M:GetWidth(), M:GetHeight()
    if IsHoriz() then
        local t0, t1 = 1 - a1, 1 - a0
        tex:SetPoint("TOPLEFT", M, "TOPLEFT", W * t0, 0)
        tex:SetSize(math.max(W * (t1 - t0), 0.01), H)
        tex:SetTexCoord(0, t0, 1, t0, 0, t1, 1, t1)
    else
        tex:SetPoint("TOPLEFT", M, "TOPLEFT", 0, -H * a0)
        tex:SetSize(W, math.max(H * (a1 - a0), 0.01))
        tex:SetTexCoord(1, 0, a0, a1)
    end
end

local function MirrorPlacePieces(force)
    local W, H = mModel:GetWidth(), mModel:GetHeight()
    local key = table.concat({ W, H, MirrorVal("mCoverX"), MirrorVal("mCoverY"), db.coverSize or 34,
        db.holeShape or "cuadrado", IsHoriz() and 1 or 0 }, ":")
    if not force and key == mPiecesKey then return end
    mPiecesKey = key
    local x, y = MirrorVal("mCoverX"), MirrorVal("mCoverY")   -- hueco propio de la copia
    if IsHoriz() then x, y = -y, x end
    local hs = (db.coverSize or 34) / 2
    local l, r = math.max(0, W / 2 + x - hs), math.min(W, W / 2 + x + hs)
    local t, b = math.max(0, H / 2 - y - hs), math.min(H, H / 2 - y + hs)
    local cxh, cyh = (l + r) / 2, (t + b) / 2
    local rects = { { 0, 0, W, t }, { 0, b, W, H - b } }
    local rowH = (b - t) / HOLE_ROWS
    for k = 0, HOLE_ROWS - 1 do
        local y0 = t + k * rowH
        local dy = math.abs(y0 + rowH / 2 - cyh)
        local half = (db.holeShape == "circulo") and ((dy < hs) and math.sqrt(hs * hs - dy * dy) or 0) or hs
        local hl, hr = math.max(0, cxh - half), math.min(W, cxh + half)
        rects[#rects + 1] = { 0, y0, hl, rowH }
        rects[#rects + 1] = { hr, y0, W - hr, rowH }
    end
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
    for _, t in ipairs({ mMoonBg, mMoonFrame, mFill[1], mFill[2], mFill[3], mSwordBg }) do MirrorCrop(t, 0, 1) end
    local isLuna, isSword, isModel = db.style == "luna", db.style == "espada", db.style == "modelo"
    mMoonBg:SetShown(isLuna); mMoonFrame:SetShown(isLuna)
    if not isLuna then for i = 1, 3 do mFill[i]:Hide() end end
    mSwordBg:SetShown(isSword)
    if not isSword then mSwordFill:Hide(); mSwordTint:Hide() end
    mModel:ClearAllPoints()
    mModel:SetSize(horiz and 270 or 150, horiz and 150 or 270)
    mModel:SetPoint("CENTER", M, "CENTER", 0, 0)
    mModel:SetShown(isModel)
    if not isModel then MirrorShowPieces(false) end
    MirrorPlacePieces(true)
    mKey = nil
    local st = STYLES[db.style] or STYLES.luna
    mFlame:SetTexture(MEDIA .. st.flame .. (horiz and "_h" or ""))
    mFlame:SetSize(horiz and 512 or 256, horiz and 256 or 512)
end

local function MirrorShow(kind, count)
    if not db.mirror then M:Hide(); return end
    count = math.min(count or 0, 3)
    local c = (db.colors and db.colors[kind]) or SEALS[kind].color
    if db.style == "modelo" then
        mLevel, mCol = count, c
        local key = kind .. ":" .. count
        if mKey ~= key then
            mKey = key
            SetupModel(mModel, count, c, true)
            for _, p in ipairs(mPieces) do SetupModel(p.m, count, c, true) end
        end
        if mModel.SetModelAlpha then pcall(mModel.SetModelAlpha, mModel, db.alpha or 0.25) end
        local hole = db.coverOn ~= false and count < 3
        MirrorPlacePieces()
        local mx, my = MirrorVal("mCoverX"), MirrorVal("mCoverY")
        if IsHoriz() then mx, my = -my, mx end
        mMarker:ClearAllPoints()
        mMarker:SetPoint("CENTER", M, "CENTER", mx, my)
        mMarker:SetSize(db.coverSize or 34, db.coverSize or 34)
        mMarker:SetShown(f.unlocked == true)
        if hole then
            if mModel:IsShown() then mModel:Hide() end
            MirrorShowPieces(true)
        else
            if not mModel:IsShown() then mModel:Show() end
            MirrorShowPieces(false)
        end
    elseif db.style == "espada" then
        local L = (SWORD_BOTTOM - SWORD_TOP) * (count / 3)
        local a0, a1
        if db.fillDir == "abajo" then          a0, a1 = 0, SWORD_TOP + L
        elseif db.fillDir == "derecha" then    a0, a1 = 0, (1 - SWORD_BOTTOM) + L
        elseif db.fillDir == "izquierda" then  a0, a1 = (1 - SWORD_TOP) - L, 1
        else                                   a0, a1 = SWORD_BOTTOM - L, 1 end
        MirrorCrop(mSwordFill, a0, a1); MirrorCrop(mSwordTint, a0, a1)
        mSwordTint:SetVertexColor(c[1], c[2], c[3])
        mSwordFill:SetShown(count > 0); mSwordTint:SetShown(count > 0)
    else
        local rev = db.fillDir == "abajo" or db.fillDir == "izquierda"
        for i = 1, 3 do
            local seg = rev and (4 - i) or i
            mFill[seg]:SetVertexColor(c[1], c[2], c[3])
            mFill[seg]:SetShown(i <= count)
        end
    end
    mFlame:SetVertexColor(c[1], c[2], c[3])
    mFlame:SetShown(count >= 3)
    MirrorPosition()
    M:Show()
end

local mFlameT, mPosT = 0, 0
M:SetScript("OnUpdate", function(self, elapsed)
    if mFlame:IsShown() then
        mFlameT = mFlameT + elapsed
        local fr = math.floor(mFlameT * FLAME_FPS) % FLAME_FRAMES
        mFlame:SetTexCoord((fr + 1) / FLAME_FRAMES, fr / FLAME_FRAMES, 0, 1)   -- llamas en espejo
    end
    mPosT = mPosT + elapsed
    if mPosT > 0.1 then mPosT = 0; MirrorPosition() end      -- sigue a la principal si la mueves
end)

-- enganchar la copia a las funciones de la principal
do
    local _apply, _show, _hide, _pos = ApplyStyle, ShowMoon, HideMoon, ApplyPosition
    ApplyStyle = function(...) _apply(...); MirrorApplyStyle() end
    ShowMoon = function(kind, tex, count, exp) _show(kind, tex, count, exp); MirrorShow(kind, count) end
    HideMoon = function(...) _hide(...); if not f:IsShown() then M:Hide() end end
    ApplyPosition = function(...) _pos(...); M:SetScale(db.scale or 1); M:SetAlpha(db.alpha or 0.25); MirrorPosition() end
end

local UWSetSeal, UWSync   -- se definen más abajo
local RegisterSettingsPanel  -- se define con el menú

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
        if not uw.warned and PW_Print then
            uw.warned = true
            PW_Print("En combate no encuentro el icono de Unsealed Wrath. Abre el Cooldown Manager > Beneficios rastreados y añade Unsealed Wrath.")
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
        flame:SetTexCoord(fr / FLAME_FRAMES, (fr + 1) / FLAME_FRAMES, 0, 1)
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

ev:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        PallyWrathDB = PallyWrathDB or {}
        db = PallyWrathDB
        CopyDefaults(DEFAULTS, db)
        db.log = {}   -- registro nuevo en cada carga
        if (db.alphaV or 0) < 2 then db.alpha = 0.25; db.alphaV = 2 end   -- nueva opacidad base
        if (db.facingV or 0) < 3 then          -- encuadre base del modelo (el que eligió Julen)
            db.modelFacing, db.modelPitch, db.modelRoll = 0, 255, 90
            db.modelZoom, db.modelY = 1.0, 0.1
            db.facingV = 3
        end
        if (db.coverV or 0) < 3 then           -- hueco de la calavera ajustado por Julen (cuadrado)
            db.coverX, db.coverY, db.coverSize, db.holeShape = -22, 48, 34, "cuadrado"
            db.coverV = 3
        end
        if (db.styleV or 0) < 1 then db.style = "espada"; db.styleV = 1 end   -- estilo base: Espada
        if (db.profV or 0) < 2 then            -- encuadres base (uno por dirección) elegidos por Julen
            db.prof = {}
            for o, p in pairs(PROFILE_DEFAULTS) do
                db.prof[o] = {}
                for k, v in pairs(p) do db.prof[o][k] = v end
            end
            db._prof = nil
            db.profV = 2
        end
        if (db.profV or 0) < 3 then            -- encuadre base de "hacia la izquierda" (Julen)
            db.prof = db.prof or {}
            db.prof.izquierda = {}
            for k, v in pairs(PROFILE_DEFAULTS.izquierda) do db.prof.izquierda[k] = v end
            if db._prof == "izquierda" then db._prof = nil end   -- recargar si está en uso
            db.profV = 3
        end
        if (db.profV or 0) < 4 then            -- restaurar las 4 direcciones con los valores de Julen
            db.prof = {}
            for o, p in pairs(PROFILE_DEFAULTS) do
                db.prof[o] = {}
                for k, v in pairs(p) do db.prof[o][k] = v end
            end
            db._prof = nil
            db.profV = 4
        end
        if (db.profV or 0) < 5 then            -- encuadre nuevo de "hacia arriba" (Julen); el resto se conserva
            db.prof = db.prof or {}
            db.prof.arriba = {}
            for k, v in pairs(PROFILE_DEFAULTS.arriba) do db.prof.arriba[k] = v end
            if db._prof == "arriba" then db._prof = nil end
            db.profV = 5
        end
        pcall(RegisterSettingsPanel)
        ApplyStyle()
        ApplyPosition()
        local _, class = UnitClass("player")
        if class ~= "PALADIN" then
            self:UnregisterEvent("UNIT_AURA")
        end
    elseif event == "PLAYER_ENTERING_WORLD" and not welcomed then
        Welcome()
        if db then Scan() end
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

local opt
local function SealColor(kind) return (db.colors and db.colors[kind]) or SEALS[kind].color end

local function OpenColorPicker(kind, swatch)
    local c = SealColor(kind)
    local old = { c[1], c[2], c[3] }
    local function apply(r, g, b)
        db.colors[kind] = { r, g, b }
        swatch:SetColorTexture(r, g, b)
        if f:IsShown() then ShowMoon(kind, nil, 3, GetTime() + 15) end
    end
    local function onChange()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        apply(r, g, b)
    end
    local function onCancel() apply(old[1], old[2], old[3]) end
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

local function BuildOptions()
    opt = CreateFrame("Frame", "PallyWrathOptions", UIParent, "BasicFrameTemplateWithInset")
    opt:SetSize(330, 700)
    opt:SetPoint("CENTER")
    opt:SetFrameStrata("DIALOG")
    opt:SetMovable(true)
    opt:EnableMouse(true)
    opt:RegisterForDrag("LeftButton")
    opt:SetScript("OnDragStart", opt.StartMoving)
    opt:SetScript("OnDragStop", opt.StopMovingOrSizing)
    opt:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "PallyWrathOptions")   -- se cierra con Esc
    local title = rawget(opt, "TitleText")
    if type(title) ~= "table" then
        title = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText(TR("|cffF58CBAPally Wrath|r - Opciones"))

    local y = -36
    local P = opt   -- contenedor actual (opt o la caja del modelo)
    local function Header(text)
        local h = P:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 18, y)
        h:SetText(TR(text))
        y = y - 22
        return h
    end
    local function Button(text, w, x, onClick)
        local b = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(TR(text))
        b:SetScript("OnClick", onClick)
        return b
    end

    -- Estilo
    Header("Estilo")
    opt.styleBtns = {}
    local x = 18
    for _, key in ipairs({ "luna", "espada", "modelo" }) do
        local b = Button(STYLES[key].name, 96, x, function()
            db.style = key
            ApplyStyle()
            opt:Refresh()
            RunTest(uw and uw.seal or "command")
        end)
        opt.styleBtns[key] = b
        x = x + 100
    end
    y = y - 34

    -- Dirección de carga
    Header("Dirección de carga")
    opt.dirBtns = {}
    local DIRS = { { "arriba", "Hacia arriba" }, { "abajo", "Hacia abajo" },
                   { "derecha", "Hacia la derecha" }, { "izquierda", "Hacia la izquierda" } }
    for i, d in ipairs(DIRS) do
        local col = (i - 1) % 2
        if i == 3 then y = y - 26 end
        local b = Button(d[2], 144, 18 + col * 150, function()
            db.fillDir = d[1]
            ApplyStyle()
            opt:Refresh()
            RunTest(uw and uw.seal or "command")
        end)
        opt.dirBtns[d[1]] = b
    end
    y = y - 34

    -- Tamaño y cargas mínimas
    local function Stepper(label, get, set, minV, maxV, step, fmt)
        local l = P:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        l:SetPoint("TOPLEFT", 18, y - 4)
        l:SetText(TR(label))
        local v = P:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        v:SetPoint("TOPLEFT", 236, y - 4)
        local minus = Button("-", 26, 200, function()
            set(math.max(minV, math.floor((get() - step) * 100 + 0.5) / 100)); opt:Refresh()
        end)
        local plus = Button("+", 26, 280, function()
            set(math.min(maxV, math.floor((get() + step) * 100 + 0.5) / 100)); opt:Refresh()
        end)
        y = y - 30
        return function() v:SetText(string.format(fmt, get())) end
    end
    Header("Indicador")
    opt.refreshScale = Stepper("Tamaño", function() return db.scale end,
        function(v) db.scale = v; ApplyPosition() end, 0.5, 2.5, 0.1, "%.1f")
    opt.refreshMin = Stepper("Aparece desde (cargas)", function() return db.minStacks end,
        function(v) db.minStacks = v; Scan() end, 1, 3, 1, "%d")

    -- Barra de opacidad
    do
        local l = P:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        l:SetPoint("TOPLEFT", 18, y - 4)
        l:SetText(TR("Opacidad"))
        local val = P:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        val:SetPoint("TOPLEFT", 270, y - 4)
        local sl = CreateFrame("Slider", nil, P)
        sl:SetOrientation("HORIZONTAL")
        sl:SetSize(150, 16)
        sl:SetPoint("TOPLEFT", 108, y - 2)
        sl:SetMinMaxValues(0.2, 1)
        sl:SetValueStep(0.05)
        if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
        local track = sl:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("LEFT", 0, 0); track:SetPoint("RIGHT", 0, 0); track:SetHeight(6)
        track:SetColorTexture(0.12, 0.12, 0.14, 1)
        local trackB = sl:CreateTexture(nil, "BORDER")
        trackB:SetPoint("TOPLEFT", track, -1, 1); trackB:SetPoint("BOTTOMRIGHT", track, 1, -1)
        trackB:SetColorTexture(0.75, 0.6, 0.25, 1)
        trackB:SetDrawLayer("BACKGROUND", -1)
        local thumb = sl:CreateTexture(nil, "ARTWORK")
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        thumb:SetSize(32, 32)
        sl:SetThumbTexture(thumb)
        sl:EnableMouseWheel(true)
        sl:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * 0.05) end)
        sl:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v * 20 + 0.5) / 20
            db.alpha = v
            val:SetText(string.format("%d%%", v * 100))
            ApplyPosition()
            if not f:IsShown() and not InCombatLockdown() then RunTest(uw and uw.seal or "command") end
        end)
        opt.refreshAlpha = function()
            sl:SetValue(db.alpha or 0.8)
            val:SetText(string.format("%d%%", (db.alpha or 0.8) * 100))
        end
        y = y - 32
    end

    -- Casillas
    local function Check(label, get, set)
        local c = CreateFrame("CheckButton", nil, P, "UICheckButtonTemplate")
        c:SetPoint("TOPLEFT", 14, y)
        c:SetSize(26, 26)
        local t = rawget(c, "Text") or rawget(c, "text")
        if type(t) ~= "table" then
            t = P:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            t:SetPoint("LEFT", c, "RIGHT", 2, 0)
        end
        t:SetText(TR(label))
        c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); opt:Refresh() end)
        y = y - 28
        return function() c:SetChecked(get()) end
    end
    opt.refreshSound = Check("Sonido al llegar a 3 cargas", function() return db.sound end,
        function(v) db.sound = v end)
    opt.refreshViewer = Check("Ocultar el visor de beneficios de Blizzard (sigue activo)", function() return db.hideViewer ~= false end,
        function(v) db.hideViewer = v; PW_ApplyViewer() end)
    opt.refreshLock = Check("Desbloquear para moverlo (arrastrar)", function() return f.unlocked == true end,
        function(v) SetLocked(not v) end)
    opt.refreshMirror = Check("Copia simétrica al otro lado del personaje", function() return db.mirror == true end,
        function(v) db.mirror = v; ApplyStyle(); RunTest(uw and uw.seal or "command") end)
    opt.refreshIcon = Check("Mostrar el icono del sello", function() return db.showIcon ~= false end,
        function(v) db.showIcon = v; ApplyStyle(); if not f:IsShown() then RunTest(uw and uw.seal or "command") end end)
    local hintIcon = P:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintIcon:SetPoint("TOPLEFT", 42, y + 4)
    hintIcon:SetText(TR("Desbloqueado, el icono se arrastra por separado."))
    hintIcon:SetWidth(165); hintIcon:SetJustifyH("LEFT")
    Button("Recolocar icono", 120, 190, function()
        db.iconOffset = nil; ApplyStyle()
        if not f:IsShown() then RunTest(uw and uw.seal or "command") end
    end)
    y = y - 30
    y = y - 6

    -- Colores
    Header("Colores de cada sello")
    opt.swatches = {}
    for i, kind in ipairs(SEAL_ORDER) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local bx, by = 18 + col * 150, y - row * 30
        local b = CreateFrame("Button", nil, P)
        b:SetSize(22, 22)
        b:SetPoint("TOPLEFT", bx, by)
        local border = b:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0, 0, 0, 1)
        local sw = b:CreateTexture(nil, "ARTWORK")
        sw:SetPoint("TOPLEFT", 2, -2)
        sw:SetPoint("BOTTOMRIGHT", -2, 2)
        local l = P:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        l:SetPoint("LEFT", b, "RIGHT", 6, 0)
        l:SetText(TR(SEAL_LABEL[kind]))
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                db.colors[kind] = nil
                opt:Refresh()
            else
                OpenColorPicker(kind, sw)
            end
        end)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(TR("Clic: cambiar color\nClic derecho: color original"))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        opt.swatches[kind] = sw
    end
    y = y - 96

    -- Acciones
    Button("Probar", 92, 18, function() RunTest(uw and uw.seal or "command") end)
    Button("Centrar", 92, 118, function()
        db.point = { "CENTER", "UIParent", "CENTER", 120, -20 }; ApplyPosition()
    end)
    Button("Restablecer", 92, 218, function()
        local log = db.log
        wipe(db)
        CopyDefaults(DEFAULTS, db)
        db.log = log
        ApplyStyle(); ApplyPosition(); opt:Refresh()
    end)
    y = y - 34
    local hint = P:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 18, y)
    hint:SetWidth(294)
    hint:SetJustifyH("LEFT")
    hint:SetText(TR("En combate las cargas se cuentan con el icono de Unsealed Wrath del visor de buffs de Blizzard: no lo quites de allí. /pw ayuda: lista de comandos."))
    y = y - 44
    opt.baseHeight = -y + 10

    -- Sección del modelo 3D: solo visible con el estilo "Modelo 3D"
    local box = CreateFrame("Frame", nil, opt)
    box:SetPoint("TOPLEFT", opt, "TOPLEFT", 0, y)
    box:SetSize(330, 10)
    opt.modelBox = box
    local yBox0 = y
    y = 0
    P = box
    Header("Modelo 3D (encuadre)")
    Button("Espada principal...", 140, 18, function() ToggleModelWindow("main") end)
    Button("Copia simétrica...", 140, 168, function() ToggleModelWindow("copy") end)
    y = y - 30
    local note = P:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 18, y)
    note:SetWidth(294); note:SetJustifyH("LEFT")
    note:SetText(TR("Cada ventana guarda el encuadre de la dirección de carga elegida."))
    y = y - 18
    opt.refreshFacing = function() if RefreshModelWindows then RefreshModelWindows() end end
    box:SetHeight(-y + 10)
    opt.boxHeight = -y + 10
    P = opt
    y = yBox0

    function opt:Refresh()
        local showModel = db.style == "modelo"
        self.modelBox:SetShown(showModel)
        self:SetHeight(self.baseHeight + (showModel and self.boxHeight or 0))
        for key, b in pairs(self.styleBtns) do
            if key == db.style then b:LockHighlight() else b:UnlockHighlight() end
            b:SetText((key == db.style and "> " or "") .. TR(STYLES[key].name) .. (key == db.style and " <" or ""))
        end
        for key, b in pairs(self.dirBtns) do
            if key == db.fillDir then b:LockHighlight() else b:UnlockHighlight() end
        end
        self.refreshScale(); self.refreshMin(); self.refreshFacing(); self.refreshAlpha(); self.refreshSound(); self.refreshLock(); self.refreshIcon(); self.refreshMirror()
        for kind, sw in pairs(self.swatches) do
            local c = SealColor(kind)
            sw:SetColorTexture(c[1], c[2], c[3])
        end
    end
    opt:SetScript("OnShow", function(self) self:Refresh() end)
    opt:SetScript("OnHide", function() for _, w in pairs(modelWins) do w:Hide() end end)
    opt:Hide()
end

------------------------------------------------------------
-- Ventanas de ajuste del Modelo 3D (principal y copia), con barras deslizantes
------------------------------------------------------------
local lastShow
do
    local _s = ShowMoon
    ShowMoon = function(kind, tex, count, exp) lastShow = { kind, tex, count, exp }; _s(kind, tex, count, exp) end
end

local function SettingsChanged()
    ApplyStyle()
    modelClip.lastColor = nil
    if f:IsShown() and lastShow then
        ShowMoon(lastShow[1], lastShow[2], lastShow[3], lastShow[4])
    elseif not (InCombatLockdown and InCombatLockdown()) and db.style == "modelo" then
        RunTest(uw and uw.seal or "command")
    end
end

local DIR_NAME = { arriba = "hacia arriba", abajo = "hacia abajo", derecha = "hacia la derecha", izquierda = "hacia la izquierda" }

local function MakeSliderRow(parent, y, label, minV, maxV, step, fmt, get, set)
    local row = {}
    local l = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    l:SetPoint("TOPLEFT", 14, y)
    l:SetText(TR(label))
    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("TOPRIGHT", -14, y)
    local sl = CreateFrame("Slider", nil, parent)
    sl:SetOrientation("HORIZONTAL")
    sl:SetSize(220, 16)
    sl:SetPoint("TOPLEFT", 40, y - 18)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    local track = sl:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(6)
    track:SetColorTexture(0.12, 0.12, 0.14, 1)
    local edge = sl:CreateTexture(nil, "BACKGROUND", nil, -1)
    edge:SetPoint("TOPLEFT", track, -1, 1); edge:SetPoint("BOTTOMRIGHT", track, 1, -1)
    edge:SetColorTexture(0.75, 0.6, 0.25, 1)
    local thumb = sl:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetSize(32, 32)
    sl:SetThumbTexture(thumb)
    local function round(v) return math.floor(v / step + 0.5) * step end
    local updating = false
    sl:SetScript("OnValueChanged", function(self, v)
        v = round(v)
        val:SetText(string.format(fmt, v))
        if updating then return end
        set(v)
        SettingsChanged()
    end)
    sl:EnableMouseWheel(true)
    sl:SetScript("OnMouseWheel", function(self, d) self:SetValue((self:GetValue() or get() or 0) + d * step) end)
    for i, sign in ipairs({ -1, 1 }) do
        local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        b:SetSize(22, 18)
        b:SetText(sign < 0 and "-" or "+")
        if sign < 0 then b:SetPoint("RIGHT", sl, "LEFT", -4, 0) else b:SetPoint("LEFT", sl, "RIGHT", 4, 0) end
        b:SetScript("OnClick", function()
            local cur = sl:GetValue() or get() or 0
            sl:SetValue(math.max(minV, math.min(maxV, cur + sign * step)))
        end)
    end
    row.refresh = function()
        updating = true
        local v = get() or 0
        sl:SetValue(v)
        val:SetText(string.format(fmt, v))
        updating = false
    end
    return row
end

local function BuildModelWindow(which)
    local isCopy = which == "copy"
    local wname = "PallyWrathModel" .. (isCopy and "Copy" or "Main")
    local w = CreateFrame("Frame", wname, UIParent, "BasicFrameTemplateWithInset")
    w:SetFrameStrata("DIALOG")
    w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", w.StartMoving); w:SetScript("OnDragStop", w.StopMovingOrSizing)
    w:SetClampedToScreen(true)
    tinsert(UISpecialFrames, wname)
    local title = rawget(w, "TitleText")
    if type(title) ~= "table" then title = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); title:SetPoint("TOP", 0, -5) end
    w.title = title
    local content = CreateFrame("Frame", nil, w)
    content:SetPoint("TOPLEFT", 0, -28); content:SetPoint("BOTTOMRIGHT")
    w.content = content
    local rows, y = {}, -6
    local function add(label, minV, maxV, step, fmt, get, set)
        rows[#rows + 1] = MakeSliderRow(content, y, label, minV, maxV, step, fmt, get, set)
        y = y - 46
    end
    if not isCopy then
        add("Giro", 0, 360, 5, "%dº", function() return db.modelFacing end, function(v) db.modelFacing = v % 360 end)
        add("Inclinación", 0, 360, 5, "%dº", function() return db.modelPitch end, function(v) db.modelPitch = v % 360 end)
        add("Rotación", 0, 360, 5, "%dº", function() return db.modelRoll end, function(v) db.modelRoll = v % 360 end)
        add("Zoom", 0.3, 4, 0.1, "%.1f", function() return db.modelZoom end, function(v) db.modelZoom = v end)
        add("Subir / bajar", -3, 3, 0.05, "%.2f", function() return db.modelY end, function(v) db.modelY = v end)
        add("Hueco calavera: tamaño", 10, 120, 1, "%d", function() return db.coverSize end, function(v) db.coverSize = v end)
        add("Hueco calavera: horizontal", -120, 120, 1, "%d", function() return db.coverX end, function(v) db.coverX = v end)
        add("Hueco calavera: vertical", -150, 150, 1, "%d", function() return db.coverY end, function(v) db.coverY = v end)
        local shape = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        shape:SetSize(140, 22); shape:SetPoint("TOPLEFT", 14, y)
        shape:SetScript("OnClick", function()
            db.holeShape = (db.holeShape == "circulo") and "cuadrado" or "circulo"
            SettingsChanged(); w:Refresh()
        end)
        rows[#rows + 1] = { refresh = function() shape:SetText(TR("Hueco: " .. (db.holeShape == "circulo" and "círculo" or "cuadrado"))) end }
        y = y - 30
    else
        add("Giro", 0, 360, 5, "%dº", function() return MirrorVal("mFacing") end, function(v) db.mFacing = v % 360 end)
        add("Inclinación", 0, 360, 5, "%dº", function() return MirrorVal("mPitch") end, function(v) db.mPitch = v % 360 end)
        add("Rotación", 0, 360, 5, "%dº", function() return MirrorVal("mRoll") end, function(v) db.mRoll = v % 360 end)
        add("Hueco calavera: horizontal", -120, 120, 1, "%d", function() return MirrorVal("mCoverX") end, function(v) db.mCoverX = v end)
        add("Hueco calavera: vertical", -150, 150, 1, "%d", function() return MirrorVal("mCoverY") end, function(v) db.mCoverY = v end)
        local note = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", 14, y); note:SetWidth(290); note:SetJustifyH("LEFT")
        note:SetText(TR("El tamaño del hueco y el zoom son los de la espada principal."))
        y = y - 24
    end
    w.fullH = -y + 40
    w:SetSize(330, w.fullH)
    -- plegar / desplegar
    local fold = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    fold:SetSize(22, 18); fold:SetPoint("TOPLEFT", 6, -3)
    fold:SetText("-")
    fold:SetScript("OnClick", function()
        w.folded = not w.folded
        content:SetShown(not w.folded)
        w:SetHeight(w.folded and 28 or w.fullH)
        fold:SetText(w.folded and "+" or "-")
    end)
    function w:Refresh()
        self.title:SetText(TR((isCopy and "Copia simétrica" or "Espada principal") .. " - " .. (DIR_NAME[db.fillDir] or "")))
        for _, r in ipairs(rows) do r.refresh() end
    end
    w:SetScript("OnShow", function(self) self:Refresh() end)
    -- colocar junto al menú de opciones
    w:ClearAllPoints()
    if opt then
        if isCopy then w:SetPoint("TOPLEFT", opt, "TOPRIGHT", 4, -340) else w:SetPoint("TOPLEFT", opt, "TOPRIGHT", 4, 0) end
    else
        w:SetPoint("CENTER", isCopy and 180 or -180, 0)
    end
    w:Hide()
    return w
end

ToggleModelWindow = function(which)
    if not modelWins[which] then modelWins[which] = BuildModelWindow(which) end
    local w = modelWins[which]
    if w:IsShown() then w:Hide() else w:Show() end
end

RefreshModelWindows = function()
    for _, w in pairs(modelWins) do if w:IsShown() then w:Refresh() end end
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
-- Comandos: /pw (también /pallywrath y /eco)
------------------------------------------------------------
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. TR(msg)) end
PW_Print = Print

------------------------------------------------------------
-- Cooldown Manager de Blizzard: es la única fuente de cargas en combate.
-- Lo encendemos si está apagado y, si se quiere, lo dejamos invisible
-- (transparente) pero activo, para que siga actualizando sus iconos.
------------------------------------------------------------
local VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
local viewerHooked, viewerGuard = {}, false

local function CanTouch(v)
    if not v then return false end
    if InCombatLockdown and InCombatLockdown() and v.IsProtected and v:IsProtected() then return false end
    return true
end

function PW_ApplyViewer()
    if not db then return end
    for _, name in ipairs(VIEWERS) do
        local v = _G[name]
        if v and CanTouch(v) then
            if not viewerHooked[v] then
                viewerHooked[v] = true
                hooksecurefunc(v, "SetAlpha", function(self, a)
                    if viewerGuard or not db or db.hideViewer == false then return end
                    if IsSecret(a) or a == 0 or not CanTouch(self) then return end
                    viewerGuard = true
                    pcall(self.SetAlpha, self, 0)
                    viewerGuard = false
                end)
            end
            viewerGuard = true
            pcall(v.SetAlpha, v, (db.hideViewer ~= false) and 0 or 1)
            viewerGuard = false
        end
    end
end

local function EnsureCooldownManager()
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then return end
    if not (C_CVar and C_CVar.GetCVar) then return end
    local ok, val = pcall(C_CVar.GetCVar, "cooldownViewerEnabled")
    Log("Cooldown Manager (cooldownViewerEnabled) = " .. D(val))
    if ok and val == "0" and not (InCombatLockdown and InCombatLockdown()) then
        local okS = pcall(C_CVar.SetCVar, "cooldownViewerEnabled", "1")
        Log("activar Cooldown Manager: ok=" .. tostring(okS))
        if okS then
            Print("Cooldown Manager activado: Pally Wrath lo necesita para contar cargas en combate.")
            if not _G.BuffIconCooldownViewer then Print("Si no ves el indicador en combate, haz /reload.") end
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
    if event == "PLAYER_ENTERING_WORLD" then pcall(EnsureCooldownManager) end
    C_Timer.After(0.5, function() pcall(PW_ApplyViewer) end)
end)

------------------------------------------------------------
-- SONDA: probar en combate vías que no dependan del Cooldown Manager
-- (/pw sonda). Escribe los resultados en el registro y muestra un
-- pequeño panel de prueba con el número "a ciegas".
------------------------------------------------------------
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

function PW_SondaToggle()
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

SLASH_PALLYWRATH1 = "/pw"
SLASH_PALLYWRATH2 = "/pallywrath"
SLASH_PALLYWRATH3 = "/eco"
SlashCmdList.PALLYWRATH = function(msg)
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
            if db.style == "modelo" then LoadModel(); modelClip.lastColor = nil end
            Print(cmd .. ": " .. (v % 360) .. "º")
        else
            Print("Uso: /pw " .. cmd .. " <grados>")
        end
    elseif cmd == "icono" then
        if a == "no" or a == "ocultar" then db.showIcon = false
        elseif a == "si" or a == "mostrar" then db.showIcon = true
        elseif a == "recolocar" or a == "reset" then db.iconOffset = nil
        else Print("Uso: /pw icono si | no | recolocar"); return end
        ApplyStyle()
        Print("Icono del sello: " .. (db.showIcon and "visible" or "oculto") .. (db.iconOffset and " (posición propia)" or ""))
    elseif cmd == "espejo" or cmd == "copia" then
        if a == "si" then db.mirror = true elseif a == "no" then db.mirror = false
        else db.mirror = not db.mirror end
        ApplyStyle()
        if db.mirror then RunTest(uw and uw.seal or "command") else M:Hide() end
        Print("Copia simétrica: " .. (db.mirror and "activada" or "desactivada"))
    elseif cmd == "giro" then
        local v = tonumber(a)
        if v then
            db.modelFacing = v % 360
            if db.style == "modelo" then LoadModel(); modelClip.lastColor = nil end
            Print("Giro del modelo: " .. db.modelFacing .. "º")
        else
            Print("Uso: /pw giro <grados>   (actual: " .. tostring(db.modelFacing) .. "º)")
        end
    elseif cmd == "objeto" then
        local id = tonumber(a)
        if id then
            db.modelItem = id
            if db.style == "modelo" then LoadModel(); modelClip.lastColor = nil end
            Print("Modelo 3D: objeto " .. id)
        else
            Print("Uso: /pw objeto <ID de objeto>   (actual: " .. tostring(db.modelItem) .. ")")
        end
    elseif cmd == "zoom" then
        local v = tonumber(a)
        if v and v > 0.2 and v < 5 then
            db.modelZoom = v
            if db.style == "modelo" then LoadModel(); modelClip.lastColor = nil end
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
        PW_ApplyViewer()
        Print("Visor de Blizzard: " .. (db.hideViewer ~= false and TR("oculto") or TR("visible")))
    elseif cmd == "sonda" or cmd == "probe" then
        PW_SondaToggle()
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
        ApplyStyle()
        ApplyPosition()
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
