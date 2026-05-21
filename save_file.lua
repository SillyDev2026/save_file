EnableGlobals()

local IO = require("io")
local PlayerData = {}

function savePath(workshop_id, saveType)
    return "players\\311210\\" .. workshop_id .. "\\" .. saveType
end

PlayerData.path = savePath(3726841077, "save.json")
PlayerData.version = 1

PlayerData.schema = {
    ["player.level"] = { type = "i", owner = "gsc", default = 1 },
    ["player.xp"] = { type = "i", owner = "gsc", default = 0 },
    ["player.prestige"] = { type = "i", owner = "gsc", default = 0 },
    ["player.downs"] = { type = "i", owner = "gsc", default = 0 },
    ["player.kills"] = { type = "i", owner = "gsc", default = 0 },
}

PlayerData.state = {}
PlayerData.dirty = {}
PlayerData.listeners = {}

function cast_from_string(t, v)
    if t == "i" or t == "f" then
        return tonumber(v) or 0
    elseif t == "b" then
        return v == "1" or v == "true"
    else
        return v
    end
end

function cast_to_string(t, v)
    if t == "b" then
        return v and "1" or "0"
    else
        return tostring(v)
    end
end

function split_namespace(fullKey)
    local ns, key = fullKey:match("^(.-)%.(.+)$")
    return ns or "", key or fullKey
end

function PlayerData.init()
    for k, def in pairs(PlayerData.schema) do
        PlayerData.state[k] = def.default
    end
    PlayerData.load()
end

function PlayerData.load()
    local file = IO.open(PlayerData.path, "r")
    if not file then return end

    local currentNamespace = ""

    for line in file:lines() do
        if line == "" or line:sub(1,1) == "#" then
        elseif line:match("^version=") then
        else
            local section = line:match("^%[(.-)%]$")
            if section then
                currentNamespace = section
            else
                if currentNamespace == "player" then
                    local left, valueStr = line:match("^(.-)=(.+)$")
                    if left and valueStr then
                        local keyPart, t = left:match("^(.-):(.*)$")
                        if keyPart and t then
                            local fullKey = "player." .. keyPart
                            local def = PlayerData.schema[fullKey]
                            if def then
                                local v = cast_from_string(t, valueStr)
                                PlayerData.state[fullKey] = v
                            end
                        end
                    end
                end
            end
        end
    end

    file:close()
end

function PlayerData.save(forceAll)
    local file = IO.open(PlayerData.path, "w")
    if not file then return end

    file:write("version=" .. PlayerData.version .. "\n")
    file:write("last_write_side=lua\n")
    file:write("[player]\n")

    for fullKey, def in pairs(PlayerData.schema) do
        local ns, keyPart = split_namespace(fullKey)
        if ns == "player" then
            local t = def.type
            local v = PlayerData.state[fullKey]
            local vStr = cast_to_string(t, v)
            file:write(string.format("%s:%s=%s\n", keyPart, t, vStr))
        end
    end

    file:close()
    PlayerData.dirty = {}
end

function PlayerData.get(key)
    return PlayerData.state[key]
end

function PlayerData.set(key, value)
    local def = PlayerData.schema[key]
    if not def then return end

    local old = PlayerData.state[key]
    if old == value then return end

    PlayerData.state[key] = value
    PlayerData.dirty[key] = true

    local listeners = PlayerData.listeners[key]
    if listeners then
        for _, cb in ipairs(listeners) do
            cb(value, old)
        end
    end
end

function PlayerData.on_change(key, callback)
    if not PlayerData.listeners[key] then
        PlayerData.listeners[key] = {}
    end
    table.insert(PlayerData.listeners[key], callback)
end

return PlayerData
