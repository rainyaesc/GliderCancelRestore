-- GliderCancelRestore 0.3.2-cache-address-fix
-- Restores the pre-1.0 E-key cancel for Eagle/Galeclaw gliding.

local MOD = "GliderCancelRestore"
local VERSION = "0.3.2-cache-address-fix"
local TARGET_KEY = Key.E
local EAGLE_ID_FRAGMENT = "eagle"

local function current_mod_root()
    local ok, source = pcall(function() return debug.getinfo(1, "S").source end)
    if not ok or type(source) ~= "string" then return nil end
    source = source:gsub("^@", "")
    return source:match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
end

local MOD_ROOT = current_mod_root()
local LOG_PATH = MOD_ROOT and (MOD_ROOT .. "/runtime.log") or "GliderCancelRestore-runtime.log"
local cancel_pending = false
local cache_refresh_pending = false
local cached_controller = nil
local cached_pawn = nil
local cached_component = nil
local glider_class = nil
local cancel_error_logged = false
local cancel_success_logged = false

local function append_line(message)
    local ok, handle = pcall(io.open, LOG_PATH, "a")
    if ok and handle then
        handle:write(tostring(message), "\n")
        handle:close()
    end
end

local function log(message)
    local line = string.format("[%s] %s", os.date("!%Y-%m-%dT%H:%M:%SZ"), tostring(message))
    print(string.format("[%s] %s\n", MOD, tostring(message)))
    append_line(line)
end

local function valid(value)
    if value == nil then return false end
    local ok, result = pcall(function() return value:IsValid() end)
    return ok and result == true
end

local function unwrap(value)
    if value == nil then return nil end
    local ok, result = pcall(function() return value:get() end)
    return ok and result or value
end

local function same_object(left, right)
    if not valid(left) or not valid(right) then return false end
    local ok, same = pcall(function() return left:GetAddress() == right:GetAddress() end)
    return ok and same == true
end

local function find_local_controller()
    local ok, controllers = pcall(function()
        return FindAllOf("PlayerController") or FindAllOf("Controller")
    end)
    if not ok or type(controllers) ~= "table" then return nil end

    for _, controller in ipairs(controllers) do
        if valid(controller) then
            local local_ok, is_local = pcall(function()
                if controller.IsLocalPlayerController then return controller:IsLocalPlayerController() end
                return false
            end)
            if local_ok and is_local == true then return controller end
        end
    end
    return nil
end

local function ui_blocks_cancel(controller)
    local construction_ok, construction_open = pcall(function() return controller.isOpenConstructionMenu end)
    if construction_ok and construction_open == true then return true, "construction-menu" end

    local cursor_ok, cursor_visible = pcall(function() return controller.bShowMouseCursor end)
    if cursor_ok and cursor_visible == true then return true, "ui-cursor-visible" end

    return false, nil
end

local function cached_local_objects()
    if not valid(cached_controller) or not valid(cached_pawn) or not valid(cached_component) then return nil, nil end

    local pawn_ok, current_pawn = pcall(function() return cached_controller.Pawn end)
    if not pawn_ok or not same_object(current_pawn, cached_pawn) then return nil, nil end
    return cached_component, cached_controller
end

local function refresh_local_cache(reason, report_success)
    local controller = find_local_controller()
    if not valid(controller) then return false end
    local pawn_ok, pawn = pcall(function() return controller.Pawn end)
    if not pawn_ok or not valid(pawn) then return false end

    if not valid(glider_class) then
        local class_ok, result = pcall(function()
            return StaticFindObject("/Script/Pal.PalGliderComponent")
        end)
        if not class_ok or not valid(result) then return false end
        glider_class = result
    end

    local component_ok, component = pcall(function()
        return pawn:GetComponentByClass(glider_class)
    end)
    if not component_ok or not valid(component) then return false end

    cached_controller = controller
    cached_pawn = pawn
    cached_component = component
    if report_success then log("local glider component cached reason=" .. tostring(reason)) end
    return true
