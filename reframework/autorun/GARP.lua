-- Gogma Artian Roll Planner
-- Artian/Gogma skill and reinforcement route planner for Monster Hunter Wilds.

local MOD_NAME = "Gogma Artian Roll Planner"
local VERSION = "0.2.42"
local CONFIG_PATH = "GogmaArtianRollPlanner.json"
local EXPORT_DIRECTORY = "Gogma Artian Roll Planner"
local EXPORT_PATH = EXPORT_DIRECTORY .. "/GogmaArtianRollPlannerPredictions.csv"
local SELECTED_PROBE_PATH = EXPORT_DIRECTORY .. "/SelectedWeaponProbe.txt"
local UINT32_MASK = 0xffffffff

local state = {
    enabled = true,
    debug = false,
    include_base_predictions = true,
    include_skill_predictions = true,
    include_gogma_predictions = true,
    desired_set_skill = 1,
    desired_group_skill = 1,
    desired_base_reinforcement_1 = 1,
    desired_base_reinforcement_2 = 1,
    desired_base_reinforcement_3 = 1,
    desired_base_reinforcement_4 = 4,
    desired_base_reinforcement_5 = 2,
    desired_gogma_reinforcement_1 = 3,
    desired_gogma_reinforcement_2 = 3,
    desired_gogma_reinforcement_3 = 2,
    desired_gogma_reinforcement_4 = 10,
    desired_gogma_reinforcement_5 = 6,
    last_artian_skill_type = nil,
    predicted_skill_type = nil,
    exact_reroll_distance = nil,
    skill_prediction_valid = nil,
    skill_counter_is_next = false,
    skill_route_cache_key = nil,
    rng_base_seed = nil,
    rng_base_seed_raw = nil,
    rng_counter_gate = nil,
    rng_counter = nil,
    rng_base_bonus = nil,
    rng_attribute_force = nil,
    rng_weapon_type = nil,
    artian_create_weapon_type = nil,
    artian_create_rarity = nil,
    artian_create_count_before = nil,
    artian_create_count_after = nil,
    base_reinforcement_predicted = nil,
    base_reinforcement_actual = nil,
    base_reinforcement_prediction_valid = nil,
    base_reinforcement_validation_detail = nil,
    base_reinforcement_pool = nil,
    base_reinforcement_pool_detail = nil,
    base_reinforcement_pool_source = nil,
    base_forge_route_cache_key = nil,
    base_forge_route_distance = nil,
    base_forge_route_value = nil,
    base_forge_route_unavailable = nil,
    gogma_current_value = nil,
    gogma_next_counter = nil,
    gogma_route_cache_key = nil,
    gogma_route_distance = nil,
    gogma_route_mode = nil,
    gogma_route_reset_count = nil,
    gogma_route_keep_count = nil,
    gogma_route_value = nil,
    export_status = nil,
    last_error = "",
}

-- Optional research probes are isolated here and never write to disk.
local debug_state = {
    gogma_roll_calls = 0,
    gogma_arg_index = nil,
    gogma_mode = nil,
    gogma_before = nil,
    gogma_after = nil,
    gogma_rng = nil,
    gogma_prediction = nil,
    gogma_prediction_valid = nil,
    gogma_error = nil,
    gogma_samples = {},
    target_bonus_calls = {},
    selected_weapon_calls = 0,
    selected_weapon_type = nil,
    selected_weapon_fields = {},
    selected_context_fields = {},
    selected_context_details = {},
    selected_weapon_equip_work = nil,
    selected_weapon_error = nil,
    selected_weapon_file_status = nil,
}

local set_skill_names = {
    "Arkveld's Hunger", "Blangonga's Spirit", "Doshaguma's Might",
    "Ebony Odogaron's Power", "Fulgur Anjanath's Will", "Gogmapocalypse",
    "Gore Magala's Tyranny", "Gravios's Protection", "Guardian Arkveld's Vitality",
    "Jin Dahaad's Revolt", "Leviathan's Fury", "Mizutsune's Prowess",
    "Nu Udra's Mutiny", "Omega Resonance", "Rathalos's Flare",
    "Rey Dau's Voltage", "Seregios's Tenacity", "Soul of the Dark Knight",
    "Uth Duna's Cover", "Xu Wu's Vigor", "Zoh Shia's Pulse",
}

local group_skill_names = {
    "Alluring Pelt", "Buttery Leathercraft", "Flexible Leathercraft",
    "Fortifying Pelt", "Guardian's Protection", "Guardian's Pulse",
    "Imparted Wisdom", "Lord's Favor", "Lord's Fury", "Lord's Soul",
    "Neopteron Alert", "Neopteron Camouflage", "Scale Layering", "Scaling Prowess",
}

local artian_set_table_order = {
    "Doshaguma's Might", "Rathalos's Flare", "Xu Wu's Vigor", "Gravios's Protection",
    "Blangonga's Spirit", "Ebony Odogaron's Power", "Fulgur Anjanath's Will",
    "Uth Duna's Cover", "Rey Dau's Voltage", "Nu Udra's Mutiny",
    "Jin Dahaad's Revolt", "Gore Magala's Tyranny", "Arkveld's Hunger",
    "Guardian Arkveld's Vitality", "Mizutsune's Prowess", "Zoh Shia's Pulse",
    "Leviathan's Fury", "Seregios's Tenacity", "Gogmapocalypse",
    "Soul of the Dark Knight", "Omega Resonance",
}

local artian_group_table_order = {
    "Neopteron Alert", "Neopteron Camouflage", "Flexible Leathercraft",
    "Buttery Leathercraft", "Scaling Prowess", "Scale Layering", "Fortifying Pelt",
    "Alluring Pelt", "Lord's Favor", "Lord's Fury", "Guardian's Pulse",
    "Guardian's Protection", "Imparted Wisdom", "Lord's Soul",
}

local base_reinforcement_id_names = {
    [4] = "Element Boost / I",
    [6] = "Attack Boost / I",
    [7] = "Sharpness Boost",
    [8] = "Affinity Boost / I",
}
local base_reinforcement_selector_ids = { 6, 8, 4, 7 }
local base_reinforcement_rng_ids = { 4, 6, 7, 8 }
local base_reinforcement_names = {}
for _, id in ipairs(base_reinforcement_selector_ids) do
    table.insert(base_reinforcement_names, base_reinforcement_id_names[id])
end

local gogma_bonus_ids = { 8, 12, 15, 9, 13, 16, 11, 14, 6, 10 }
local gogma_bonus_names_by_id = {
    [6] = "Sharpness Boost",
    [8] = "Attack Boost II",
    [9] = "Affinity Boost II",
    [10] = "Sharpness/Ammo Boost EX",
    [11] = "Element Boost II",
    [12] = "Attack Boost III",
    [13] = "Affinity Boost III",
    [14] = "Element Boost EX",
    [15] = "Attack Boost EX",
    [16] = "Affinity Boost EX",
}
local gogma_bonus_names = {}
for _, id in ipairs(gogma_bonus_ids) do
    table.insert(gogma_bonus_names, gogma_bonus_names_by_id[id])
end

local installed_hooks = {}
local current_skill_equip_work = nil
local current_skill_capture = nil
local current_weapon_type_out = nil
local resolving_skill_type = false
local latest_create_counter = nil
local pending_base_prediction = nil
local active_base_pool_capture = nil
local lottery_method = nil
local base_bonus_method = nil
local attribute_force_method = nil
local artian_skill_type_method = nil

local function type_name_of(object)
    if object == nil then
        return nil
    end
    local ok, name = pcall(function()
        return object:get_type_definition():get_full_name()
    end)
    return ok and name or nil
end

local function inspect_selected_weapon_object(object, depth, fields, visited)
    if object == nil or depth > 2 then
        return nil
    end
    local address = tostring(object)
    if visited[address] then
        return nil
    end
    visited[address] = true
    local type_def = object:get_type_definition()
    local object_type = type_def:get_full_name()
    if object_type == "app.savedata.cEquipWork" then
        return object
    end
    for _, field in ipairs(type_def:get_fields()) do
        local field_name = field:get_name()
        local field_type = field:get_type():get_full_name()
        local value = nil
        local value_ok, field_value = pcall(function()
            return object:get_field(field_name)
        end)
        if value_ok then
            value = field_value
        end
        local scalar = field_type:find("System.", 1, true) == 1
            or field_type:find("WeaponDef.", 1, true) ~= nil
            or field_type:find("ItemDef.", 1, true) ~= nil
        local suffix = scalar and (" = " .. tostring(value)) or ""
        table.insert(fields, string.rep("  ", depth) .. field_name .. ": "
            .. field_type .. suffix)
        if field_type == "app.savedata.cEquipWork" then
            if value ~= nil then
                return value
            end
        elseif depth < 2 and (field_type:find("WeaponInfo", 1, true)
                or field_type:find("WeaponData", 1, true)
                or field_type:find("EquipSet", 1, true)
                or field_type:find("PartsArtianList", 1, true)
                or field_type:find("EquipWork", 1, true)) then
            if value ~= nil then
                local found = inspect_selected_weapon_object(
                    value, depth + 1, fields, visited
                )
                if found ~= nil then
                    return found
                end
            end
        end
    end
    return nil
end

local function resolve_data_path(relative_path)
    if fs ~= nil and fs.get_game_path ~= nil then
        if fs.create_directory ~= nil then
            pcall(fs.create_directory, fs.get_game_path(EXPORT_DIRECTORY))
        end
        return fs.get_game_path(relative_path)
    end
    return relative_path
end

