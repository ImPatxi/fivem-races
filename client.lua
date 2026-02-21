-- ============================================================
-- CLIENT.LUA — Offroad Race System
-- ============================================================

local QBCore = exports['qb-core']:GetCoreObject()
local RESOURCE = GetCurrentResourceName()

-- ============================================================
-- State
-- ============================================================
local state = {
    racing        = false,
    inLobby       = false,
    checkpoint    = 1,
    startTime     = 0,
    totalCPs      = #Config.Checkpoints,
}

-- Entity handles
local entities = {
    startPed    = nil,
    finishPed   = nil,
    startBlip   = nil,
    finishBlip  = nil,
    cpHandle    = nil,
    nextCpHandle = nil,
    cpBlip      = nil,
    nextCpBlip  = nil,
}

-- ============================================================
-- Helpers
-- ============================================================

--- Load a ped model with timeout safety
---@param model string|number
---@return number hash
local function LoadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if HasModelLoaded(hash) then return hash end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then
            warn(('[%s] Model load timeout: %s'):format(RESOURCE, model))
            return hash
        end
        Wait(0)
    end
    return hash
end

--- Spawn a frozen, invincible NPC
---@param cfg table
---@return number ped
local function SpawnNPC(cfg)
    local hash = LoadModel(cfg.model)
    local ped = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)
    return ped
end

