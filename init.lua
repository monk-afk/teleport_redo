local S = minetest.get_translator("teleport_redo")

local request_ttl = 60

local request_color = "#FFA500"
local sysmsg_color = "#FF4D00"

local tpp_places = {}
local tp_data = {}


local function send_player(player, message)
    minetest.chat_send_player(player, minetest.colorize(request_color, message))
end


local function play_sound(sound_pos)
  minetest.sound_play("tpr_warp", {pos = sound_pos, gain = 0.5, max_hear_distance = 10})
end


-- The following three functions sourced from minetest/builtin
local function teleport_to_pos(name, p)
    local lm = 31000
    if p.x < -lm or p.x > lm or p.y < -lm or p.y > lm
            or p.z < -lm or p.z > lm then
        return false, S("Cannot teleport out of map bounds!")
    end
    local teleportee = minetest.get_player_by_name(name)
    if not teleportee then
        return false, S("Cannot get player with name ") .. name
    end
    if teleportee:get_attach() then
        return false, S("Cannot teleport, @1 is attached to an object!", name)
    end
    teleportee:set_pos(p)
    play_sound(p)
    return true, S("Teleporting @1 to ", name) .. minetest.pos_to_string(p, 1)
end

local function find_free_position_near(pos)
    local tries = {
        {x=1, y=0, z=0},
        {x=-1, y=0, z=0},
        {x=0, y=0, z=1},
        {x=0, y=0, z=-1},
    }
    for _, d in ipairs(tries) do
        local p = vector.add(pos, d)
        local n = minetest.get_node_or_nil(p)
        if n then
            local def = minetest.registered_nodes[n.name]
            if def and not def.walkable then
                return p
            end
        end
    end
    return pos
end

local function teleport_to_player(name, target_name)
    local teleportee = minetest.get_player_by_name(name)
    if not teleportee then
        return false, S("Cannot get player with name ") .. name
    end
    if teleportee:get_attach() then
        return false, S("Cannot teleport, @1 is attached to an object!", name)
    end
    local target = minetest.get_player_by_name(target_name)
    if not target then
        return false, S("Cannot get player with name ") .. target_name
    end
    local p = find_free_position_near(target:get_pos())
    teleportee:set_pos(p)
    play_sound(p)
    return true, S("Teleporting @1 to @2 at position ", name, target_name) ..
        minetest.pos_to_string(p, 1)
end
------------- See LICENSE -----------------------------------------------------


  -- common check functions
local function get_or_create_data(player_name)
    local name = player_name:lower()
    local context = tp_data[name]
    if not context then
        context = {
            player_name = player_name,
            timestamp = os.time(), 
            request_pending = false,
            blocked_players = {},
            do_not_disturb = false,
        }
        tp_data[name] = context
    end
    return context
end

local function is_player_registered(player_name)
    return player_name and minetest.player_exists(player_name)
end

local function is_player_online(player_name)
    return minetest.get_player_by_name(player_name) ~= nil
end

local function has_enabled_dnd(player_tp_data)
    return player_tp_data.do_not_disturb
end

local function is_player_blocked(player_tp_data, target_name)
    return player_tp_data.blocked_players[target_name] ~= nil
end

local function has_pending_request(player_tp_data)
    return player_tp_data.request_pending ~= false
end


  -- tpr/tphr functions

local function queue_request_timeout(sender_tp_data, receiver_tp_data)
    minetest.after(request_ttl, function(sender_tp_data, receiver_tp_data)
        if has_pending_request(sender_tp_data) then
            sender_tp_data.request_pending = false
        end

        if has_pending_request(receiver_tp_data) then
            receiver_tp_data.request_pending = false
        end
    end, sender_tp_data, receiver_tp_data)
end

local function add_teleport_request(sender_tp_data, receiver_tp_data, target, destination)
    sender_tp_data.request_pending = true
    receiver_tp_data.request_pending = {target, destination}
    
    queue_request_timeout(sender_tp_data, receiver_tp_data)
end

local function request_teleport(sender, param, destination)
    local receiver = param:match("^([^ ]+)$")

    if sender == receiver then
      return true, S("One does not teleport to oneself.")
    elseif not is_player_registered(receiver) then
        return true, S("Not a valid player name, please check the spelling and try again.")
    elseif not is_player_online(param) or not is_player_online(sender) then
        return true, S("Sender and receiver must be online to request teleport")
    end

    local sender_tp_data = get_or_create_data(sender)
    local receiver_tp_data = get_or_create_data(receiver)

    if is_player_blocked(sender_tp_data, receiver) or is_player_blocked(receiver_tp_data, sender)
            or has_enabled_dnd(sender_tp_data) or has_enabled_dnd(receiver_tp_data) then
        return true, S("You or the receiver has an active Do Not Disturb policy")

    elseif has_pending_request(sender_tp_data) or has_pending_request(receiver_tp_data) then
        return true, S("You or the recipient have a pending teleport request. Please wait a moment before trying again.")
    end

    local msg
    if destination == sender then -- tphr
        msg = S("@1 requested you teleport to them", sender)
        add_teleport_request(sender_tp_data, receiver_tp_data, receiver, sender)

    elseif destination == receiver then -- tpr
        msg = S("@1 requested to teleport to you", sender)
        add_teleport_request(sender_tp_data, receiver_tp_data, sender, receiver)
    end

    send_player(receiver, msg)
    send_player(sender, S("Teleport request sent! It will timeout in @1 seconds.", request_ttl))
