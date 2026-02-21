-- ============================================================
-- SERVER.LUA — Offroad Race System
-- ============================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
-- Race State
-- ============================================================

---@class PlayerData
---@field name string
---@field checkpoint number
---@field finished boolean
---@field finishTime number

---@class RaceState
---@field lobbyActive boolean
---@field raceActive boolean
---@field lobbyStart number
---@field players table<number, PlayerData>
local race = {
    lobbyActive = false,
    raceActive  = false,
    lobbyStart  = 0,
    players     = {},
}

-- ============================================================
-- Helpers
-- ============================================================

---@param src number
---@return string
local function GetCharName(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return 'Desconocido' end
    local info = player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname, info.lastname)
end

---@return number
local function GetPlayerCount()
    local n = 0
    for _ in pairs(race.players) do n = n + 1 end
    return n
end

--- Build a sorted leaderboard: finished first (by time), then by checkpoint desc
---@return table[]
local function GetLeaderboard()
    local list = {}
    for _, data in pairs(race.players) do
        list[#list + 1] = {
            name       = data.name,
            checkpoint = data.checkpoint,
            finished   = data.finished,
            finishTime = data.finishTime,
        }
    end

    table.sort(list, function(a, b)
        if a.finished and b.finished then return a.finishTime < b.finishTime end
        if a.finished then return true end
        if b.finished then return false end
        return a.checkpoint > b.checkpoint
    end)

    return list
end

--- Broadcast leaderboard to all racing players
local function BroadcastLeaderboard()
    local lb = GetLeaderboard()
    for src in pairs(race.players) do
        TriggerClientEvent('patxi-carrera:client:updateLeaderboard', src, lb)
    end
end

--- Broadcast lobby state to all lobby players
---@param timeLeft number seconds remaining
local function BroadcastLobby(timeLeft)
    local players = GetLeaderboard()
    for src in pairs(race.players) do
        TriggerClientEvent('patxi-carrera:client:lobbyUpdate', src, timeLeft, players)
    end
end

--- Full reset of race state
local function ResetRace()
    race.lobbyActive = false
    race.raceActive  = false
    race.lobbyStart  = 0
    race.players     = {}
end

-- ============================================================
-- Race Start
-- ============================================================

local function StartRace()
    if not race.lobbyActive then return end

    if GetPlayerCount() < Config.MinPlayers then
        for src in pairs(race.players) do
            TriggerClientEvent('patxi-carrera:client:raceForceStop', src)
        end
        ResetRace()
        return
    end

    race.raceActive = true

    -- Signal all players
    for src in pairs(race.players) do
        TriggerClientEvent('patxi-carrera:client:startRace', src)
    end

    -- Race monitor thread
    CreateThread(function()
        while race.raceActive do
            Wait(5000)

            -- Check if all players finished or left
            local anyActive = false
            for _, data in pairs(race.players) do
                if not data.finished then
                    anyActive = true
                    break
                end
            end

            if not anyActive or GetPlayerCount() == 0 then
                race.raceActive = false
                Wait(10000) -- Let players see final results
                ResetRace()
                return
            end

            BroadcastLeaderboard()
        end
    end)
end

-- ============================================================
-- Lobby Management
-- ============================================================

--- Start the lobby countdown thread
local function StartLobbyCountdown()
    CreateThread(function()
        local lobbyMs = Config.LobbyTime * 60 * 1000
        local start   = GetGameTimer()

        while race.lobbyActive and not race.raceActive do
            local elapsed   = GetGameTimer() - start
            local remaining = lobbyMs - elapsed

            if remaining <= 0 then
                for src in pairs(race.players) do
                    TriggerClientEvent('patxi-carrera:client:lobbyEnd', src)
                end
                StartRace()
                return
            end

            BroadcastLobby(math.ceil(remaining / 1000))
            Wait(1000)
        end
    end)
end

RegisterNetEvent('patxi-carrera:server:joinLobby', function()
    local src = source

    if race.raceActive then
        TriggerClientEvent('patxi-carrera:client:joinedLobby', src, false,
            'Hay una carrera en curso. Espera a que termine.')
        return
    end

    if race.players[src] then
        TriggerClientEvent('patxi-carrera:client:joinedLobby', src, false, 'Ya estás inscrito.')
        return
    end

    race.players[src] = {
        name       = GetCharName(src),
        checkpoint = 0,
        finished   = false,
        finishTime = 0,
    }

    -- First player creates the lobby
    if not race.lobbyActive then
        race.lobbyActive = true
        race.lobbyStart  = GetGameTimer()

        TriggerClientEvent('patxi-carrera:client:joinedLobby', src, true,
            ('Te has inscrito. Lobby abierto por %d minuto(s).'):format(Config.LobbyTime))

        StartLobbyCountdown()
    else
        TriggerClientEvent('patxi-carrera:client:joinedLobby', src, true,
            'Te has inscrito en la carrera.')
    end
end)

RegisterNetEvent('patxi-carrera:server:leaveLobby', function()
    local src = source
    race.players[src] = nil

    if GetPlayerCount() == 0 and not race.raceActive then
        ResetRace()
    end
end)

-- ============================================================
-- Race Events
-- ============================================================

RegisterNetEvent('patxi-carrera:server:checkpointReached', function(checkpoint)
    local src = source
    if not race.players[src] or not race.raceActive then return end

    race.players[src].checkpoint = checkpoint
    BroadcastLeaderboard()
end)

RegisterNetEvent('patxi-carrera:server:playerFinished', function(finishTime)
    local src = source
    local player = race.players[src]
    if not player or not race.raceActive or player.finished then return end

    player.finished   = true
    player.finishTime = finishTime
    player.checkpoint = #Config.Checkpoints + 1

    -- Reward
    local qbPlayer = QBCore.Functions.GetPlayer(src)
    if qbPlayer then
        qbPlayer.Functions.AddMoney('cash', Config.Reward, 'offroad-race-reward')
    end

    BroadcastLeaderboard()

    -- Check if everyone is done
    local allDone = true
    for _, data in pairs(race.players) do
        if not data.finished then
            allDone = false
            break
        end
    end

    if allDone then
        race.raceActive = false
        SetTimeout(10000, function()
            ResetRace()
        end)
    end
end)

RegisterNetEvent('patxi-carrera:server:playerTimeout', function()
    local src = source
    race.players[src] = nil

    if GetPlayerCount() == 0 then
        race.raceActive = false
        ResetRace()
    end
end)

RegisterNetEvent('patxi-carrera:server:playerLeft', function()
    local src = source
    race.players[src] = nil

    if GetPlayerCount() == 0 and race.raceActive then
        race.raceActive = false
        ResetRace()
    end
end)

RegisterNetEvent('patxi-carrera:server:requestLeaderboard', function()
    local src = source
    TriggerClientEvent('patxi-carrera:client:updateLeaderboard', src, GetLeaderboard())
end)

-- ============================================================
-- Player Disconnect Cleanup
-- ============================================================

AddEventHandler('playerDropped', function()
    local src = source
    if not race.players[src] then return end

    race.players[src] = nil

    if GetPlayerCount() == 0 then
        race.raceActive = false
        ResetRace()
    else
        BroadcastLeaderboard()
    end
end)
