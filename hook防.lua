if not hookmetamethod then return end

if shared.VW_HOOKMETAMETHOD_SCRIPT then
    pcall(function()
        shared.VW_HOOKMETAMETHOD_SCRIPT.Functions.CleanHooks()
    end)
    shared.VW_HOOKMETAMETHOD_SCRIPT = nil
end

local Script = {
    Functions = {},
    GameState = "Unknown"
}
shared.VW_HOOKMETAMETHOD_SCRIPT = Script

local _original_hooks = {__index = {}, __newindex = {}, __namecall = {}}
local _active_hooks = {__index = false, __newindex = false, __namecall = false}

local function debug_print(...)
    if shared.VW_hookmetamethod_debugging then
        print("[VW_hookmetamethod]", ...)
    end
end

local function debug_warn(...)
    if shared.VW_hookmetamethod_debugging then
        warn("[VW_hookmetamethod]", ...)
    end
end

local function _install_hook(hookType, object, value)
    local tbl = Script.hookmetamethod[hookType]
    _original_hooks[hookType] = _original_hooks[hookType] or {}
    _original_hooks[hookType][object] = _original_hooks[hookType][object] or {}
    debug_print("Installed hook ("..tostring(hookType).."): "..tostring(object))
    _original_hooks[hookType][object] = hookmetamethod(game, hookType, function(self, ...)
        local args = {...}
        local suc, res = pcall(value, self, unpack(args))
        if suc and res ~= Script.hookmetamethod.APPROVED_CONSTANT then
            if res ~= nil and type(res) == "table" then
                args = res
            else
                return res
            end
        end
        return _original_hooks[hookType][object](self, unpack(args))
    end)
    _active_hooks[hookType] = true
end

local function _uninstall_hook(hookType, object, value)
    if not _active_hooks[hookType] then return end
    debug_print("Uninstalling hook for", hookType, object, value)
    _original_hooks[hookType] = _original_hooks[hookType] or {}
    if _original_hooks[hookType][object] then
        hookmetamethod(game, hookType, _original_hooks[hookType][object])
        _original_hooks[hookType][object] = nil
    end
    _active_hooks[hookType] = false
end

local function _has_any_handlers(hookType, object)
    _original_hooks[hookType] = _original_hooks[hookType] or {}
    return _original_hooks[hookType][object] ~= nil
end

local function _handler_mt(hookType)
    return {
        __newindex = function(t, object, value)
            local had_handlers = _has_any_handlers(hookType, object)
            debug_warn("[Registry_ID]: "..tostring(object).." | [Registry_Value]: "..tostring(value).." | [Action Requested]: "..tostring(had_handlers))
            if not had_handlers then
                _install_hook(hookType, object, value)
            elseif had_handlers then
                _uninstall_hook(hookType, object, value)
            end
            debug_print("[", hookType, "] __newindex: object=", object, "value=", value)
        end,
        __index = function(t, object)
            return rawget(t, object)
        end,
        __pairs = function(t)
            return next, t, nil
        end
    }
end

Script.hookmetamethod = setmetatable({
    __index = setmetatable({}, _handler_mt("__index")),
    __newindex = setmetatable({}, _handler_mt("__newindex")),
    __namecall = setmetatable({}, _handler_mt("__namecall")),
    APPROVED_CONSTANT = "APPROVED_TRUE"
}, {
    __index = function(t, k) return rawget(t, k) end,
    __newindex = function(t, k, v) rawset(t, k, v) end
})

local SHOULD_WAIT_FOR_TOGGLES = false

function Script.Functions.CleanHooks()
    debug_print("Cleaning all hooks and handlers")
    SHOULD_WAIT_FOR_TOGGLES = false
    for hookType, tbl in pairs(Script.hookmetamethod) do
        if type(tbl) == "table" then
            for obj in pairs(tbl) do
                tbl[obj] = nil
            end
        end
        _uninstall_hook(hookType)
    end
end

local spoofedProps = {
    Velocity = Vector3.new(0, 0, 0),
    AssemblyLinearVelocity = Vector3.new(0, 0, 0)
}
local root
local lplr = game:GetService("Players").LocalPlayer

if shared.CHARACTER_ADDED_CONN then pcall(function() shared.CHARACTER_ADDED_CONN:Disconnect() end); shared.CHARACTER_ADDED_CONN = nil end

if lplr.Character then task.spawn(function() root = lplr.Character and lplr.Character:WaitForChild("HumanoidRootPart") end) end
shared.CHARACTER_ADDED_CONN = lplr.CharacterAdded:Connect(function() root = lplr.Character:WaitForChild("HumanoidRootPart") end)

if shared.VW_GAMESTATE_CHANGE then pcall(function() shared.VW_GAMESTATE_CHANGE:Disconnect() end) end

pcall(function() Script.GameState = workspace.Values.CurrentGame.Value end)

shared.VW_GAMESTATE_CHANGE = workspace:WaitForChild("Values"):WaitForChild("CurrentGame"):GetPropertyChangedSignal("Value"):Connect(function()
    pcall(function() Script.GameState = workspace.Values.CurrentGame.Value end)
end)

Script.HooksData = {}
Script.HooksData.CoreIndexHook = function(self, key)
    if not root then
        return Script.hookmetamethod.APPROVED_CONSTANT
    end
    if not checkcaller() and typeof(self) == "Instance" and self == root then
        if spoofedProps[key] ~= nil then
            return spoofedProps[key]
        end
        if key == "Position" then
            if shared.RLGLIsGreenLight == false and shared.RLGLLastRootPartCFrame then
                return shared.RLGLLastRootPartCFrame
            elseif shared.DISABLE_FALL_DETECTION_SKY_GAMES then
                -- nil
            end
        end
    end
    return Script.hookmetamethod.APPROVED_CONSTANT
end

Script.HooksData.CoreNamecallHook = function(self, ...)
    local method = getnamecallmethod and getnamecallmethod() or nil
    local args = {...}
    
    if tostring(self) == "rootCFrame" and method == "FireServer" and Script.GameState == "RedLightGreenLight" then
        if shared.RLGLIsGreenLight == false and shared.RLGLLastRootPartCFrame then
            args[1] = shared.RLGLLastRootPartCFrame
            return args
        end
    end
    
    if tostring(self) == "DALGONATEMPREMPTE" and method == "FireServer" then
        if args[1] ~= nil and type(args[1]) == "table" and args[1].CrackAmount ~= nil then
            return nil
        end
    end
    
    if tostring(self) == "TemporaryReachedBindable" and method == "FireServer" then
        if args[1] ~= nil and type(args[1]) == "table" and (args[1].FallingPlayer ~= nil or args[1].funnydeath ~= nil) then
            return nil
        end
    end
    
    if tostring(self) == "RandomOtherRemotes" and method == "FireServer" then
        if args[1] ~= nil and type(args[1]) == "table" and args[1].FallenOffMap ~= nil then
            return nil
        end
    end
    
    if tostring(self) == "UsePowerSpin" and method == "FireServer" then
        if args[1] ~= nil and string.find(tostring(args[1]), "rbxassetid") then
            return nil
        end
    end
    
    return Script.hookmetamethod.APPROVED_CONSTANT
end

Script.hookmetamethod.__index.CoreIndexHook = Script.HooksData.CoreIndexHook
Script.hookmetamethod.__namecall.CoreNamecallHook = Script.HooksData.CoreNamecallHook