end

minetest.register_chatcommand("tpr", {
    description = S("Request teleport to player"),
    params = S("<name>"),
    privs = {interact = true},
    func = function(name, param)
        return request_teleport(name, param, param)
    end
})

minetest.register_chatcommand("tphr", {
    description = S("Request a player teleport to you"),
    params = S("<name>"),
    privs = {interact = true},
    func = function(name, param)
        return request_teleport(name, param, name)
    end
})


  -- tpy/tpn functions

local function respond_to_request(name, accept_request)
    local player_tp_data = get_or_create_data(name)

    if not has_pending_request(player_tp_data) or
            type(player_tp_data.request_pending) ~= "table" then
        return true, S("You have no pending teleport requests")
    end

    local target = player_tp_data.request_pending[1]
    local destination = player_tp_data.request_pending[2]

    if accept_request then
        player_tp_data.request_pending = true
        return teleport_to_player(target, destination)
    else
        send_player(target, S("Teleport request denied!"))
        send_player(destination, S("Teleport request denied!"))
        player_tp_data.request_pending = false
    end
end

minetest.register_chatcommand("tpy", {
    description = S("Accept teleport requests from another player"),
    params = "",
    privs = {interact = true},
    func = function(name)
        return respond_to_request(name, true)
    end
})

minetest.register_chatcommand("tpn", {
    description = S("Deny teleport requests from another player"),
    params = "",
    privs = {interact = true},
    func = function(name)
        return respond_to_request(name)
    end
})


  -- tpdnd functions

local function toggle_tpr_block(player_tp_data, target_name)
    local msg
    if player_tp_data.blocked_players[target_name] then
        player_tp_data.blocked_players[target_name] = nil
        msg = S("Allowing teleport requests from @1", target_name)
    else
        player_tp_data.blocked_players[target_name] = true
        msg = S("Refusing teleport requests from @1", target_name)
    end
    send_player(player_tp_data.player_name, msg)
end

local function list_blocked_players(player_tp_data)
    local blocked_list = {}
    for blocked_player, _ in pairs(player_tp_data.blocked_players) do
        table.insert(blocked_list, blocked_player)
    end
    return table.concat(blocked_list, ", ")
end

local function toggle_dnd(name, param)
    local param = param:match("^([^ ]+)$")
    local player_tp_data = get_or_create_data(name)

    if not param then
        player_tp_data.do_not_disturb = not player_tp_data.do_not_disturb
        local status = player_tp_data.do_not_disturb 
                and S("You have enabled Do Not Disturb - Teleport requests will be ignored")
                or  S("You have disabled Do Not Disturb - Receiving teleport requests")
        minetest.chat_send_player(name, status)

    elseif name == param then
      return false, S("Unable to block teleport requests from yourself.")

    elseif param == "!show" then
        local blocked_players = list_blocked_players(player_tp_data)
        if blocked_players == "" then
            return true, S("Block list is empty!")
        else
            return true, S("Blocked players: ") .. blocked_players
        end

    elseif param == "!clear" then
        player_tp_data.blocked_players = {}
        return true, S("Your teleport block list has been cleared.")

    elseif is_player_registered(param) then
        toggle_tpr_block(player_tp_data, param)

    else
        return false, S("Player '@1' does not exist.", param)
    end
end

minetest.register_chatcommand("tpdnd", {
    description = S("Block teleport requests from selected or all players"),
    params = "< >|"..S("<name>").."|<!show>|<!clear>",
    privs = {interact = true},
    func = toggle_dnd
})


  -- tpp functions

local function tpp_view_or_visit(name, param)
    local param = param:match("^([^ ]+)$")

    if not param then
        local places = {}
        for key, value in pairs(tpp_places) do
            table.insert(places, key)
        end

        table.insert(places, S("Usage: ").."/tpp <place>")
        return true, table.concat(places, "\n")
    end

    local tpp_place = tpp_places[param:lower()]

    if tpp_place then
        local p = vector.apply(tpp_place, tonumber)

        if p.x and p.y and p.z then
            return teleport_to_pos(name, p)
        end
    end
end

minetest.register_chatcommand("tpp", {
    description = S("List or visit the available Public Places."),
    params = "[ |place] -- "..S("Without parameter will list all places."),
    privs = {interact = true},
    func = tpp_view_or_visit
})


local places_file = minetest.get_modpath(minetest.get_current_modname()).."/tpp_places.lua"
local function load_tp_places()
    tpp_places = {}
    tpp_places = dofile(places_file)
end
load_tp_places()

minetest.register_chatcommand("tpp_reload", {
    description = S("Reload Public Places from file."),
    params = "",
    privs = {server = true},
    func = load_tp_places
})


  -- other

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if tp_data[name] then
        tp_data[name].timestamp = os.time()
    end
end)


local int = math.random(3500, 3800)
local function purge_offline()
    local time_past = os.time() + int
    for name, player in pairs(tp_data) do
        if not is_player_online(player.player_name) then
            if player.timestamp < time_past then
                tp_data[name] = nil
            end
        end
    end
    minetest.after(int, purge_offline)
end
minetest.after(int, purge_offline)
