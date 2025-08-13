--
--  Outland Hunger System (Phase 1)
--  - Persistent hunger with offline decay (optional)
--  - Context-aware drain (idle/moving/combat/resting) and gates (BG/Arena/flight/ghost)
--  - Threshold messaging and optional auras
--  - Basic food consumption hooks for common food items
--  - Simple .hunger command (player + GM tools)
--

--[[ Configuration ]]--
local Hunger = {
    ENABLED = true,

    -- Ticking / bounds
    TICK_MS = 5000,
    MAX = 100,
    START = 100,

    -- Drain per tick. Positive numbers drain hunger.
    RATES = {
        base = 0.5,
        moving = 0.5,   -- extra drain when moving
        combat = 1.0,   -- extra drain when in combat
        resting = -0.4, -- reduce drain when resting (can go as low as REST_MIN)
        REST_MIN = 0.1, -- minimum drain while resting
    },

    -- Optional offline decay when a player is logged out (per hour)
    OFFLINE_DECAY_PER_HOUR = 0, -- set to >0 to slowly drain while offline

    -- Thresholds for messaging/effects
    THRESHOLDS = {
        peckish = 70,
        hungry = 40,
        famished = 25, -- new stage: applies regen penalty
        starving = 15,
    },

    -- Optional auras to apply at thresholds (set to nil to disable)
    -- Note: Uses real spell IDs; validated via GetSpellInfo before applying.
    APPLY_AURAS = true, -- set true to enable aura application
    SPELLS = {
        peckish = nil,   -- e.g., a harmless visual aura (left nil by default)
        hungry = nil,    -- e.g., a mild debuff (left nil by default)
        -- Custom debuff: "Famished" (-25% Health & Mana regeneration)
        -- Create a custom spell (e.g., ID 90001) with:
        --   - Effect 0: SPELL_AURA_MOD_HEALTH_REGEN_PERCENT, Amount = -25
        --   - Effect 1: SPELL_AURA_MOD_POWER_REGEN_PERCENT (MiscValue = POWER_MANA), Amount = -25
        -- If the spell does not exist client-side, this will safely no-op due to GetSpellInfo check.
        famished = 90001,
        starving = 1604, -- Dazed (movement slow) — caution: strong effect
    },

    -- While starving, periodically reapply (pulse) the starving aura to refresh effect.
    STARVING_PULSE_INTERVAL = 20, -- seconds (set to 0 to disable pulsing)

    -- Context gates
    GATES = {
        disableInBG = true,
        disableInArena = true,
        disableInFlight = true,
        disableWhileGhost = true,
    },

    -- Messaging
    MESSAGES = {
        peckish = "You feel a bit peckish.",
        hungry = "You're getting hungry.",
        famished = "Your body is conserving energy due to lack of food. Health and mana regenerate 25% slower.",
        starving = "You're starving! Find food soon.",
        restored = function(amount)
            return ("You eat and restore %d hunger."):format(amount)
        end,
        show = function(value, max)
            return ("Hunger: %d/%d"):format(value, max)
        end,
    },

    -- Known food items (examples; extend as needed)
    FOOD = {
        [4540] = 10, -- Tough Hunk of Bread
        [4541] = 20, -- Freshly Baked Bread
        [4542] = 30, -- Moist Cornbread
        [117]  = 8,  -- Tough Jerky
        [2287] = 12, -- Haunch of Meat
        [4592] = 15, -- Longjaw Mud Snapper
    },

    DEBUG = false,
}

--[[ Internal State ]]--
local STATE = {
    byGuid = {}, -- guidLow -> { value:number, stage:string|nil, lastPos={map,x,y,z}, nextSave=0 }
}

--[[ Debug helper ]]--
local function dbg(player, fmt, ...)
    if not Hunger.DEBUG then return end
    if player and player.SendBroadcastMessage then
        player:SendBroadcastMessage(("[Hunger][DEBUG] " .. fmt):format(...))
    end
end

--[[ Eluna Event Constants ]]--
local PLAYER_EVENT_ON_LOGIN = 3
local PLAYER_EVENT_ON_LOGOUT = 4
local PLAYER_EVENT_ON_SAVE = 25
local PLAYER_EVENT_ON_FIRST_LOGIN = 30
local PLAYER_EVENT_ON_COMMAND = 42

local ITEM_EVENT_ON_USE = 2