end

local function request_cache_refresh(reason, delay_ms)
    if cache_refresh_pending then return end
    cache_refresh_pending = true
    ExecuteWithDelay(delay_ms or 0, function()
        local ok, error_message = pcall(function()
            ExecuteInGameThread(function()
                cache_refresh_pending = false
                refresh_local_cache(reason, true)
            end)
        end)
        if not ok then
            cache_refresh_pending = false
            log("ERROR cache refresh queue failed: " .. tostring(error_message))
        end
    end)
end

local function is_gliding(component)
    local ok, result = pcall(function() return component:IsGliding() end)
    return ok and result == true
end

local function current_glider_pal_id(component)
    local ok, value = pcall(function() return component.CurrentGliderPalID:ToString() end)
    return ok and tostring(value) or "<unreadable>"
end

local function is_eagle_glider(pal_id)
    return type(pal_id) == "string" and pal_id:lower():find(EAGLE_ID_FRAGMENT, 1, true) ~= nil
end

local function cancel_eagle_gliding()
    if cancel_pending then return end
    cancel_pending = true

    local queued, queue_error = pcall(function()
        ExecuteInGameThread(function()
            local component, controller = cached_local_objects()
            if not valid(component) then cancel_pending = false; return end

            local blocked = ui_blocks_cancel(controller)
            if blocked then cancel_pending = false; return end

            if not is_gliding(component) then
                cancel_pending = false
                return
            end

            local pal_id = current_glider_pal_id(component)
            if not is_eagle_glider(pal_id) then
                cancel_pending = false
                return
            end

            local call_ok, call_error = pcall(function() component:EndGliding() end)
            if not call_ok then
                cancel_pending = false
                if not cancel_error_logged then
                    cancel_error_logged = true
                    log(string.format("ERROR EndGliding failed id=%s error=%s", tostring(pal_id), tostring(call_error)))
                end
                return
            end
            if not cancel_success_logged then
                cancel_success_logged = true
                log("first E -> native EndGliding dispatched id=" .. tostring(pal_id) .. "; later cancels are not logged")
            end
            cancel_pending = false
        end)
    end)

    if not queued then
        cancel_pending = false
        log("ERROR failed to enter game thread: " .. tostring(queue_error))
    end
end

local function register_e_key()
    local conflict_ok, already_registered = pcall(function() return IsKeyBindRegistered(TARGET_KEY) end)
    if conflict_ok and already_registered == true then
        log("ERROR Key.E is already registered by another UE4SS mod; refusing to replace it")
        return false
    end

    local ok, error_message = pcall(function()
        RegisterKeyBind(TARGET_KEY, cancel_eagle_gliding)
    end)
    if not ok then
        log("ERROR failed to register Key.E: " .. tostring(error_message))
        return false
    end
    log("Key.E registered: only ends local Eagle/Galeclaw gliding; normal E input is not consumed")
    return true
end

log(string.format("loaded %s; native EndGliding pipeline, no stamina/gravity/speed edits", VERSION))
append_line("--- new process ---")
register_e_key()

request_cache_refresh("startup", 3000)

pcall(function()
    RegisterInitGameStatePostHook(function()
        cached_controller = nil
        cached_pawn = nil
        cached_component = nil
        request_cache_refresh("InitGameState", 2000)
    end)
end)

local function register_possession_refresh(path, label)
    local ok, pre_id, post_id = pcall(function()
        return RegisterHook(path, function()
            request_cache_refresh(label, 500)
        end)
    end)
    if ok then
        log(string.format("cache hook registered %s pre=%s post=%s", path, tostring(pre_id), tostring(post_id)))
    else
        log("cache hook unavailable " .. path .. " error=" .. tostring(pre_id))
    end
end

register_possession_refresh("/Script/Engine.PlayerController:ClientRestart", "ClientRestart")
register_possession_refresh("/Script/Engine.PlayerController:ServerAcknowledgePossession", "ServerAcknowledgePossession")