local function write_selected_weapon_probe()
    local path = resolve_data_path(SELECTED_PROBE_PATH)
    local file, err = io.open(path, "w")
    if file == nil then
        debug_state.selected_weapon_file_status = "Probe write failed: " .. tostring(err)
        return
    end
    file:write("Selected weapon probe\n")
    file:write("Selections: ", tostring(debug_state.selected_weapon_calls), "\n")
    file:write("Type: ", tostring(debug_state.selected_weapon_type), "\n")
    file:write("Equip work: ", tostring(debug_state.selected_weapon_equip_work), "\n")
    file:write("Error: ", tostring(debug_state.selected_weapon_error), "\n\n")
    file:write("WeaponInfo details\n")
    for _, line in ipairs(debug_state.selected_weapon_fields) do
        file:write(line, "\n")
    end
    file:write("\nSelected controller context\n")
    for _, line in ipairs(debug_state.selected_context_fields) do
        file:write(line, "\n")
    end
    file:write("\nSelected context details\n")
    for _, line in ipairs(debug_state.selected_context_details) do
        file:write(line, "\n")
    end
    file:close()
    debug_state.selected_weapon_file_status = "Probe file: SelectedWeaponProbe.txt"
end

local function u32(value)
    return value & UINT32_MASK
end

local function table_skill_type_from_runtime(value)
    value = tonumber(value)
    return value
end