--[[ DB Helpers ]]--
local function EnsureTable()
    CharDBExecute([[ 
        CREATE TABLE IF NOT EXISTS character_hunger (
            guid INT UNSIGNED PRIMARY KEY,
            hunger TINYINT UNSIGNED NOT NULL DEFAULT 100,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end

local function now()
    return GetGameTime() -- seconds
end

local function clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

local function loadHunger(player)
    local guid = player:GetGUIDLow()
    local s = STATE.byGuid[guid]
    if s then return s end

    local q = CharDBQuery("SELECT hunger, UNIX_TIMESTAMP(updated_at) FROM character_hunger WHERE guid=" .. guid)
    local value = Hunger.START
    local last = now()
    if q then
        value = q:GetUInt32(0)
        local updated_at = q:GetUInt32(1)
        if Hunger.OFFLINE_DECAY_PER_HOUR and Hunger.OFFLINE_DECAY_PER_HOUR > 0 then
            local hours = math.floor(math.max(0, now() - updated_at) / 3600)
            if hours > 0 then
                value = clamp(value - Hunger.OFFLINE_DECAY_PER_HOUR * hours, 0, Hunger.MAX)
            end
        end
    else
        CharDBExecute("INSERT INTO character_hunger (guid, hunger) VALUES (" .. guid .. "," .. Hunger.START .. ")")
    end

    s = { value = value, stage = nil, lastPos = { player:GetMapId(), player:GetX(), player:GetY(), player:GetZ() }, nextSave = now() + 30 }
    STATE.byGuid[guid] = s
    return s
end

local function saveHunger(player, force)
    local guid = player:GetGUIDLow()
    local s = STATE.byGuid[guid]
    if not s then return end
    if not force and now() < (s.nextSave or 0) then return end
    local v = math.floor(clamp(s.value, 0, Hunger.MAX))
    CharDBExecute("UPDATE character_hunger SET hunger=" .. v .. " WHERE guid=" .. guid)
    s.nextSave = now() + 30
end

--[[ Effects ]]--
local function spellExists(id)
    if not id then return false end
    local info = GetSpellInfo and GetSpellInfo(id)
    return info ~= nil
end

local function removeAllThresholdAuras(player)
    for _, spellId in pairs(Hunger.SPELLS) do
        if spellId and spellExists(spellId) then player:RemoveAura(spellId) end
    end
end

local function applyStage(player, s)
    local t = Hunger.THRESHOLDS
    local v = s.value
    local newStage = nil
    if v <= t.starving then newStage = "starving"
    elseif v <= (t.famished or -1) then newStage = "famished"
    elseif v <= t.hungry then newStage = "hungry"
    elseif v <= t.peckish then newStage = "peckish"
    else newStage = nil end

    if newStage ~= s.stage then
        -- stage changed
        s.stage = newStage
        removeAllThresholdAuras(player)
        local starvingAuraActive = false
        if Hunger.APPLY_AURAS and newStage and Hunger.SPELLS[newStage] and spellExists(Hunger.SPELLS[newStage]) then
            player:AddAura(Hunger.SPELLS[newStage], player)
            if newStage == "starving" then starvingAuraActive = true end
        end
        if newStage and Hunger.MESSAGES[newStage] and player.SendBroadcastMessage then
            player:SendBroadcastMessage(Hunger.MESSAGES[newStage])
        end
    end
end

--[[ Rate Computation ]]--
local function distance2(ax, ay, az, bx, by, bz)
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return dx * dx + dy * dy + dz * dz
end

local function isMoving(player, s)
    local map, x, y, z = player:GetMapId(), player:GetX(), player:GetY(), player:GetZ()
    local lp = s.lastPos
    local moved = (lp[1] ~= map) or distance2(lp[2], lp[3], lp[4], x, y, z) > 1.0
    s.lastPos = { map, x, y, z }
    return moved
end

local function gated(player)
    if Hunger.GATES.disableWhileGhost and player.IsDead and player:IsDead() then
        return true
    end
    if Hunger.GATES.disableInFlight and player.IsTaxiFlying and player:IsTaxiFlying() then return true end
    if Hunger.GATES.disableInArena and player.IsInArena and player:IsInArena() then return true end
    if Hunger.GATES.disableInBG and player.IsInBattleground and player:IsInBattleground() then return true end
    return false
end

local function tickPlayer(player)
    local s = loadHunger(player)
    if gated(player) then
        -- While gated, ensure no auras from hunger
        removeAllThresholdAuras(player)
        return
    end

    local rate = Hunger.RATES.base

    if isMoving(player, s) then rate = rate + Hunger.RATES.moving end
    if player.IsInCombat and player:IsInCombat() then rate = rate + Hunger.RATES.combat end
    if player.IsResting and player:IsResting() then
        rate = rate + Hunger.RATES.resting
        if rate < Hunger.RATES.REST_MIN then rate = Hunger.RATES.REST_MIN end
    end

    s.value = clamp(s.value - rate, 0, Hunger.MAX)
    applyStage(player, s)
    -- Periodic starving pulse (recast aura) if configured
    if s.stage == "starving" and Hunger.APPLY_AURAS and Hunger.SPELLS.starving and Hunger.STARVING_PULSE_INTERVAL and Hunger.STARVING_PULSE_INTERVAL > 0 then
        local spellId = Hunger.SPELLS.starving
        if spellExists(spellId) then
            local nowSec = now()
            if not s.nextStarvePulse or nowSec >= s.nextStarvePulse then
                -- Recast: remove then add to force refresh/visual
                if player.RemoveAura then player:RemoveAura(spellId) end
                player:AddAura(spellId, player)
                s.nextStarvePulse = nowSec + Hunger.STARVING_PULSE_INTERVAL
            end
        end
    end
    saveHunger(player, false)

    if Hunger.DEBUG and math.random(1, 20) == 1 then
        if player.SendBroadcastMessage then
            player:SendBroadcastMessage(Hunger.MESSAGES.show(math.floor(s.value), Hunger.MAX))
        end
    end
end

--[[ Food Handling ]]--
local function onFoodUse(event, player, item, target)
    local entry = item:GetEntry()
    local amount = Hunger.FOOD[entry]
    if not amount then return end
    local s = loadHunger(player)
    local before = s.value
    s.value = clamp(s.value + amount, 0, Hunger.MAX)
    applyStage(player, s)
    saveHunger(player, true)
    if player.SendBroadcastMessage then
        player:SendBroadcastMessage(Hunger.MESSAGES.restored(math.floor(s.value - before)))
    end
end

local function registerFoodHandlers()
    for entry, _ in pairs(Hunger.FOOD) do
        RegisterItemEvent(entry, ITEM_EVENT_ON_USE, onFoodUse)
    end
end

--[[ Commands ]]--
local function onCommand(event, player, command, chatHandler)
    if not command then return end
    local msg = command:lower()
    if msg == "hunger" or msg:match("^hunger%s") then
        local s = loadHunger(player)
        local isGM = player.IsGM and player:IsGM()
        if msg:match("^hunger%s+set%s+%d+") and isGM then
            local set = tonumber(msg:match("set%s+(%d+)"))
            if set then
                s.value = clamp(set, 0, Hunger.MAX)
                applyStage(player, s)
                saveHunger(player, true)
                if player.SendBroadcastMessage then
                    player:SendBroadcastMessage("[GM] " .. Hunger.MESSAGES.show(math.floor(s.value), Hunger.MAX))
                end
            end
        elseif msg:match("^hunger%s+add%s+%d+") and isGM then
            local add = tonumber(msg:match("add%s+(%d+)"))
            if add then
                s.value = clamp(s.value + add, 0, Hunger.MAX)
                applyStage(player, s)
                saveHunger(player, true)
                if player.SendBroadcastMessage then
                    player:SendBroadcastMessage("[GM] " .. Hunger.MESSAGES.show(math.floor(s.value), Hunger.MAX))
                end
            end
        elseif msg:match("^hunger%s+reset") and isGM then
            s.value = Hunger.START
            applyStage(player, s)
            saveHunger(player, true)
            if player.SendBroadcastMessage then
                player:SendBroadcastMessage("[GM] Hunger reset.")
            end
        else
            if player.SendBroadcastMessage then
                player:SendBroadcastMessage(Hunger.MESSAGES.show(math.floor(s.value), Hunger.MAX))
            end
        end
        return false -- consume the command
    end
end

--[[ Player Lifecycle ]]--
local function onLogin(event, player)
    loadHunger(player)
end

local function onFirstLogin(event, player)
    local guid = player:GetGUIDLow()
    local start = Hunger.START
    CharDBExecute("INSERT IGNORE INTO character_hunger (guid, hunger) VALUES (" .. guid .. "," .. start .. ")")
    STATE.byGuid[guid] = { value = start, stage = nil, lastPos = { player:GetMapId(), player:GetX(), player:GetY(), player:GetZ() }, nextSave = now() + 30 }
end

local function onLogout(event, player)
    saveHunger(player, true)
    STATE.byGuid[player:GetGUIDLow()] = nil
end

local function onSave(event, player)
    saveHunger(player, true)
end

--[[ Scheduler ]]--
local function mainTick()
    if not Hunger.ENABLED then return end
    local players = GetPlayersInWorld()
    for _, player in ipairs(players) do
        if player and player.IsInWorld and player:IsInWorld() then
            tickPlayer(player)
        end
    end
end

--[[ Bootstrap ]]--
EnsureTable()
registerFoodHandlers()
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, onLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_FIRST_LOGIN, onFirstLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGOUT, onLogout)
RegisterPlayerEvent(PLAYER_EVENT_ON_SAVE, onSave)
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, onCommand)
CreateLuaEvent(mainTick, Hunger.TICK_MS, 0)

print("== [Outland] Hunger System (Phase 1) Loaded ==")