local ADDON = ...
local PREFIX = "PallyWrathVer"
local SEND_INTERVAL = 15

local function ParseVersion(value)
    if (issecretvalue and issecretvalue(value)) or type(value) ~= "string" or #value > 11 then return end
    local major, minor, patch = value:match("^(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)$")
    if not major then return end
    major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
    return major * 1000000 + minor * 1000 + patch, ("%d.%d.%d"):format(major, minor, patch)
end

local function GroupChannel()
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function IsAvailable(channel)
    if channel == "GUILD" then return IsInGuild() end
    return channel ~= nil and channel == GroupChannel()
end

local channels = {}
local localVersion, localLabel, notified
local chat = C_ChatInfo

local function Schedule(channel, kind)
    if not IsAvailable(channel) then return end
    local state = channels[channel] or {}
    channels[channel] = state
    if kind == "H" or not state.pending then state.pending = kind end
    if state.scheduled or not state.pending then return end

    local delay = math.max(1 + math.random(), (state.lastSend or -SEND_INTERVAL) + SEND_INTERVAL - GetTime())
    state.scheduled = true
    C_Timer.After(delay, function()
        state.scheduled = false
        if not IsAvailable(channel) then state.pending = nil; return end
        if not state.pending or (chat.InChatMessagingLockdown and chat.InChatMessagingLockdown()) then return end
        local message = state.pending .. ":" .. localLabel
        state.pending, state.lastSend = nil, GetTime()
        pcall(chat.SendAddonMessage, PREFIX, message, channel)
    end)
end

local function Receive(prefix, message, channel)
    if issecretvalue and (issecretvalue(prefix) or issecretvalue(message) or issecretvalue(channel)) then return end
    if prefix ~= PREFIX or not IsAvailable(channel) or type(message) ~= "string" then return end
    if #message > 13 then return end
    local kind, label = message:match("^([HV]):(.*)$")
    local remoteVersion, remoteLabel = ParseVersion(label)
    if not remoteVersion then return end

    local state = channels[channel]
    if kind == "V" and remoteVersion >= localVersion and state and state.pending == "V" then
        state.pending = nil
    end

    if remoteVersion > localVersion and not notified then
        notified = true
        local locale = GetLocale()
        local spanish = locale == "esES" or locale == "esMX"
        local messageFormat = spanish
            and "Otra copia anuncia la versión %s. Busca la actualización de Pally Wrath en CurseForge."
            or "Another copy reports version %s. Check CurseForge for a Pally Wrath update."
        DEFAULT_CHAT_FRAME:AddMessage("|cffF58CBAPally Wrath|r: " .. messageFormat:format(remoteLabel))
    elseif kind == "H" and remoteVersion < localVersion then
        Schedule(channel, "V")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        self:UnregisterEvent(event)
        local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        if not getMetadata or not chat or not chat.RegisterAddonMessagePrefix or not chat.SendAddonMessage then return end
        localVersion, localLabel = ParseVersion(getMetadata(ADDON, "Version"))
        if not localVersion then return end
        local ok, result = pcall(chat.RegisterAddonMessagePrefix, PREFIX)
        if not ok or result == false then return end
        if chat.IsAddonMessagePrefixRegistered and not chat.IsAddonMessagePrefixRegistered(PREFIX) then return end
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_GUILD_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("CHAT_MSG_ADDON")
    elseif event == "PLAYER_ENTERING_WORLD" then
        Schedule("GUILD", "H")
        Schedule(GroupChannel(), "H")
    elseif event == "GROUP_ROSTER_UPDATE" then
        Schedule(GroupChannel(), "H")
    elseif event == "PLAYER_GUILD_UPDATE" then
        local unit = ...
        if not unit or unit == "player" then Schedule("GUILD", "H") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        for channel, state in pairs(channels) do
            if state.pending then Schedule(channel, state.pending) end
        end
    elseif event == "CHAT_MSG_ADDON" then
        Receive(...)
    end
end)