--- Create a map blip from NPC config
---@param cfg table
---@return number blip
local function CreateNPCBlip(cfg)
    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, cfg.blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.blip.scale)
    SetBlipColour(blip, cfg.blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.blip.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ============================================================
-- NUI Bridge
-- ============================================================

local function SendUI(payload)
    SendNUIMessage(payload)
end

local function ShowRaceHUD(show)
    SendUI({ action = 'toggleHUD', show = show })
end

local function UpdateTimerUI(remaining, cp, total)
    SendUI({ action = 'updateTimer', remaining = remaining, checkpoint = cp, total = total })
end

local function ShowLobbyUI(show, timeLeft, players)
    SendUI({ action = 'toggleLobby', show = show, timeLeft = timeLeft or 0, players = players or {} })
end

local function ShowLeaderboardUI(show, leaderboard)
    SendUI({ action = 'updateLeaderboard', show = show, leaderboard = leaderboard or {} })
end

local function Notify(msg, nType)
    SendUI({ action = 'notification', message = msg, type = nType or 'info' })
end

-- ============================================================
-- Checkpoint Management
-- ============================================================

local function DeleteCheckpoints()
    if entities.cpHandle then
        DeleteCheckpoint(entities.cpHandle)
        entities.cpHandle = nil
    end
    if entities.nextCpHandle then
        DeleteCheckpoint(entities.nextCpHandle)
        entities.nextCpHandle = nil
    end
    if entities.cpBlip then
        RemoveBlip(entities.cpBlip)
        entities.cpBlip = nil
    end
    if entities.nextCpBlip then
        RemoveBlip(entities.nextCpBlip)
        entities.nextCpBlip = nil
    end
end

--- Create a GTA Online-style checkpoint cylinder
---@param cpType number Native checkpoint type (45=arrow, 4=finish)
---@param pos vector3
---@param nextPos vector3
---@param color table {r,g,b,a}
---@return number handle
local function CreateRaceCheckpoint(cpType, pos, nextPos, color)
    local target = nextPos or pos
    local size = Config.CheckpointSize
    local handle = CreateCheckpoint(
        cpType,
        pos.x, pos.y, pos.z,
        target.x, target.y, target.z,
        size,
        color.r, color.g, color.b, color.a,
        0
    )
    SetCheckpointCylinderHeight(handle, Config.CheckpointHeight, Config.CheckpointHeight, size)
    SetCheckpointIconRgba(handle, color.r, color.g, color.b, 200)
    return handle
end

--- Update visible checkpoints (current + next) and minimap blips
local function UpdateCheckpoints()
    DeleteCheckpoints()

    if not state.racing or state.checkpoint > state.totalCPs then return end

    local pos     = Config.Checkpoints[state.checkpoint]
    local isLast  = state.checkpoint == state.totalCPs
    local finishCoords = vector3(Config.FinishNPC.coords.x, Config.FinishNPC.coords.y, Config.FinishNPC.coords.z)

    -- Determine next position for the arrow direction
    local nextPos = isLast and finishCoords or Config.Checkpoints[state.checkpoint + 1]
    local cpType  = isLast and 4 or 45 -- 4 = finish flag, 45 = arrow cylinder

    -- Current checkpoint
    entities.cpHandle = CreateRaceCheckpoint(cpType, pos, nextPos, Config.CheckpointColor)

    entities.cpBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(entities.cpBlip, 1)
    SetBlipColour(entities.cpBlip, 5)
    SetBlipScale(entities.cpBlip, 0.9)
    SetBlipRoute(entities.cpBlip, true)
    SetBlipRouteColour(entities.cpBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Checkpoint %d/%d'):format(state.checkpoint, state.totalCPs))
    EndTextCommandSetBlipName(entities.cpBlip)

    -- Next checkpoint preview (if not last)
    if not isLast and state.checkpoint + 1 <= state.totalCPs then
        local nextCpPos = Config.Checkpoints[state.checkpoint + 1]
        local afterNext = (state.checkpoint + 2 <= state.totalCPs)
            and Config.Checkpoints[state.checkpoint + 2]
            or finishCoords

        entities.nextCpHandle = CreateRaceCheckpoint(45, nextCpPos, afterNext, Config.NextCheckpointColor)

        entities.nextCpBlip = AddBlipForCoord(nextCpPos.x, nextCpPos.y, nextCpPos.z)
        SetBlipSprite(entities.nextCpBlip, 1)
        SetBlipColour(entities.nextCpBlip, 18)
        SetBlipScale(entities.nextCpBlip, 0.6)
        SetBlipDisplay(entities.nextCpBlip, 2)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Siguiente')
        EndTextCommandSetBlipName(entities.nextCpBlip)
    end
end

-- ============================================================
-- Race Logic
-- ============================================================

--- Stop the race and clean up
---@param reason 'timeout'|'finished'|'cancelled'
local function StopRace(reason)
    state.racing     = false
    state.checkpoint  = 1
    state.startTime   = 0

    DeleteCheckpoints()
    ShowRaceHUD(false)
    ShowLeaderboardUI(false)

    local messages = {
        timeout   = { '⏱️ Se acabó el tiempo. Carrera cancelada.', 'error' },
        finished  = { ('🏁 ¡Has terminado la carrera! Recompensa: $%s'):format(Config.Reward), 'success' },
        cancelled = { '❌ Carrera cancelada.', 'error' },
    }

    local msg = messages[reason]
    if msg then Notify(msg[1], msg[2]) end

    -- Notify server
    local serverEvents = {
        timeout   = 'patxi-carrera:server:playerTimeout',
        cancelled = 'patxi-carrera:server:playerLeft',
    }
    if serverEvents[reason] then
        TriggerServerEvent(serverEvents[reason])
    end
end

--- Main checkpoint detection & timer loop
local function RaceLoop()
    CreateThread(function()
        local maxMs = Config.MaxTime * 60 * 1000

        while state.racing do
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            -- Only the driver validates checkpoints
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local playerPos = GetEntityCoords(ped)
                local cpPos     = Config.Checkpoints[state.checkpoint]

                if #(playerPos - cpPos) < Config.CheckpointRadius then
                    PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', false)
                    state.checkpoint = state.checkpoint + 1

                    if state.checkpoint > state.totalCPs then
                        local finishTime = GetGameTimer() - state.startTime
                        TriggerServerEvent('patxi-carrera:server:playerFinished', finishTime)
                        StopRace('finished')
                        return
                    end

                    Notify(('✅ Checkpoint %d/%d'):format(state.checkpoint - 1, state.totalCPs), 'success')
                    TriggerServerEvent('patxi-carrera:server:checkpointReached', state.checkpoint)
                    UpdateCheckpoints()
                end
            end

            -- Timer update
            if state.racing then
                local elapsed   = GetGameTimer() - state.startTime
                local remaining = maxMs - elapsed

                if remaining <= 0 then
                    StopRace('timeout')
                    return
                end

                UpdateTimerUI(remaining, state.checkpoint, state.totalCPs)
            end

            Wait(100)
        end
    end)
end

-- ============================================================
-- Server Events
-- ============================================================

RegisterNetEvent('patxi-carrera:client:joinedLobby', function(success, msg)
    if success then
        state.inLobby = true
        Notify('✅ ' .. msg, 'success')
    else
        Notify('❌ ' .. msg, 'error')
    end
end)

RegisterNetEvent('patxi-carrera:client:lobbyUpdate', function(timeLeft, players)
    ShowLobbyUI(true, timeLeft, players)
end)

RegisterNetEvent('patxi-carrera:client:lobbyEnd', function()
    state.inLobby = false
    ShowLobbyUI(false)
end)

RegisterNetEvent('patxi-carrera:client:startRace', function()
    state.inLobby    = false
    state.racing     = true
    state.checkpoint  = 1
    state.startTime   = GetGameTimer()

    ShowLobbyUI(false)
    ShowRaceHUD(true)
    UpdateCheckpoints()
    RaceLoop()

    Notify('🏁 ¡La carrera ha comenzado! Tienes ' .. Config.MaxTime .. ' minutos.', 'info')
    PlaySoundFrontend(-1, 'MP_5_SECOND_TIMER', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
end)

RegisterNetEvent('patxi-carrera:client:raceForceStop', function()
    if state.racing then
        StopRace('cancelled')
    end
    if state.inLobby then
        state.inLobby = false
        ShowLobbyUI(false)
        Notify('❌ Carrera cancelada por el servidor.', 'error')
    end
end)

RegisterNetEvent('patxi-carrera:client:updateLeaderboard', function(leaderboard)
    if state.racing then
        ShowLeaderboardUI(true, leaderboard)
    end
end)

-- ============================================================
-- ox_target Interactions
-- ============================================================

local function SetupTargets()
    exports.ox_target:addLocalEntity(entities.startPed, {
        {
            name     = 'race_register',
            icon     = 'fas fa-flag-checkered',
            label    = 'Inscribirse en la carrera',
            distance = 2.5,
            canInteract = function()
                return not state.racing and not state.inLobby
            end,
            onSelect = function()
                TriggerServerEvent('patxi-carrera:server:joinLobby')
            end,
        },
        {
            name     = 'race_leave',
            icon     = 'fas fa-door-open',
            label    = 'Salir de la carrera',
            distance = 2.5,
            canInteract = function()
                return state.inLobby
            end,
            onSelect = function()
                state.inLobby = false
                ShowLobbyUI(false)
                TriggerServerEvent('patxi-carrera:server:leaveLobby')
                Notify('Has salido de la carrera.', 'info')
            end,
        },
    })

    exports.ox_target:addLocalEntity(entities.finishPed, {
        {
            name     = 'race_info_finish',
            icon     = 'fas fa-trophy',
            label    = 'Ver clasificación',
            distance = 2.5,
            onSelect = function()
                TriggerServerEvent('patxi-carrera:server:requestLeaderboard')
            end,
        },
    })
end

-- ============================================================
-- Initialization
-- ============================================================

CreateThread(function()
    entities.startPed  = SpawnNPC(Config.StartNPC)
    entities.finishPed = SpawnNPC(Config.FinishNPC)
    entities.startBlip = CreateNPCBlip(Config.StartNPC)
    entities.finishBlip = CreateNPCBlip(Config.FinishNPC)

    SetupTargets()
end)

-- ============================================================
-- Cleanup
-- ============================================================

local function CleanupAll()
    DeleteCheckpoints()
    ShowRaceHUD(false)
    ShowLobbyUI(false)
    ShowLeaderboardUI(false)

    if entities.startPed and DoesEntityExist(entities.startPed) then
        exports.ox_target:removeLocalEntity(entities.startPed)
        DeleteEntity(entities.startPed)
    end
    if entities.finishPed and DoesEntityExist(entities.finishPed) then
        exports.ox_target:removeLocalEntity(entities.finishPed)
        DeleteEntity(entities.finishPed)
    end
    if entities.startBlip then RemoveBlip(entities.startBlip) end
    if entities.finishBlip then RemoveBlip(entities.finishBlip) end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    CleanupAll()
end)

-- Cancel race on player death
AddEventHandler('gameEventTriggered', function(event, data)
    if event ~= 'CEventNetworkEntityDamage' then return end
    local victim = data[1]
    if victim == PlayerPedId() and IsEntityDead(victim) and state.racing then
        StopRace('cancelled')
    end
end)
