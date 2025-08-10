-- =================================================================
--
--  Outland :: Core Survival Systems
--  File: outland_survival.lua
--
-- =================================================================

--[[ Game Balance Constants ]]--
-- These are at the top for easy tweaking.
local TICK_INTERVAL_SECONDS = 5  -- How often hunger depletes (in seconds).
local HUNGER_PER_TICK = 1         -- How much hunger is lost per tick.
local MAX_HUNGER = 100            -- The maximum hunger a player can have.
local HUNGER_DATA_KEY = "outland_hunger" -- The key for storing player data.

--[[
    Function: Survival_OnPlayerLogin
    Hook: PLAYER_EVENT_ON_LOGIN
    Purpose: Initializes a player's hunger value to the maximum when they first
             log in or if the data is missing.
]]--
local function Survival_OnPlayerLogin(event, player)
    if player:GetData(HUNGER_DATA_KEY) == nil then
        player:SetData(HUNGER_DATA_KEY, MAX_HUNGER)
        print(("[Outland] Initialized hunger for player %s."):format(player:GetName()))
    end
end

--[[
    Function: Survival_HungerTick
    Purpose: This is the core logic for a single player's hunger drain.
             It's called by the main update loop.
]]--
local function Survival_HungerTick(player)
    local currentHunger = player:GetData(HUNGER_DATA_KEY) or MAX_HUNGER

    -- Calculate the new hunger value, ensuring it doesn't go below zero.
    local newHunger = math.max(0, currentHunger - HUNGER_PER_TICK)

    player:SetData(HUNGER_DATA_KEY, newHunger)

    -- For testing, send a message to the player so we can see it working.
    player:SendBroadcastMessage(("[DEBUG] Your hunger is now %d/%d."):format(newHunger, MAX_HUNGER))
end

--[[
    Function: Survival_MainUpdate
    Purpose: This is the "heartbeat" of our survival system. It runs on a timer,
             gets all online players, and applies the hunger tick to each one.
]]--
local function Survival_MainUpdate()
    local onlinePlayers = GetPlayers()
    for _, player in ipairs(onlinePlayers) do
        -- Ensure the player is valid and in the world before ticking.
        if player and player:IsInWorld() then
            Survival_HungerTick(player)
        end
    end
end

--[[ Event Registration ]]--
-- We register our functions to be called by the server's events.

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, Survival_OnPlayerLogin)
CreateRepeaterEvent(Survival_MainUpdate, TICK_INTERVAL_SECONDS * 1000, 0)

print("== [Outland] Core Survival System Loaded ==")