local function clamp_index(value, values)
    value = tonumber(value) or 1
    return math.max(1, math.min(#values, math.floor(value)))
end

local function load_config()
    local ok, loaded = pcall(json.load_file, CONFIG_PATH)
    if ok and type(loaded) == "table" then
        for key, value in pairs(loaded) do
            if state[key] ~= nil then
                state[key] = value
            end
        end
    end
    state.desired_set_skill = clamp_index(state.desired_set_skill, set_skill_names)
    state.desired_group_skill = clamp_index(state.desired_group_skill, group_skill_names)
    for slot = 1, 5 do
        local key = "desired_base_reinforcement_" .. tostring(slot)
        state[key] = clamp_index(state[key], base_reinforcement_names)
        key = "desired_gogma_reinforcement_" .. tostring(slot)
        state[key] = clamp_index(state[key], gogma_bonus_names)
    end
end

local function save_config()
    local persisted = {
        enabled = state.enabled,
        include_base_predictions = state.include_base_predictions,
        include_skill_predictions = state.include_skill_predictions,
        include_gogma_predictions = state.include_gogma_predictions,
        desired_set_skill = state.desired_set_skill,
        desired_group_skill = state.desired_group_skill,
    }
    for slot = 1, 5 do
        local key = "desired_base_reinforcement_" .. tostring(slot)
        persisted[key] = state[key]
        key = "desired_gogma_reinforcement_" .. tostring(slot)
        persisted[key] = state[key]
    end
    local ok, err = pcall(json.dump_file, CONFIG_PATH, persisted)
    if not ok then
        state.last_error = "Config save failed: " .. tostring(err)
    end
end

local function index_of(values, target)
    for index, value in ipairs(values) do
        if value == target then
            return index
        end
    end
    return nil
end

local function artian_skill_type_for_names(set_name, group_name)
    local set_index = index_of(artian_set_table_order, set_name)
    local group_index = index_of(artian_group_table_order, group_name)
    if set_index == nil or group_index == nil then
        return nil
    end
    if set_index == 1 then
        local first_block = { 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15 }
        return first_block[group_index]
    end
    local block_start = 16 + (set_index - 2) * 15
    return group_index == 14 and block_start + 14 or block_start + group_index - 1
end

local function names_for_artian_skill_type(skill_type)
    skill_type = tonumber(skill_type)
    if skill_type == nil then
        return nil, nil
    end

    for _, set_name in ipairs(artian_set_table_order) do
        for _, group_name in ipairs(artian_group_table_order) do
            if artian_skill_type_for_names(set_name, group_name) == skill_type then
                return set_name, group_name
            end
        end
    end
    return nil, nil
end

local function read_address_value(address, value_type, method_name)
    local value = sdk.to_valuetype(sdk.to_ptr(address), value_type)
    return value[method_name](value, 0)
end

local function read_qword(address)
    return read_address_value(address, "System.UInt64", "read_qword")
end

local function read_dword(address)
    return read_address_value(address, "System.UInt32", "read_dword")
end

local function read_skill_rng_state()
    if lottery_method == nil then
        return nil
    end
    local address = sdk.to_int64(lottery_method:get_function())
    local type_info = read_qword(address + 0x106d54f8)
    local static_holder = read_qword(type_info + 0x80)
    local static_array = read_qword(static_holder + 0x10)
    local static_index = read_dword(type_info + 0xe0)
    local static_data = read_qword(static_array + static_index * 8 + 0x20)
    local counter_wrapper = read_qword(static_data + 0x1e0)
    local counter_object = read_qword(counter_wrapper + 0x10)
    local base_seed_raw = read_qword(static_data + 0x170)
    return {
        base_seed_raw = base_seed_raw,
        base_seed = base_seed_raw % 100000000,
        counter_gate = read_dword(counter_object + 0x1c),
        counter = read_dword(counter_object + 0xf4),
        gogma_counter = read_dword(counter_object + 0xa8),
    }
end

local function rng_step(x, y, z, w)
    local t = u32(x ~ u32(x << 15))
    local next_w = u32(w ~ (w >> 21) ~ t ~ (t >> 4))
    return y, z, w, next_w
end

local function initialize_rng(seed)
    local seed_state = u32(seed)
    local x = 0x159a55e5
    local y = 0x1f123bb5
    local z = 0x05491333
    local w = z
    for iteration = 1, 100 do
        local mixed = u32((0x65ac9365 >> (seed_state & 3)) ~ seed_state)
        seed_state = u32(
            u32(mixed << 4) ~ u32(mixed << 3)
            ~ (mixed >> 3) ~ (mixed >> 4) ~ mixed
        )
        local t = u32(seed_state ~ u32(seed_state << 15))
        local next_w = u32(z ~ (z >> 21) ~ t ~ (t >> 4))
        x, y, z, w = x, y, z, next_w
        if iteration < 100 then
            x, y, z = y, z, w
        end
    end
    return x, y, z, w
end

local function initialize_gogma_rng(capture)
    if capture == nil or capture.base_seed == nil or capture.weapon_type == nil
        or capture.attribute_force == nil or capture.gogma_counter == nil then
        return nil
    end
    local seed = u32(
        capture.base_seed + capture.weapon_type * 1000 + capture.attribute_force
    ) ~ 0x00ac9365
    local x, y, z, w = initialize_rng(seed)
    local steps = capture.counter_gate ~= nil and capture.counter_gate < 0x23
        and 0 or capture.gogma_counter * 10
    for _ = 1, steps do
        x, y, z, w = rng_step(x, y, z, w)
    end
    return { x = x, y = y, z = z, w = w }
end

local function select_weighted_gogma_bonus(rng, pool)
    if rng == nil or pool == nil or #pool == 0 then
        return nil
    end
    rng.x, rng.y, rng.z, rng.w = rng_step(rng.x, rng.y, rng.z, rng.w)
    local total = 0
    for _, entry in ipairs(pool) do
        total = total + entry.probability
    end
    if total <= 0 then
        return nil
    end
    local roll = rng.w % total
    for _, entry in ipairs(pool) do
        if roll < entry.probability then
            return entry.bonus_id, roll, total
        end
        roll = roll - entry.probability
    end
    return nil
end

local function unpack_gogma_bonus_ids(packed)
    local ids = {}
    packed = tonumber(packed)
    if packed == nil then
        return ids
    end
    for _ = 1, 5 do
        table.insert(ids, (packed % 1000) - 1)
        packed = math.floor(packed / 1000)
    end
    return ids
end

local function selected_gogma_bonus_ids()
    local ids = {}
    for slot = 1, 5 do
        local selected = state["desired_gogma_reinforcement_" .. tostring(slot)] or 1
        table.insert(ids, gogma_bonus_ids[selected])
    end
    return ids
end

local function gogma_repeat_penalty(id)
    return (id == 10 or id == 14 or id == 15 or id == 16) and 80 or 50
end

local function gogma_keep_family(id)
    if id == 8 or id == 12 or id == 15 then
        return { 8, 12, 15 }
    elseif id == 9 or id == 13 or id == 16 then
        return { 9, 13, 16 }
    elseif id == 11 or id == 14 then
        return { 11, 14 }
    elseif id == 6 or id == 10 then
        return { 6, 10 }
    end
    return {}
end

local function gogma_family_id(id)
    if id == 8 or id == 12 or id == 15 then
        return 1
    elseif id == 9 or id == 13 or id == 16 then
        return 2
    elseif id == 11 or id == 14 then
        return 3
    elseif id == 6 or id == 10 then
        return 4
    end
    return 0
end

local function gogma_family_layout(packed)
    local layout = 0
    local multiplier = 1
    for _, id in ipairs(unpack_gogma_bonus_ids(packed)) do
        layout = layout + gogma_family_id(id) * multiplier
        multiplier = multiplier * 5
    end
    return layout
end

local function build_gogma_pool(mode, current_id, selected_ids)
    local candidates = mode == 1 and gogma_keep_family(current_id) or gogma_bonus_ids
    local counts = {}
    for _, id in ipairs(selected_ids) do
        counts[id] = (counts[id] or 0) + 1
    end
    local pool = {}
    for _, id in ipairs(candidates) do
        local weight = math.max(0, 100 - (counts[id] or 0) * gogma_repeat_penalty(id))
        if weight > 0 then
            table.insert(pool, { bonus_id = id, probability = weight })
        end
    end
    return pool
end

local function simulate_gogma_roll(rng, packed, mode)
    local current_ids = unpack_gogma_bonus_ids(packed)
    local selected_ids = {}
    local result = 0
    local multiplier = 1
    for slot = 1, 5 do
        local pool = build_gogma_pool(mode, current_ids[slot], selected_ids)
        local id = select_weighted_gogma_bonus(rng, pool)
        if id == nil then
            return nil, nil
        end
        table.insert(selected_ids, id)
        result = result + (id + 1) * multiplier
        multiplier = multiplier * 1000
    end
    return result, selected_ids
end

local function skill_type_from_table_index(index)
    local set_index = math.floor(index / #artian_group_table_order) + 1
    local group_index = (index % #artian_group_table_order) + 1
    return artian_skill_type_for_names(
        artian_set_table_order[set_index],
        artian_group_table_order[group_index]
    )
end

local function predict_skill_route(capture, desired_skill_type)
    if capture == nil or capture.weapon_type == nil or capture.attribute_force == nil
        or capture.base_seed == nil or capture.counter == nil then
        return nil, nil
    end
    local seed = u32(
        capture.weapon_type * 1000 + capture.attribute_force + capture.base_seed
    ) ~ 0x00ac9365
    local x, y, z, w = initialize_rng(seed)
    local counter_steps = capture.counter_gate ~= nil and capture.counter_gate < 0x36
        and 0 or capture.counter * 10
    for _ = 1, counter_steps do
        x, y, z, w = rng_step(x, y, z, w)
    end
    x, y, z, w = rng_step(x, y, z, w)
    local predicted_current = skill_type_from_table_index(w % 294)
    local distance = nil
    for rerolls = 1, 5000 do
        if not (capture.counter_is_next and rerolls == 1) then
            for _ = 1, 10 do
                x, y, z, w = rng_step(x, y, z, w)
            end
        end
        if skill_type_from_table_index(w % 294) == desired_skill_type then
            distance = rerolls
            break
        end
    end
    return predicted_current, distance
end

local function refresh_skill_route()
    local desired_type = artian_skill_type_for_names(
        set_skill_names[state.desired_set_skill],
        group_skill_names[state.desired_group_skill]
    )
    local cache_key = table.concat({
        tostring(state.rng_weapon_type), tostring(state.rng_attribute_force),
        tostring(state.rng_base_seed), tostring(state.rng_counter),
        tostring(state.rng_counter_gate), tostring(state.skill_counter_is_next),
        tostring(desired_type),
    }, "|")
    if cache_key == state.skill_route_cache_key then
        return
    end
    state.skill_route_cache_key = cache_key
    local capture = {
        weapon_type = state.rng_weapon_type,
        attribute_force = state.rng_attribute_force,
        base_seed = state.rng_base_seed,
        counter = state.rng_counter,
        counter_gate = state.rng_counter_gate,
        counter_is_next = state.skill_counter_is_next,
    }
    local predicted, distance = predict_skill_route(capture, desired_type)
    state.predicted_skill_type = predicted
    state.exact_reroll_distance = distance
end

local function default_base_reinforcement_pool()
    local fallback_max_counts = { [4] = 5, [6] = 5, [7] = 2, [8] = 5 }
    local pool = {}
    for _, bonus_id in ipairs(base_reinforcement_rng_ids) do
        table.insert(pool, {
            bonus_id = bonus_id,
            count = 0,
            max_count = fallback_max_counts[bonus_id],
        })
    end
    return pool
end

local function clone_base_reinforcement_pool(source)
    local pool = {}
    for _, entry in ipairs(source or {}) do
        table.insert(pool, {
            bonus_id = entry.bonus_id,
            count = entry.count or 0,
            max_count = entry.max_count or 5,
        })
    end
    return pool
end

local function set_base_reinforcement_pool(pool, source)
    state.base_reinforcement_pool = clone_base_reinforcement_pool(pool)
    local detail = {}
    for _, entry in ipairs(pool) do
        table.insert(detail, table.concat({
            tostring(entry.bonus_id), tostring(entry.count or 0),
            tostring(entry.max_count),
        }, ":"))
    end
    state.base_reinforcement_pool_detail = table.concat(detail, ",")
    state.base_reinforcement_pool_source = source
    state.base_forge_route_cache_key = nil
end

local function draw_base_reinforcement(x, y, z, w, source_pool)
    local pool = clone_base_reinforcement_pool(source_pool)
    local bonuses = {}
    local packed = 0
    local multiplier = 1
    for _ = 1, 5 do
        if #pool == 0 then
            break
        end
        x, y, z, w = rng_step(x, y, z, w)
        local index = (w % #pool) + 1
        local entry = pool[index]
        table.insert(bonuses, entry.bonus_id)
        packed = packed + entry.bonus_id * multiplier
        multiplier = multiplier * 1000
        entry.count = entry.count + 1
        if entry.count >= entry.max_count then
            table.remove(pool, index)
        end
    end
    return x, y, z, w, packed, bonuses
end

local function predict_base_reinforcement(
    base_seed, weapon_type, rarity, create_count, source_pool
)
    if base_seed == nil or weapon_type == nil or rarity == nil or create_count == nil then
        return nil, nil
    end
    local seed = u32(base_seed + weapon_type * 1000 + rarity) ~ 0x00ac9365
    local x, y, z, w = initialize_rng(seed)
    for _ = 1, create_count * 10 do
        x, y, z, w = rng_step(x, y, z, w)
    end
    local pool = source_pool or default_base_reinforcement_pool()
    local packed, bonuses
    x, y, z, w, packed, bonuses =
        draw_base_reinforcement(x, y, z, w, pool)
    return packed, bonuses
end

local function fit_base_reinforcement_pool(
    base_seed, weapon_type, rarity, create_count, actual
)
    if actual == nil then
        return nil
    end
    local seed = u32(base_seed + weapon_type * 1000 + rarity) ~ 0x00ac9365
    local x, y, z, w = initialize_rng(seed)
    for _ = 1, create_count * 10 do
        x, y, z, w = rng_step(x, y, z, w)
    end
    local rolls = {}
    for index = 1, 5 do
        x, y, z, w = rng_step(x, y, z, w)
        rolls[index] = w
    end

    local best_pool = nil
    local best_distance = math.huge
    local default_limits = { [4] = 5, [6] = 5, [7] = 2, [8] = 5 }

    local function test_limits(order, limits, position)
        if position <= #order then
            for maximum = 1, 5 do
                limits[position] = maximum
                test_limits(order, limits, position + 1)
            end
            return
        end
        local pool = {}
        local capacity = 0
        for index, bonus_id in ipairs(order) do
            capacity = capacity + limits[index]
            table.insert(pool, {
                bonus_id = bonus_id,
                count = 0,
                max_count = limits[index],
            })
        end
        if capacity < 5 then
            return
        end
        local candidate = clone_base_reinforcement_pool(pool)
        local packed = 0
        local multiplier = 1
        for _, roll in ipairs(rolls) do
            local selected = (roll % #candidate) + 1
            local entry = candidate[selected]
            packed = packed + entry.bonus_id * multiplier
            multiplier = multiplier * 1000
            entry.count = entry.count + 1
            if entry.count >= entry.max_count then
                table.remove(candidate, selected)
            end
        end
        if packed == actual then
            local distance = (4 - #order) * 10
            for index, bonus_id in ipairs(order) do
                distance = distance
                    + math.abs(limits[index] - default_limits[bonus_id])
            end
            if distance < best_distance then
                best_pool = pool
                best_distance = distance
            end
        end
    end

    local function test_orders(remaining, order)
        if #order > 0 then
            test_limits(order, {}, 1)
        end
        for index, bonus_id in ipairs(remaining) do
            local next_remaining = {}
            for other_index, other_id in ipairs(remaining) do
                if other_index ~= index then
                    table.insert(next_remaining, other_id)
                end
            end
            local next_order = {}
            for _, existing_id in ipairs(order) do
                table.insert(next_order, existing_id)
            end
            table.insert(next_order, bonus_id)
            test_orders(next_remaining, next_order)
        end
    end
    test_orders(base_reinforcement_rng_ids, {})
    return best_pool
end

local function same_multiset(left, right)
    if #(left or {}) ~= #(right or {}) then
        return false
    end
    local counts = {}
    for _, value in ipairs(left) do
        counts[value] = (counts[value] or 0) + 1
    end
    for _, value in ipairs(right) do
        counts[value] = (counts[value] or 0) - 1
    end
    for _, count in pairs(counts) do
        if count ~= 0 then
            return false
        end
    end
    return true
end

local function selected_base_bonus_ids()
    local values = {}
    for slot = 1, 5 do
        local selected = state["desired_base_reinforcement_" .. tostring(slot)] or 1
        table.insert(values, base_reinforcement_selector_ids[selected])
    end
    return values
end

local function format_base_reinforcements(packed)
    packed = tonumber(packed)
    if packed == nil then
        return "unknown"
    end
    local names = {}
    for _ = 1, 5 do
        local id = packed % 1000
        table.insert(names, base_reinforcement_id_names[id] or ("Bonus " .. tostring(id)))
        packed = math.floor(packed / 1000)
    end
    return table.concat(names, " | ")
end

local function base_pool_summary(pool)
    local values = {}
    for _, entry in ipairs(pool or {}) do
        local name = base_reinforcement_id_names[entry.bonus_id]
            or ("Bonus " .. tostring(entry.bonus_id))
        table.insert(values, name .. " (max " .. tostring(entry.max_count) .. ")")
    end
    return table.concat(values, ", ")
end

local function unavailable_base_target_reason(pool, target)
    local available = {}
    local requested = {}
    for _, entry in ipairs(pool or {}) do
        available[entry.bonus_id] = entry.max_count
    end
    for _, bonus_id in ipairs(target or {}) do
        requested[bonus_id] = (requested[bonus_id] or 0) + 1
    end
    local problems = {}
    for bonus_id, count in pairs(requested) do
        local maximum = available[bonus_id] or 0
        if maximum == 0 then
            table.insert(problems, (base_reinforcement_id_names[bonus_id]
                or tostring(bonus_id)) .. " is unavailable")
        elseif count > maximum then
            table.insert(problems, (base_reinforcement_id_names[bonus_id]
                or tostring(bonus_id)) .. " is limited to " .. tostring(maximum))
        end
    end
    if #problems == 0 then
        return nil
    end
    table.sort(problems)
    return table.concat(problems, "; ")
end

local function refresh_base_forge_route()
    local target = selected_base_bonus_ids()
    local key = table.concat({
        tostring(state.rng_base_seed), tostring(state.artian_create_weapon_type),
        tostring(state.artian_create_rarity), tostring(state.artian_create_count_after),
        tostring(state.base_reinforcement_pool_detail),
        table.concat(target, ","),
    }, "|")
    if key == state.base_forge_route_cache_key then
        return
    end
    state.base_forge_route_cache_key = key
    state.base_forge_route_distance = nil
    state.base_forge_route_value = nil
    state.base_forge_route_unavailable = nil
    if state.rng_base_seed == nil or state.artian_create_weapon_type == nil
        or state.artian_create_rarity == nil or state.artian_create_count_after == nil then
        return
    end

    local seed = u32(
        state.rng_base_seed + state.artian_create_weapon_type * 1000
        + state.artian_create_rarity
    ) ~ 0x00ac9365
    local x, y, z, w = initialize_rng(seed)
    for _ = 1, state.artian_create_count_after * 10 do
        x, y, z, w = rng_step(x, y, z, w)
    end
    local pool = state.base_reinforcement_pool
        or default_base_reinforcement_pool()
    state.base_forge_route_unavailable = unavailable_base_target_reason(pool, target)
    if state.base_forge_route_unavailable ~= nil then
        return
    end
    for offset = 0, 4999 do
        local packed, bonuses
        x, y, z, w, packed, bonuses =
            draw_base_reinforcement(x, y, z, w, pool)
        if same_multiset(bonuses, target) then
            state.base_forge_route_distance = offset + 1
            state.base_forge_route_value = packed
            return
        end
        for _ = 1, 5 do
            x, y, z, w = rng_step(x, y, z, w)
        end
    end
end

local function format_gogma_reinforcements(packed)
    local names = {}
    for _, id in ipairs(unpack_gogma_bonus_ids(packed)) do
        table.insert(names, gogma_bonus_names_by_id[id] or ("Bonus " .. tostring(id + 1)))
    end
    return table.concat(names, " | ")
end

local function copy_rng(rng)
    return { x = rng.x, y = rng.y, z = rng.z, w = rng.w }
end

local function find_mixed_gogma_route(target)
    if state.gogma_current_value == nil or state.gogma_next_counter == nil
        or state.rng_base_seed == nil or state.rng_weapon_type == nil
        or state.rng_attribute_force == nil then
        return nil, nil
    end
    local capture = {
        base_seed = state.rng_base_seed,
        weapon_type = state.rng_weapon_type,
        attribute_force = state.rng_attribute_force,
        gogma_counter = state.gogma_next_counter,
        counter_gate = state.rng_counter_gate,
    }
    local rng = initialize_gogma_rng(capture)
    if rng == nil then
        return nil, nil
    end
    local states = {
        { packed = state.gogma_current_value, last_reset = nil },
    }
    for distance = 1, 5000 do
        local next_states = {}
        local seen = {}

        -- Reset ignores the previous reinforcement value, so every state has
        -- the same Reset successor at a given stream counter.
        local reset_result, reset_ids = simulate_gogma_roll(
            copy_rng(rng), state.gogma_current_value, 0
        )
        if reset_result == nil then
            return nil, nil, nil
        end
        if same_multiset(reset_ids, target) then
            return distance, reset_result, distance
        end
        seen[gogma_family_layout(reset_result)] = true
        table.insert(next_states, { packed = reset_result, last_reset = distance })

        for _, route_state in ipairs(states) do
            local keep_result, keep_ids = simulate_gogma_roll(
                copy_rng(rng), route_state.packed, 1
            )
            if keep_result ~= nil then
                if same_multiset(keep_ids, target) then
                    return distance, keep_result, route_state.last_reset
                end
                local layout = gogma_family_layout(keep_result)
                if not seen[layout] then
                    seen[layout] = true
                    table.insert(next_states, {
                        packed = keep_result,
                        last_reset = route_state.last_reset,
                    })
                end
            end
        end
        states = next_states
        -- Consecutive amendment counters start ten xorshift steps apart.
        for _ = 1, 10 do
            rng.x, rng.y, rng.z, rng.w = rng_step(rng.x, rng.y, rng.z, rng.w)
        end
    end
    return nil, nil, nil
end

local function refresh_gogma_route()
    local target = selected_gogma_bonus_ids()
    local key = table.concat({
        tostring(state.rng_base_seed), tostring(state.rng_weapon_type),
        tostring(state.rng_attribute_force), tostring(state.rng_counter_gate),
        tostring(state.gogma_next_counter), tostring(state.gogma_current_value),
        table.concat(target, ","),
    }, "|")
    if key == state.gogma_route_cache_key then
        return
    end
    state.gogma_route_cache_key = key
    state.gogma_route_distance = nil
    state.gogma_route_mode = nil
    state.gogma_route_reset_count = nil
    state.gogma_route_keep_count = nil
    state.gogma_route_value = nil
    local distance, value, last_reset = find_mixed_gogma_route(target)
    if distance ~= nil then
        state.gogma_route_distance = distance
        state.gogma_route_value = value
        state.gogma_route_reset_count = last_reset or 0
        state.gogma_route_keep_count = last_reset ~= nil
            and distance - last_reset or distance
        if state.gogma_route_reset_count == 0 then
            state.gogma_route_mode = 1
        elseif state.gogma_route_keep_count == 0 then
            state.gogma_route_mode = 0
        else
            state.gogma_route_mode = 2
        end
    end
end

local function install_weapon_type_hook()
    local key = "weapon_type"
    if installed_hooks[key] then
        return
    end
    local type_def = sdk.find_type_definition("app.WeaponDef")
    local method = type_def:get_method(
        "getTYPEFromFixed(app.WeaponDef.TYPE_Fixed,app.WeaponDef.TYPE)"
    ) or type_def:get_method("getTYPEFromFixed")
    sdk.hook(method, function(args)
        if current_skill_capture ~= nil then
            current_weapon_type_out = args[3]
        end
    end, function(retval)
        if current_skill_capture ~= nil and current_weapon_type_out ~= nil then
            local ok, value = pcall(function()
                return sdk.to_valuetype(current_weapon_type_out, "System.UInt64"):read_dword(0)
            end)
            if ok then
                current_skill_capture.weapon_type = value & UINT32_MASK
            end
        end
        current_weapon_type_out = nil
        return retval
    end)
    installed_hooks[key] = true
end

local function install_base_bonus_hook()
    local key = "base_bonus"
    if installed_hooks[key] then
        return
    end
    local type_def = sdk.find_type_definition("app.ArtianUtil")
    local method = type_def:get_method("getBaseBonusByCreateingInt(app.savedata.cEquipWork)")
        or type_def:get_method("getBaseBonusByCreateingInt")
    base_bonus_method = method
    sdk.hook(method, function()
    end, function(retval)
        if current_skill_capture ~= nil then
            current_skill_capture.base_bonus = tonumber(sdk.to_int64(retval) & UINT32_MASK)
        end
        return retval
    end)
    installed_hooks[key] = true
end

local function install_attribute_hook()
    local key = "attribute"
    if installed_hooks[key] then
        return
    end
    local type_def = sdk.find_type_definition("app.WeaponUtil")
    local method = type_def:get_method("getAttributeForce(app.savedata.cEquipWork)")
        or type_def:get_method("getAttributeForce")
    attribute_force_method = method
    sdk.hook(method, function()
    end, function(retval)
        if current_skill_capture ~= nil then
            current_skill_capture.attribute_force = tonumber(sdk.to_int64(retval) & UINT32_MASK)
        end
        return retval
    end)
    installed_hooks[key] = true
end

local function install_skill_hook()
    local key = "skill_roll"
    if installed_hooks[key] then
        return
    end
    local type_def = sdk.find_type_definition("app.Em0078_ArtianUtil")
    lottery_method = type_def:get_method("lotterySkill(app.savedata.cEquipWork)")
        or type_def:get_method("lotterySkill")
    local get_skill_type = type_def:get_method("getArtianSkillType(app.savedata.cEquipWork)")
        or type_def:get_method("getArtianSkillType")
    artian_skill_type_method = get_skill_type
    sdk.hook(lottery_method, function(args)
        if not state.enabled then
            return
        end
        current_skill_equip_work = args[2]
        local ok, rng = pcall(read_skill_rng_state)
        current_skill_capture = ok and rng or {}
    end, function(retval)
        if state.enabled and current_skill_equip_work ~= nil and current_skill_capture ~= nil then
            local ok, err = pcall(function()
                local equip_work = sdk.to_managed_object(current_skill_equip_work)
                state.last_artian_skill_type = table_skill_type_from_runtime(
                    get_skill_type:call(nil, equip_work)
                )
                state.rng_base_seed = current_skill_capture.base_seed
                state.rng_base_seed_raw = current_skill_capture.base_seed_raw
                state.rng_counter_gate = current_skill_capture.counter_gate
                state.rng_counter = current_skill_capture.counter
                state.rng_base_bonus = current_skill_capture.base_bonus
                state.rng_attribute_force = current_skill_capture.attribute_force
                state.rng_weapon_type = current_skill_capture.weapon_type
                state.skill_route_cache_key = nil
                refresh_skill_route()
                state.skill_prediction_valid = state.predicted_skill_type
                    == state.last_artian_skill_type
            end)
            if not ok then
                state.last_error = "Skill prediction failed: " .. tostring(err)
            end
        end
        current_skill_equip_work = nil
        current_skill_capture = nil
        return retval
    end)
    installed_hooks[key] = true
end

local function install_skill_type_hook()
    local key = "skill_type"
    if installed_hooks[key] then
        return
    end
    local type_def = sdk.find_type_definition("app.Em0078_ArtianUtil")
    local method = type_def:get_method("getArtianSkillType(app.savedata.cEquipWork)")
        or type_def:get_method("getArtianSkillType")
    sdk.hook(method, function()
        -- This getter is also used while other Artian menus close. Only the
        -- lotterySkill call owns permission to update the captured skill route.
        resolving_skill_type = state.enabled and current_skill_equip_work ~= nil
    end, function(retval)
        if resolving_skill_type then
            local value = tonumber(sdk.to_int64(retval) & UINT32_MASK)
            state.last_artian_skill_type = table_skill_type_from_runtime(value)
        end
        resolving_skill_type = false
        return retval
    end)
    installed_hooks[key] = true
end

local function find_equip_work_argument(args)
    for index = 2, 5 do
        local ok, object, value = pcall(function()
            local candidate = sdk.to_managed_object(args[index])
            return candidate, tonumber(candidate:get_field("BonusByGrinding"))
        end)
        if ok and object ~= nil and value ~= nil then
            return object, index, value
        end
    end
    return nil, nil, nil
end

local function install_gogma_reinforcement_probe()
    local type_def = sdk.find_type_definition("app.Em0078_ArtianUtil")
    local method = type_def:get_method("lotteryCreateBonus(app.savedata.cEquipWork)")
        or type_def:get_method("lotteryCreateBonus")
    if method == nil then
        debug_state.gogma_error = "lotteryCreateBonus method not found"
        return
    end
    sdk.hook(method, function(args)
        debug_state.gogma_roll_calls = debug_state.gogma_roll_calls + 1
        debug_state.gogma_after = nil
        debug_state.gogma_error = nil
        debug_state.gogma_mode = tonumber(sdk.to_int64(args[4]) & 0xff)
        debug_state.gogma_weapon_data = sdk.to_managed_object(args[2])
        local equip_work, index, before = find_equip_work_argument(args)
        debug_state.gogma_equip_work = equip_work
        debug_state.gogma_arg_index = index
        debug_state.gogma_before = before
        debug_state.gogma_creating = equip_work ~= nil
            and tonumber(equip_work:get_field("BonusByCreating")) or nil
        debug_state.target_bonus_calls = {}
        local ok, rng = pcall(read_skill_rng_state)
        debug_state.gogma_rng = ok and rng or {}
        debug_state.gogma_prediction = {
            rng = nil,
            ids = {},
            packed = 0,
        }
        debug_state.gogma_prediction_valid = nil
        current_skill_capture = debug_state.gogma_rng
        if equip_work ~= nil and base_bonus_method ~= nil then
            local bonus_ok, bonus = pcall(function()
                return tonumber(base_bonus_method:call(nil, equip_work))
            end)
            if bonus_ok then
                debug_state.gogma_rng.base_bonus = bonus
            end
        end
    end, function(retval)
        local ok, err = pcall(function()
            if debug_state.gogma_equip_work ~= nil then
                debug_state.gogma_after = tonumber(
                    debug_state.gogma_equip_work:get_field("BonusByGrinding")
                )
                local prediction = debug_state.gogma_prediction
                if prediction ~= nil and #prediction.ids == 5 then
                    debug_state.gogma_prediction_valid =
                        prediction.packed == debug_state.gogma_after
                end
                if debug_state.gogma_rng ~= nil then
                    state.rng_base_seed = debug_state.gogma_rng.base_seed
                    state.rng_counter_gate = debug_state.gogma_rng.counter_gate
                    state.rng_weapon_type = debug_state.gogma_rng.weapon_type
                    state.rng_attribute_force = debug_state.gogma_rng.attribute_force
                    state.gogma_next_counter =
                        (debug_state.gogma_rng.gogma_counter or 0) + 1
                    state.gogma_current_value = debug_state.gogma_after
                    state.gogma_route_cache_key = nil
                end
            end
        end)
        if not ok then
            debug_state.gogma_error = tostring(err)
        end
        table.insert(debug_state.gogma_samples, 1, {
            before = debug_state.gogma_before,
            after = debug_state.gogma_after,
            seed = debug_state.gogma_rng and debug_state.gogma_rng.base_seed or nil,
            counter = debug_state.gogma_rng and debug_state.gogma_rng.counter or nil,
            gogma_counter = debug_state.gogma_rng
                and debug_state.gogma_rng.gogma_counter or nil,
            predicted = debug_state.gogma_prediction
                and debug_state.gogma_prediction.packed or nil,
            valid = debug_state.gogma_prediction_valid,
            target_calls = #debug_state.target_bonus_calls,
            mode = debug_state.gogma_mode,
        })
        if #debug_state.gogma_samples > 20 then
            table.remove(debug_state.gogma_samples)
        end
        debug_state.gogma_equip_work = nil
        current_skill_capture = nil
        return retval
    end)
end

local function install_target_bonus_probe()
    local type_def = sdk.find_type_definition("app.Em0078_ArtianUtil")
    local method = type_def:get_method("getTargetBonusId")
    if method == nil then
        return
    end
    sdk.hook(method, function(args)
        if debug_state.gogma_equip_work == nil then
            return
        end
        local record = {
            return_buffer = sdk.to_int64(args[2]),
            current_id = tonumber(sdk.to_int64(args[3]) & UINT32_MASK),
            pool = {},
            pool_entries = {},
        }
        debug_state.pending_target_bonus = record
        table.insert(debug_state.target_bonus_calls, record)
    end, function(retval)
        local record = debug_state.pending_target_bonus
        if record ~= nil then
            local ok, err = pcall(function()
                record.return_value = sdk.to_int64(retval)
                record.words = {
                    read_qword(record.return_value),
                    read_qword(record.return_value + 8),
                    read_qword(record.return_value + 16),
                }
                record.total = read_dword(record.return_value + 8)
                local list_address = read_qword(record.return_value)
                local list = sdk.to_managed_object(list_address)
                local count = tonumber(list:call("get_Count")) or 0
                for index = 0, count - 1 do
                    local item = list:call("get_Item", index)
                    local bonus_id = tonumber(item:get_field("BonusId"))
                    local probability = tonumber(item:get_field("Probability"))
                    table.insert(record.pool_entries, {
                        bonus_id = bonus_id,
                        probability = probability,
                    })
                    table.insert(record.pool,
                        tostring(bonus_id) .. ":" .. tostring(probability))
                end
                local prediction = debug_state.gogma_prediction
                if prediction ~= nil then
                    if prediction.rng == nil then
                        prediction.rng = initialize_gogma_rng(debug_state.gogma_rng)
                    end
                    record.predicted_id, record.roll, record.predicted_total =
                        select_weighted_gogma_bonus(prediction.rng, record.pool_entries)
                    if record.predicted_id ~= nil then
                        table.insert(prediction.ids, record.predicted_id)
                        local slot = #prediction.ids - 1
                        prediction.packed = prediction.packed
                            + (record.predicted_id + 1) * (1000 ^ slot)
                    end
                end
            end)
            if not ok then
                record.error = tostring(err)
            end
        end
        debug_state.pending_target_bonus = nil
        return retval
    end)
end

local function install_create_count_hooks()
    local type_def = sdk.find_type_definition("app.savedata.cEquipParam")
    local get_method = type_def:get_method(
        "getArtianCreateCount(app.WeaponDef.TYPE,app.ItemDef.RARE)"
    ) or type_def:get_method("getArtianCreateCount")
    local add_method = type_def:get_method(
        "addArtianCreateCount(app.WeaponDef.TYPE,app.ItemDef.RARE)"
    ) or type_def:get_method("addArtianCreateCount")

    sdk.hook(get_method, function(args)
        local storage = thread.get_hook_storage()
        storage["create_type"] = tonumber(sdk.to_int64(args[3]))
        storage["create_rarity"] = tonumber(sdk.to_int64(args[4]))
    end, function(retval)
        local storage = thread.get_hook_storage()
        local weapon_type = storage["create_type"]
        local rarity = storage["create_rarity"]
        if state.enabled and weapon_type ~= nil and rarity ~= nil then
            local count = tonumber(sdk.to_int64(retval) & UINT32_MASK)
            latest_create_counter = {
                weapon_type = weapon_type,
                rarity = rarity,
                before = count,
                after = count,
            }
            state.artian_create_weapon_type = weapon_type
            state.artian_create_rarity = rarity
            state.artian_create_count_before = count
            state.artian_create_count_after = count
            local ok, rng = pcall(read_skill_rng_state)
            if ok and rng ~= nil then
                state.rng_base_seed = rng.base_seed
                state.rng_base_seed_raw = rng.base_seed_raw
            end
            state.base_reinforcement_predicted = predict_base_reinforcement(
                state.rng_base_seed, weapon_type, rarity, count,
                state.base_reinforcement_pool
            )
            state.base_reinforcement_prediction_valid = nil
            state.base_forge_route_cache_key = nil
        end
        storage["create_type"] = nil
        storage["create_rarity"] = nil
        return retval
    end)

    sdk.hook(add_method, function(args)
        if not state.enabled then
            return
        end
        local weapon_type = tonumber(sdk.to_int64(args[3]))
        local rarity = tonumber(sdk.to_int64(args[4]))
        if latest_create_counter ~= nil
            and latest_create_counter.weapon_type == weapon_type
            and latest_create_counter.rarity == rarity then
            pending_base_prediction = predict_base_reinforcement(
                state.rng_base_seed,
                weapon_type,
                rarity,
                latest_create_counter.before,
                active_base_pool_capture ~= nil
                    and active_base_pool_capture.entries
                    or state.base_reinforcement_pool
            )
            latest_create_counter.after = latest_create_counter.before + 1
            state.artian_create_count_after = latest_create_counter.after
            state.base_forge_route_cache_key = nil
        end
    end, function(retval)
        return retval
    end)
end

local function install_base_pool_reader()
    local artian_type = sdk.find_type_definition("app.ArtianUtil")
    local create_method = artian_type:get_method(
        "createArtianWeapon(app.user_data.WeaponData.cData,app.ArtianUtil.cPartsData[])"
    ) or artian_type:get_method("createArtianWeapon")
    if create_method == nil then
        error("createArtianWeapon method not found")
    end

    sdk.hook(create_method, function()
        if state.enabled then
            local pool = default_base_reinforcement_pool()
            set_base_reinforcement_pool(pool, "native base pool")
            active_base_pool_capture = { entries = pool }
        end
    end, function(retval)
        active_base_pool_capture = nil
        return retval
    end)
end

local function install_box_insert_hook()
    local type_def = sdk.find_type_definition("app.savedata.cEquipParam")
    local method = type_def:get_method(
        "addEquipBoxArtianWeapon(app.savedata.cEquipWork,app.user_data.WeaponData.cData)"
    ) or type_def:get_method("addEquipBoxArtianWeapon")
    sdk.hook(method, function(args)
        if not state.enabled then
            return
        end
        local ok, err = pcall(function()
            local equip_work = sdk.to_managed_object(args[3])
            local actual = tonumber(equip_work:get_field("BonusByGrinding"))
            local pool = active_base_pool_capture ~= nil
                and active_base_pool_capture.entries or nil
            if pool ~= nil and #pool > 0 then
                set_base_reinforcement_pool(pool,
                    state.base_reinforcement_pool_source or "forge")
            end
            local predicted = nil
            local expected_count = latest_create_counter ~= nil
                and latest_create_counter.before
                or state.artian_create_count_before
            if expected_count ~= nil then
                predicted = predict_base_reinforcement(
                    state.rng_base_seed,
                    state.artian_create_weapon_type,
                    state.artian_create_rarity,
                    expected_count,
                    state.base_reinforcement_pool
                )
            end
            state.base_reinforcement_actual = actual

            if predicted ~= actual and expected_count ~= nil then
                local fitted_pool = fit_base_reinforcement_pool(
                    state.rng_base_seed,
                    state.artian_create_weapon_type,
                    state.artian_create_rarity,
                    expected_count,
                    actual
                )
                if fitted_pool ~= nil then
                    set_base_reinforcement_pool(fitted_pool, "fitted native recipe pool")
                    predicted = predict_base_reinforcement(
                        state.rng_base_seed,
                        state.artian_create_weapon_type,
                        state.artian_create_rarity,
                        expected_count,
                        fitted_pool
                    )
                end
            end

            -- Menu code may call getArtianCreateCount again between generation
            -- and box insertion. Reconcile that displaced getter snapshot with
            -- the sequence actually stored on the newly forged weapon.
            if predicted ~= actual and expected_count ~= nil
                and state.rng_base_seed ~= nil
                and state.artian_create_weapon_type ~= nil
                and state.artian_create_rarity ~= nil then
                local first_count = math.max(0, expected_count - 3)
                for count = first_count, expected_count + 3 do
                    local candidate = predict_base_reinforcement(
                        state.rng_base_seed,
                        state.artian_create_weapon_type,
                        state.artian_create_rarity,
                        count,
                        state.base_reinforcement_pool
                    )
                    if candidate == actual then
                        predicted = candidate
                        state.artian_create_count_before = count
                        state.artian_create_count_after = count + 1
                        if latest_create_counter ~= nil then
                            latest_create_counter.before = count
                            latest_create_counter.after = count + 1
                        end
                        state.base_forge_route_cache_key = nil
                        break
                    end
                end
            end
            state.base_reinforcement_predicted = predicted
            state.base_reinforcement_prediction_valid =
                predicted ~= nil and predicted == actual
            state.base_reinforcement_validation_detail = table.concat({
                "seed " .. tostring(state.rng_base_seed),
                "type " .. tostring(state.artian_create_weapon_type),
                "rarity " .. tostring(state.artian_create_rarity),
                "expected count " .. tostring(expected_count),
                "predicted " .. tostring(predicted),
                "actual " .. tostring(actual),
                "pool " .. tostring(state.base_reinforcement_pool_detail),
                "pool source " .. tostring(state.base_reinforcement_pool_source),
            }, " | ")
            pending_base_prediction = nil
        end)
        if not ok then
            state.last_error = "Forge validation failed: " .. tostring(err)
        end
    end, function(retval)
        return retval
    end)
end

local function identify_selected_weapon(equip_work)
    local rng = read_skill_rng_state()
    current_skill_capture = rng
    local capture_ok, capture_err = pcall(function()
        if base_bonus_method ~= nil then
            base_bonus_method:call(nil, equip_work)
        end
        if attribute_force_method ~= nil then
            attribute_force_method:call(nil, equip_work)
        end
    end)
    current_skill_capture = nil
    if not capture_ok then
        error(capture_err)
    end

    if artian_skill_type_method ~= nil then
        state.last_artian_skill_type = table_skill_type_from_runtime(
            artian_skill_type_method:call(nil, equip_work)
        )
    end
    state.rng_base_seed = rng.base_seed
    state.rng_base_seed_raw = rng.base_seed_raw
    state.rng_counter_gate = rng.counter_gate
    state.rng_counter = rng.counter
    state.rng_base_bonus = rng.base_bonus
    state.rng_attribute_force = rng.attribute_force
    state.rng_weapon_type = rng.weapon_type
    state.skill_counter_is_next = true
    state.gogma_next_counter = rng.gogma_counter
    state.gogma_current_value = tonumber(equip_work:get_field("BonusByGrinding"))
    state.skill_route_cache_key = nil
    state.gogma_route_cache_key = nil
    refresh_skill_route()
    refresh_gogma_route()
end

local function work_from_container(container)
    if container == nil then
        return nil
    end
    local info_ok, work_info = pcall(function()
        return container:get_field("<WorkInfo>k__BackingField")
    end)
    if not info_ok or work_info == nil then
        return nil
    end
    local work_ok, work = pcall(function()
        return work_info:get_field("<Work>k__BackingField")
    end)
    return work_ok and work or nil
end

local function selected_equip_work(owner, info)
    local equip_work = work_from_container(info)
    if equip_work ~= nil then
        return equip_work
    end
    local parts_ok, parts_list = pcall(function()
        return owner:get_field("_PartsArtianList")
    end)
    if not parts_ok then
        parts_list = nil
    end
    equip_work = work_from_container(parts_list)
    if equip_work ~= nil then
        return equip_work
    end

    local function find_work(object, depth, visited)
        if object == nil or depth > 3 then
            return nil
        end
        local address = tostring(object)
        if visited[address] then
            return nil
        end
        visited[address] = true
        local type_def = object:get_type_definition()
        if type_def:get_full_name() == "app.savedata.cEquipWork" then
            return object
        end
        for _, field in ipairs(type_def:get_fields()) do
            local field_type = field:get_type():get_full_name()
            if field_type:find("WeaponInfo", 1, true)
                or field_type:find("EquipSet", 1, true)
                or field_type:find("PartsArtianList", 1, true)
                or field_type:find("EquipWork", 1, true) then
                local value_ok, value = pcall(function()
                    return object:get_field(field:get_name())
                end)
                if value_ok and value ~= nil then
                    local found = find_work(value, depth + 1, visited)
                    if found ~= nil then
                        return found
                    end
                end
            end
        end
        return nil
    end

    equip_work = find_work(parts_list, 0, {})
    if equip_work ~= nil then
        return equip_work
    end
    return find_work(owner, 0, {})
end

local function install_selected_weapon_probe()
    local type_def = sdk.find_type_definition("app.GUI080301")
    local method = type_def:get_method(
        "setCurrentWeapon(app.EquipBoxInfo.WeaponInfo)"
    ) or type_def:get_method("setCurrentWeapon")
    if method == nil then
        return
    end
    sdk.hook(method, function(args)
        if not state.enabled then
            return
        end
        local storage = thread.get_hook_storage()
        storage["selected_weapon_owner"] = args[2]
    end, function(retval)
        local storage = thread.get_hook_storage()
        local owner_address = storage["selected_weapon_owner"]
        storage["selected_weapon_owner"] = nil
        if owner_address == nil then
            return retval
        end
        debug_state.selected_weapon_calls = debug_state.selected_weapon_calls + 1
        debug_state.selected_weapon_fields = {}
        debug_state.selected_context_fields = {}
        debug_state.selected_context_details = {}
        debug_state.selected_weapon_equip_work = nil
        debug_state.selected_weapon_error = nil
        local ok, err = pcall(function()
            local owner = sdk.to_managed_object(owner_address)
            local info = owner:get_field("_CurrentWeaponInfo")
            debug_state.selected_weapon_type = type_name_of(info) or tostring(info)
            local equip_work = selected_equip_work(owner, info)
            if state.debug then
                local inspected = inspect_selected_weapon_object(
                    info, 0, debug_state.selected_weapon_fields, {}
                )
                if equip_work == nil then
                    equip_work = inspected
                end
                for _, field in ipairs(owner:get_type_definition():get_fields()) do
                    local name = field:get_name()
                    local field_type = field:get_type():get_full_name()
                    if name:find("Current", 1, true) or name:find("Equip", 1, true)
                        or name:find("Weapon", 1, true)
                        or name:find("Artian", 1, true) then
                        table.insert(debug_state.selected_context_fields,
                            name .. ": " .. field_type)
                    end
                    if field_type:find("EquipSet", 1, true)
                        or field_type:find("PartsArtianList", 1, true) then
                        local value_ok, value = pcall(function()
                            return owner:get_field(name)
                        end)
                        if value_ok and value ~= nil then
                            local context_equip_work = inspect_selected_weapon_object(
                                value, 0, debug_state.selected_context_details, {}
                            )
                            if equip_work == nil and context_equip_work ~= nil then
                                equip_work = context_equip_work
                            end
                        end
                    end
                end
            end
            if equip_work ~= nil then
                debug_state.selected_weapon_equip_work = tostring(equip_work)
                identify_selected_weapon(equip_work)
            end
        end)
        if not ok then
            debug_state.selected_weapon_error = tostring(err)
        end
        if state.debug then
            local write_ok, write_err = pcall(write_selected_weapon_probe)
            if not write_ok then
                debug_state.selected_weapon_file_status =
                    "Probe write failed: " .. tostring(write_err)
            end
        end
        return retval
    end)
end

local function install_hooks()
    local ok, err = pcall(function()
        install_weapon_type_hook()
        install_base_bonus_hook()
        install_attribute_hook()
        install_skill_hook()
        install_skill_type_hook()
        install_create_count_hooks()
        install_box_insert_hook()
    end)
    if not ok then
        state.last_error = "Hook setup failed: " .. tostring(err)
    end
    local pool_ok, pool_err = pcall(install_base_pool_reader)
    if not pool_ok then
        state.last_error = "Base pool reader setup failed: " .. tostring(pool_err)
    end
    local probe_ok, probe_err = pcall(install_gogma_reinforcement_probe)
    if not probe_ok then
        debug_state.gogma_error = tostring(probe_err)
    end
    pcall(install_target_bonus_probe)
    local selection_ok, selection_err = pcall(install_selected_weapon_probe)
    if not selection_ok then
        debug_state.selected_weapon_error = tostring(selection_err)
    end
end

local function draw_checkbox(label, key)
    local first, second = imgui.checkbox(label, state[key])
    if second ~= nil then
        state[key] = second
    else
        state[key] = first
    end
end

local function draw_colored_text(text, color)
    local ok = pcall(imgui.text_colored, text, color)
    if not ok then
        imgui.text(text)
    end
end

local function draw_quick_start()
    draw_colored_text("Quick start", 0xff73d7ff)
    imgui.text("1. Tick only the stages you want to plan.")
    imgui.text("2. Base Artian: forge once with the parts you intend to use.")
    imgui.text("3. Gogma: hover over the weapon in the smithy upgrade list.")
    imgui.text("4. Choose targets, recalculate, then follow the displayed route.")
end

local function draw_skill_route()
    draw_checkbox("Include in plan##gogma_skills", "include_skill_predictions")
    imgui.text("Gogma set and group skills")
    local changed
    changed, state.desired_set_skill = imgui.combo(
        "Set skill", state.desired_set_skill, set_skill_names
    )
    changed, state.desired_group_skill = imgui.combo(
        "Group skill", state.desired_group_skill, group_skill_names
    )
    if imgui.button("Recalculate##skills") then
        state.skill_route_cache_key = nil
    end
    refresh_skill_route()

    local current_set, current_group = names_for_artian_skill_type(state.last_artian_skill_type)
    if current_set == nil then
        draw_colored_text("Hover over a Gogma Artian weapon to identify its skill stream.",
            0xff80c0ff)
        return
    end
    imgui.text("Current: " .. current_set .. " / " .. current_group)
    local desired_type = artian_skill_type_for_names(
        set_skill_names[state.desired_set_skill], group_skill_names[state.desired_group_skill]
    )
    if state.last_artian_skill_type == desired_type then
        imgui.text("Route: already at target")
    elseif state.skill_prediction_valid == false then
        imgui.text("Route unavailable: prediction validation failed")
    elseif state.exact_reroll_distance ~= nil then
        imgui.text("Route: reset skills " .. tostring(state.exact_reroll_distance) .. " time(s)")
    else
        imgui.text("Route: target not found within 5000 resets")
    end
end

local function draw_base_route()
    draw_checkbox("Include in plan##base", "include_base_predictions")
    imgui.text("Base Artian reinforcements")
    local changed
    for slot = 1, 5 do
        local key = "desired_base_reinforcement_" .. tostring(slot)
        changed, state[key] = imgui.combo(
            "Bonus " .. tostring(slot), state[key], base_reinforcement_names
        )
    end
    if imgui.button("Recalculate##reinforcements") then
        state.base_forge_route_cache_key = nil
    end
    refresh_base_forge_route()

    if state.artian_create_weapon_type == nil then
        draw_colored_text("Forge one base Artian weapon with the intended parts first.",
            0xff80c0ff)
        return
    end
    imgui.text("Stream: weapon type " .. tostring(state.artian_create_weapon_type)
        .. ", rarity " .. tostring(state.artian_create_rarity + 1)
        .. ", next count " .. tostring(state.artian_create_count_after))
    draw_colored_text("Possible from this recipe: "
        .. base_pool_summary(state.base_reinforcement_pool), 0xff80ff80)
    if state.base_reinforcement_prediction_valid == false then
        imgui.text("Route unavailable: prediction validation failed")
        if state.base_reinforcement_validation_detail ~= nil then
            imgui.text(state.base_reinforcement_validation_detail)
        end
    elseif state.base_forge_route_unavailable ~= nil then
        draw_colored_text("Impossible for this recipe: "
            .. state.base_forge_route_unavailable, 0xff8080ff)
    elseif state.base_forge_route_distance == nil then
        imgui.text("Route: target not found within 5000 weapons")
    elseif state.base_forge_route_distance == 1 then
        imgui.text("Route: forge and keep the next weapon")
    else
        imgui.text("Route: forge " .. tostring(state.base_forge_route_distance)
            .. " weapons; keep weapon " .. tostring(state.base_forge_route_distance))
    end
    if state.base_forge_route_value ~= nil then
        imgui.text("Result: " .. format_base_reinforcements(state.base_forge_route_value))
    end
end

local function draw_gogma_route()
    draw_checkbox("Include in plan##gogma_reinforcements", "include_gogma_predictions")
    imgui.text("Gogma reinforcements")
    local changed
    for slot = 1, 5 do
        local key = "desired_gogma_reinforcement_" .. tostring(slot)
        changed, state[key] = imgui.combo(
            "Gogma bonus " .. tostring(slot), state[key], gogma_bonus_names
        )
    end
    if imgui.button("Recalculate##gogma_reinforcements") then
        state.gogma_route_cache_key = nil
    end
    refresh_gogma_route()

    if state.gogma_current_value == nil then
        draw_colored_text(
            "Hover over a Gogma Artian weapon to identify its reinforcement stream.",
            0xff80c0ff)
        return
    end
    imgui.text("Current: " .. format_gogma_reinforcements(state.gogma_current_value))
    if same_multiset(unpack_gogma_bonus_ids(state.gogma_current_value),
            selected_gogma_bonus_ids()) then
        imgui.text("Route: already at target")
    elseif state.gogma_route_distance == nil then
        imgui.text("Route: target not found within 5000 amendments")
    else
        if state.gogma_route_reset_count > 0 then
            imgui.text("1. Amend (Reset Bonuses) "
                .. tostring(state.gogma_route_reset_count) .. " time(s)")
        end
        if state.gogma_route_keep_count > 0 then
            local step = state.gogma_route_reset_count > 0 and "2. " or "1. "
            imgui.text(step .. "Amend (Keep Bonuses) "
                .. tostring(state.gogma_route_keep_count) .. " time(s)")
        end
        imgui.text("Total: " .. tostring(state.gogma_route_distance)
            .. " amendment(s)")
        imgui.text("Result: " .. format_gogma_reinforcements(state.gogma_route_value))
    end
end

local function draw_combined_plan()
    local selected = (state.include_base_predictions and 1 or 0)
        + (state.include_skill_predictions and 1 or 0)
        + (state.include_gogma_predictions and 1 or 0)
    if selected < 2 then
        return
    end

    imgui.separator()
    imgui.text("Optimal combined plan")
    local total = 0
    local available = true
    local step = 1

    if state.include_base_predictions then
        if state.base_forge_route_unavailable ~= nil then
            draw_colored_text(tostring(step) .. ". Base Artian target is impossible for this recipe: "
                .. state.base_forge_route_unavailable, 0xff8080ff)
            available = false
        elseif state.base_forge_route_distance == nil then
            imgui.text(tostring(step) .. ". Base Artian route not identified")
            available = false
        else
            imgui.text(tostring(step) .. ". Forge "
                .. tostring(state.base_forge_route_distance) .. " weapon(s); keep the last")
            total = total + state.base_forge_route_distance
        end
        step = step + 1
    end

    if state.include_skill_predictions then
        local desired_type = artian_skill_type_for_names(
            set_skill_names[state.desired_set_skill],
            group_skill_names[state.desired_group_skill]
        )
        if state.last_artian_skill_type == nil then
            imgui.text(tostring(step) .. ". Gogma skill route not identified")
            available = false
        else
            local count = state.last_artian_skill_type == desired_type
                and 0 or state.exact_reroll_distance
            if count == nil then
                imgui.text(tostring(step) .. ". Gogma skill target not reachable in search range")
                available = false
            else
                imgui.text(tostring(step) .. ". Reset skills " .. tostring(count) .. " time(s)")
                total = total + count
            end
        end
        step = step + 1
    end

    if state.include_gogma_predictions then
        local at_target = state.gogma_current_value ~= nil and same_multiset(
            unpack_gogma_bonus_ids(state.gogma_current_value),
            selected_gogma_bonus_ids()
        )
        if state.gogma_current_value == nil then
            imgui.text(tostring(step) .. ". Gogma reinforcement route not identified")
            available = false
        elseif at_target then
            imgui.text(tostring(step) .. ". Gogma reinforcements already at target")
        elseif state.gogma_route_distance == nil then
            imgui.text(tostring(step)
                .. ". Gogma reinforcement target not reachable in search range")
            available = false
        else
            if (state.gogma_route_reset_count or 0) > 0 then
                imgui.text(tostring(step) .. "a. Amend (Reset Bonuses) "
                    .. tostring(state.gogma_route_reset_count) .. " time(s)")
            end
            if (state.gogma_route_keep_count or 0) > 0 then
                imgui.text(tostring(step) .. "b. Amend (Keep Bonuses) "
                    .. tostring(state.gogma_route_keep_count) .. " time(s)")
            end
            total = total + state.gogma_route_distance
        end
    end

    if available then
        imgui.text("Minimum total actions: " .. tostring(total))
    end
    if state.include_base_predictions
        and (state.include_skill_predictions or state.include_gogma_predictions) then
        imgui.text("Gogma routes apply to the currently identified weapon stream")
    end
end

local function csv_cell(value)
    local text = tostring(value or "")
    return '"' .. text:gsub('"', '""') .. '"'
end

local function selected_base_target_text()
    local names = {}
    for slot = 1, 5 do
        local index = state["desired_base_reinforcement_" .. tostring(slot)] or 1
        table.insert(names, base_reinforcement_names[index])
    end
    return table.concat(names, " | ")
end

local function selected_gogma_target_text()
    local names = {}
    for slot = 1, 5 do
        local index = state["desired_gogma_reinforcement_" .. tostring(slot)] or 1
        table.insert(names, gogma_bonus_names[index])
    end
    return table.concat(names, " | ")
end

local function append_base_prediction_rows(rows, overall_step)
    local distance = state.base_forge_route_distance
    if distance == nil or state.rng_base_seed == nil
        or state.artian_create_weapon_type == nil or state.artian_create_rarity == nil
        or state.artian_create_count_after == nil then
        return overall_step
    end
    local seed = u32(state.rng_base_seed + state.artian_create_weapon_type * 1000
        + state.artian_create_rarity) ~ 0x00ac9365
    local x, y, z, w = initialize_rng(seed)
    for _ = 1, state.artian_create_count_after * 10 do
        x, y, z, w = rng_step(x, y, z, w)
    end
    for step = 1, distance do
        local packed
        x, y, z, w, packed = draw_base_reinforcement(
            x, y, z, w,
            state.base_reinforcement_pool or default_base_reinforcement_pool()
        )
        overall_step = overall_step + 1
        table.insert(rows, {
            overall_step, step, "Base Artian reinforcements",
            step == distance and "Forge and keep" or "Forge and discard",
            format_base_reinforcements(packed), selected_base_target_text(),
        })
        for _ = 1, 5 do
            x, y, z, w = rng_step(x, y, z, w)
        end
    end
    return overall_step
end

local function append_skill_prediction_rows(rows, overall_step)
    local distance = state.exact_reroll_distance
    if distance == nil or state.rng_weapon_type == nil
        or state.rng_attribute_force == nil or state.rng_base_seed == nil
        or state.rng_counter == nil then
        return overall_step
    end
    local seed = u32(state.rng_weapon_type * 1000 + state.rng_attribute_force
        + state.rng_base_seed) ~ 0x00ac9365
    local x, y, z, w = initialize_rng(seed)
    local counter_steps = state.rng_counter_gate ~= nil and state.rng_counter_gate < 0x36
        and 0 or state.rng_counter * 10
    for _ = 1, counter_steps do
        x, y, z, w = rng_step(x, y, z, w)
    end
    x, y, z, w = rng_step(x, y, z, w)
    local target = set_skill_names[state.desired_set_skill] .. " / "
        .. group_skill_names[state.desired_group_skill]
    for step = 1, distance do
        if not (state.skill_counter_is_next and step == 1) then
            for _ = 1, 10 do
                x, y, z, w = rng_step(x, y, z, w)
            end
        end
        local set_name, group_name = names_for_artian_skill_type(
            skill_type_from_table_index(w % 294)
        )
        overall_step = overall_step + 1
        table.insert(rows, {
            overall_step, step, "Gogma set and group skills", "Reset skills",
            set_name ~= nil and (set_name .. " / " .. group_name) or "unknown", target,
        })
    end
    return overall_step
end

local function append_gogma_prediction_rows(rows, overall_step)
    if state.gogma_route_distance == nil or state.gogma_current_value == nil then
        return overall_step
    end
    local rng = initialize_gogma_rng({
        base_seed = state.rng_base_seed,
        weapon_type = state.rng_weapon_type,
        attribute_force = state.rng_attribute_force,
        gogma_counter = state.gogma_next_counter,
        counter_gate = state.rng_counter_gate,
    })
    if rng == nil then
        return overall_step
    end
    local packed = state.gogma_current_value
    local target = selected_gogma_target_text()
    for step = 1, state.gogma_route_distance do
        local mode = step <= (state.gogma_route_reset_count or 0) and 0 or 1
        local result = simulate_gogma_roll(copy_rng(rng), packed, mode)
        if result == nil then
            return overall_step
        end
        packed = result
        overall_step = overall_step + 1
        table.insert(rows, {
            overall_step, step, "Gogma reinforcements",
            mode == 0 and "Amend (Reset Bonuses)" or "Amend (Keep Bonuses)",
            format_gogma_reinforcements(packed), target,
        })
        for _ = 1, 10 do
            rng.x, rng.y, rng.z, rng.w = rng_step(rng.x, rng.y, rng.z, rng.w)
        end
    end
    return overall_step
end

local function export_prediction_rows()
    refresh_base_forge_route()
    refresh_skill_route()
    refresh_gogma_route()

    local rows = {
        { "Row", "Stage step", "Stage", "Action", "Predicted result", "Target" },
    }
    local overall_step = 0
    if state.include_base_predictions then
        overall_step = append_base_prediction_rows(rows, overall_step)
    end
    if state.include_skill_predictions then
        overall_step = append_skill_prediction_rows(rows, overall_step)
    end
    if state.include_gogma_predictions then
        append_gogma_prediction_rows(rows, overall_step)
    end

    local path = resolve_data_path(EXPORT_PATH)
    local file, err = io.open(path, "w")
    if file == nil then
        state.export_status = "Export failed: " .. tostring(err)
        return
    end
    for _, row in ipairs(rows) do
        local cells = {}
        for column = 1, 6 do
            table.insert(cells, csv_cell(row[column]))
        end
        file:write(table.concat(cells, ","), "\n")
    end
    file:close()
    state.export_status = "Exported " .. tostring(#rows - 1)
        .. " steps: GogRollPlannerPredictions.csv"
end

local function draw_export()
    imgui.separator()
    imgui.text("Export")
    if imgui.button("Export predictions to CSV") then
        local ok, err = pcall(export_prediction_rows)
        if not ok then
            state.export_status = "Export failed: " .. tostring(err)
        end
    end
    if state.export_status ~= nil then
        imgui.text(state.export_status)
    end
end

local function draw_debug_research()
    if not state.debug then
        return
    end
    imgui.separator()
    imgui.text("Gogma reinforcement research")
    if imgui.button("Clear history##gogma_research") then
        debug_state.gogma_samples = {}
        debug_state.gogma_roll_calls = 0
        debug_state.gogma_arg_index = nil
        debug_state.gogma_mode = nil
        debug_state.gogma_before = nil
        debug_state.gogma_after = nil
        debug_state.gogma_rng = nil
        debug_state.gogma_prediction = nil
        debug_state.gogma_prediction_valid = nil
        debug_state.gogma_error = nil
        debug_state.target_bonus_calls = {}
        debug_state.selected_weapon_calls = 0
        debug_state.selected_weapon_type = nil
        debug_state.selected_weapon_fields = {}
        debug_state.selected_context_fields = {}
        debug_state.selected_context_details = {}
        debug_state.selected_weapon_equip_work = nil
        debug_state.selected_weapon_error = nil
    end
    imgui.text("Calls: " .. tostring(debug_state.gogma_roll_calls)
        .. " | equip arg: " .. tostring(debug_state.gogma_arg_index)
        .. " | mode: " .. tostring(debug_state.gogma_mode))
    imgui.text("BonusByGrinding: " .. tostring(debug_state.gogma_before)
        .. " -> " .. tostring(debug_state.gogma_after))
    imgui.text("BonusByCreating: " .. tostring(debug_state.gogma_creating))
    local rng = debug_state.gogma_rng
    if rng ~= nil then
        imgui.text("RNG: seed " .. tostring(rng.base_seed)
            .. " | skill counter " .. tostring(rng.counter)
            .. " | Gogma counter " .. tostring(rng.gogma_counter)
            .. " | gate " .. tostring(rng.counter_gate))
        imgui.text("Inputs: weapon " .. tostring(rng.weapon_type)
            .. " | attribute " .. tostring(rng.attribute_force)
            .. " | base bonus " .. tostring(rng.base_bonus))
    end
    if debug_state.gogma_error ~= nil then
        imgui.text("Probe error: " .. debug_state.gogma_error)
    end
    imgui.text("Selected weapon probe")
    imgui.text("Selections: " .. tostring(debug_state.selected_weapon_calls)
        .. " | type: " .. tostring(debug_state.selected_weapon_type)
        .. " | equip work: " .. tostring(debug_state.selected_weapon_equip_work))
    if debug_state.selected_weapon_error ~= nil then
        imgui.text("Selection error: " .. debug_state.selected_weapon_error)
    end
    if debug_state.selected_weapon_file_status ~= nil then
        imgui.text(debug_state.selected_weapon_file_status)
    end
    for index, record in ipairs(debug_state.target_bonus_calls) do
        imgui.text("Target " .. tostring(index)
            .. ": current " .. tostring(record.current_id)
            .. " | total " .. tostring(record.total)
            .. " | pool " .. table.concat(record.pool, ", "))
        if record.predicted_id ~= nil then
            imgui.text("  predicted id " .. tostring(record.predicted_id)
                .. " | roll " .. tostring(record.roll)
                .. "/" .. tostring(record.predicted_total))
        end
        if record.words ~= nil then
            imgui.text("  buffers: " .. tostring(record.return_buffer)
                .. " / " .. tostring(record.return_value)
                .. " | words " .. table.concat(record.words, ", "))
        end
        if record.error ~= nil then
            imgui.text("  decode error: " .. record.error)
        end
    end
    for index, sample in ipairs(debug_state.gogma_samples) do
        imgui.text(tostring(index) .. ": counters " .. tostring(sample.counter)
            .. "/" .. tostring(sample.gogma_counter)
            .. " | mode " .. tostring(sample.mode)
            .. " | pools " .. tostring(sample.target_calls)
            .. " | predicted " .. tostring(sample.predicted)
            .. " | valid " .. tostring(sample.valid)
            .. " | " .. tostring(sample.before) .. " -> " .. tostring(sample.after))
    end
end

re.on_config_save(save_config)

re.on_draw_ui(function()
    if not imgui.tree_node(MOD_NAME .. " v" .. VERSION) then
        return
    end
    local ok, err = pcall(function()
        draw_checkbox("Enable", "enabled")
        draw_checkbox("Debug", "debug")
        imgui.separator()
        draw_quick_start()
        imgui.separator()
        draw_base_route()
        imgui.separator()
        draw_skill_route()
        imgui.separator()
        draw_gogma_route()
        draw_combined_plan()
        draw_export()
        draw_debug_research()
        if state.last_error ~= "" then
            imgui.separator()
            imgui.text(state.last_error)
        end
    end)
    if not ok then
        state.last_error = "UI failed: " .. tostring(err)
        imgui.text(state.last_error)
    end
    imgui.tree_pop()
end)

load_config()
install_hooks()
