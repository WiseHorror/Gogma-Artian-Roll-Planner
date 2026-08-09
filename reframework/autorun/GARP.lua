-- Gogma Artian Roll Planner
-- Artian/Gogma skill and reinforcement route planner for Monster Hunter Wilds.

local MOD_NAME = "Gogma Artian Roll Planner"
local VERSION = "0.9.1"
local CONFIG_PATH = "GogmaArtianRollPlanner.json"
local EXPORT_DIRECTORY = "Gogma Artian Roll Planner"
local EXPORT_PATH = EXPORT_DIRECTORY .. "/GogmaArtianRollPlannerPredictions.csv"
local WEB_VALUES_PATH = EXPORT_DIRECTORY .. "/GogmaWebCalculatorValues.json"
local UINT32_MASK = 0xffffffff

-- Fixed smithy costs. Material inventories are deliberately not read or
-- optimized here: players can satisfy each point requirement with any mix.
local COSTS = {
    rarity8_forge_zenny = 10000,
    rarity8_parts_per_forge = 3,
    base_levels = 5,
    base_points_per_level = 3000,
    base_zenny_per_level = 2000,
    oricalcite_points = 300,
    gogma_upgrade_devices = 3,
    gogma_upgrade_zenny = 30000,
    skill_reset_points = 1500,
    skill_reset_zenny = 9000,
    gogma_amend_points = 6000,
    gogma_amend_zenny = 5000,
}

local state = {
    enabled = true,
    include_base_predictions = true,
    include_skill_predictions = true,
    include_gogma_predictions = true,
    include_reinforcement_predictions = true,
    plan_mode = 1,
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
    desired_reinforcement_1 = 10,
    desired_reinforcement_2 = 10,
    desired_reinforcement_3 = 8,
    desired_reinforcement_4 = 13,
    desired_reinforcement_5 = 11,
    target_weapon_type = 11,
    target_attribute = 5,
    material_attribute_1 = 5,
    material_attribute_2 = 5,
    material_attribute_3 = 5,
    material_infusion_1 = 1,
    material_infusion_2 = 1,
    material_infusion_3 = 1,
    existing_weapon_index = 1,
    existing_weapons = nil,
    existing_weapon_status = nil,
    existing_route_status = nil,
    existing_skill_resets = nil,
    existing_gogma_resets = nil,
    existing_gogma_keeps = nil,
    existing_gogma_value = nil,
    existing_start_gogma_value = nil,
    existing_skill_capture = nil,
    existing_gogma_capture = nil,
    existing_rng_state = nil,
    existing_total = nil,
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
    artian_create_counter_value = nil,
    -- Forge planning has a save-wide seed and must not overwrite rng_* above.
    creation_base_seed = nil,
    planning_saved_create_count = nil,
    planning_create_index = nil,
    base_reinforcement_predicted = nil,
    base_reinforcement_actual = nil,
    base_reinforcement_prediction_valid = nil,
    base_reinforcement_validation_detail = nil,
    base_nearby_predictions = nil,
    base_reinforcement_pool = nil,
    base_reinforcement_pool_detail = nil,
    base_reinforcement_pool_source = nil,
    base_forge_route_cache_key = nil,
    base_forge_route_distance = nil,
    base_forge_route_value = nil,
    base_forge_route_unavailable = nil,
    planning_input_error = nil,
    full_plan_status = nil,
    full_plan_forges = nil,
    full_plan_base_value = nil,
    full_plan_initial_skill_type = nil,
    full_plan_skill_resets = nil,
    full_plan_skills_pending = false,
    full_plan_skill_counter_snapshot = nil,
    full_plan_skill_capture = nil,
    full_plan_gogma_capture = nil,
    full_plan_gogma_resets = nil,
    full_plan_gogma_keeps = nil,
    full_plan_gogma_value = nil,
    full_plan_total = nil,
    full_plan_running = false,
    full_plan_progress = nil,
    export_status = nil,
    web_values_status = nil,
    last_error = "",
}

local function format_number(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    while true do
        local replaced, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        text = replaced
        if count == 0 then
            return text
        end
    end
end

local function full_plan_costs()
    if state.full_plan_forges == nil then
        return nil
    end
    local forges = state.full_plan_forges
    local reaches_gogma = state.include_skill_predictions
        or state.include_gogma_predictions
    local skill_resets = state.full_plan_skill_resets or 0
    local amendments = (state.full_plan_gogma_resets or 0)
        + (state.full_plan_gogma_keeps or 0)
    local base_points = COSTS.base_levels * COSTS.base_points_per_level
    local forge_zenny = forges * COSTS.rarity8_forge_zenny
    local base_zenny = COSTS.base_levels * COSTS.base_zenny_per_level
    local upgrade_zenny = reaches_gogma and COSTS.gogma_upgrade_zenny or 0
    local skill_points = skill_resets * COSTS.skill_reset_points
    local skill_zenny = skill_resets * COSTS.skill_reset_zenny
    local amend_points = amendments * COSTS.gogma_amend_points
    local amend_zenny = amendments * COSTS.gogma_amend_zenny
    return {
        forges = forges,
        forge_parts = forges * COSTS.rarity8_parts_per_forge,
        base_points = base_points,
        skill_points = skill_points,
        amend_points = amend_points,
        upgrade_devices = reaches_gogma and COSTS.gogma_upgrade_devices or 0,
        total_zenny = forge_zenny + base_zenny + upgrade_zenny
            + skill_zenny + amend_zenny,
    }
end

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

local weapon_type_names = {
    "Great Sword", "Sword & Shield", "Dual Blades", "Long Sword", "Hammer",
    "Hunting Horn", "Lance", "Gunlance", "Switch Axe", "Charge Blade",
    "Insect Glaive", "Bow", "Heavy Bowgun", "Light Bowgun",
}

local weapon_material_parts = {
    { "Blade", "Blade", "Tube" },   -- Great Sword
    { "Blade", "Tube", "Disc" },    -- Sword & Shield
    { "Blade", "Blade", "Disc" },   -- Dual Blades
    { "Blade", "Tube", "Tube" },    -- Long Sword
    { "Disc", "Disc", "Tube" },      -- Hammer
    { "Disc", "Device", "Device" },  -- Hunting Horn
    { "Blade", "Disc", "Disc" },     -- Lance
    { "Disc", "Disc", "Device" },    -- Gunlance
    { "Blade", "Blade", "Device" },  -- Switch Axe
    { "Blade", "Disc", "Device" },   -- Charge Blade
    { "Blade", "Tube", "Device" },   -- Insect Glaive
    { "Tube", "Tube", "Device" },    -- Bow
    { "Disc", "Tube", "Device" },    -- Heavy Bowgun
    { "Tube", "Device", "Device" },  -- Light Bowgun
}

local attribute_names = {
    "None", "Fire", "Water", "Thunder", "Ice", "Dragon", "Poison",
    "Paralysis", "Sleep", "Blast",
}
local infusion_names = { "Attack Infusion", "Affinity Infusion" }
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
    [4] = "Element Boost I",
    [6] = "Attack Boost I",
    [7] = "Sharpness Boost",
    [8] = "Affinity Boost I",
}
local saved_base_reinforcement_id_names = {
    [4] = "Attack Boost I",
    [6] = "Element Boost I",
    [7] = "Sharpness Boost",
    [8] = "Affinity Boost I",
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

local reinforcement_names = {
    "Attack Boost I", "Affinity Boost I", "Element Boost I", "Sharpness Boost",
    "Attack Boost II", "Affinity Boost II", "Element Boost II",
    "Attack Boost III", "Affinity Boost III", "Attack Boost EX",
    "Affinity Boost EX", "Element Boost EX", "Sharpness/Ammo Boost EX",
}
local reinforcement_base_ids = { 6, 8, 4, 7 }
local reinforcement_gogma_ids = {
    [4] = 6,
    [5] = 8, [6] = 9, [7] = 11,
    [8] = 12, [9] = 13, [10] = 15,
    [11] = 16, [12] = 14, [13] = 10,
}

local installed_hooks = {}
local current_skill_equip_work = nil
local current_skill_capture = nil
local current_weapon_type_out = nil
local resolving_skill_type = false
local latest_create_counter = nil
local artian_create_param = nil
local get_artian_create_count_method = nil
local resolving_create_counter_candidates = false
local capture_target_planning_inputs
local pending_base_prediction = nil
local active_base_pool_capture = nil
local lottery_method = nil
local base_bonus_method = nil
local attribute_force_method = nil
local artian_skill_type_method = nil
local resolve_artian_create_param
local collection_item
local try_object_field
local skill_attribute_force_for_recipe
local packed_reinforcement_tier
local full_plan_coroutine = nil
local full_plan_yield_enabled = false
local maybe_yield_full_plan

local function type_name_of(object)
    if object == nil then
        return nil
    end
    local ok, name = pcall(function()
        return object:get_type_definition():get_full_name()
    end)
    return ok and name or nil
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

local function u32(value)
    return value & UINT32_MASK
end

local function table_skill_type_from_runtime(value)
    value = tonumber(value)
    return value
end

local function to_u32_number(value)
    if value == nil then
        return nil
    end
    local direct = tonumber(value)
    if direct ~= nil then
        return direct & UINT32_MASK
    end
    local ok, converted = pcall(function()
        return tonumber(sdk.to_int64(value) & UINT32_MASK)
    end)
    return ok and converted or nil
end

local function clamp_index(value, values)
    value = tonumber(value) or 1
    return math.max(1, math.min(#values, math.floor(value)))
end

local function load_config()
    local ok, loaded = pcall(json.load_file, CONFIG_PATH)
    local has_unified_reinforcements = false
    if ok and type(loaded) == "table" then
        has_unified_reinforcements = loaded.desired_reinforcement_1 ~= nil
        for key, value in pairs(loaded) do
            if state[key] ~= nil then
                state[key] = value
            end
        end
    end
    state.desired_set_skill = clamp_index(state.desired_set_skill, set_skill_names)
    state.desired_group_skill = clamp_index(state.desired_group_skill, group_skill_names)
    state.plan_mode = clamp_index(state.plan_mode, { 1, 2 })
    state.target_weapon_type = clamp_index(state.target_weapon_type, weapon_type_names)
    state.target_attribute = clamp_index(state.target_attribute, attribute_names)
    for slot = 1, 3 do
        local attribute_key = "material_attribute_" .. tostring(slot)
        local infusion_key = "material_infusion_" .. tostring(slot)
        state[attribute_key] = clamp_index(state[attribute_key], attribute_names)
        state[infusion_key] = clamp_index(state[infusion_key], infusion_names)
    end
    for slot = 1, 5 do
        local unified_key = "desired_reinforcement_" .. tostring(slot)
        if not has_unified_reinforcements then
            local old_key = "desired_gogma_reinforcement_" .. tostring(slot)
            local old_index = clamp_index(state[old_key], gogma_bonus_names)
            local old_id = gogma_bonus_ids[old_index]
            for index, id in pairs(reinforcement_gogma_ids) do
                if id == old_id then
                    state[unified_key] = index
                    break
                end
            end
        end
        state[unified_key] = clamp_index(state[unified_key], reinforcement_names)
        local key = "desired_base_reinforcement_" .. tostring(slot)
        state[key] = clamp_index(state[key], base_reinforcement_names)
        key = "desired_gogma_reinforcement_" .. tostring(slot)
        state[key] = clamp_index(state[key], gogma_bonus_names)
    end
end

local function save_config()
    local persisted = {
        enabled = state.enabled,
        include_skill_predictions = state.include_skill_predictions,
        include_reinforcement_predictions = state.include_reinforcement_predictions,
        plan_mode = state.plan_mode,
        desired_set_skill = state.desired_set_skill,
        desired_group_skill = state.desired_group_skill,
        target_weapon_type = state.target_weapon_type,
        target_attribute = state.target_attribute,
        material_attribute_1 = state.material_attribute_1,
        material_attribute_2 = state.material_attribute_2,
        material_attribute_3 = state.material_attribute_3,
        material_infusion_1 = state.material_infusion_1,
        material_infusion_2 = state.material_infusion_2,
        material_infusion_3 = state.material_infusion_3,
    }
    for slot = 1, 5 do
        local unified_key = "desired_reinforcement_" .. tostring(slot)
        persisted[unified_key] = state[unified_key]
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

local function sync_reinforcement_target()
    local has_base_tier = false
    local has_gogma_tier = false
    for slot = 1, 5 do
        local selected = state["desired_reinforcement_" .. tostring(slot)] or 1
        if selected <= 3 then
            has_base_tier = true
        elseif selected >= 5 then
            has_gogma_tier = true
        end
    end

    if has_base_tier and has_gogma_tier then
        state.include_base_predictions = false
        state.include_gogma_predictions = false
        return nil, "Base I bonuses cannot be mixed with Gogma II/III/EX bonuses."
    end

    local use_gogma = has_gogma_tier
    state.include_base_predictions = state.include_reinforcement_predictions and not use_gogma
    state.include_gogma_predictions = state.include_reinforcement_predictions and use_gogma
    for slot = 1, 5 do
        local selected = state["desired_reinforcement_" .. tostring(slot)] or 1
        if use_gogma then
            local id = reinforcement_gogma_ids[selected]
            state["desired_gogma_reinforcement_" .. tostring(slot)] =
                index_of(gogma_bonus_ids, id) or 1
        else
            local id = reinforcement_base_ids[selected]
            state["desired_base_reinforcement_" .. tostring(slot)] =
                index_of(base_reinforcement_selector_ids, id) or 1
        end
    end
    return use_gogma and "gogma" or "base", nil
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

local function attribute_name_for_force(attribute_force)
    for index, _ in ipairs(attribute_names) do
        if skill_attribute_force_for_recipe(index) == attribute_force then
            return attribute_names[index]
        end
    end
    return "Attribute " .. tostring(attribute_force)
end

local function equip_field_number(equip_work, field_name)
    local ok, value = pcall(function()
        return equip_work:get_field(field_name)
    end)
    return ok and to_u32_number(value) or nil
end

local function equip_field_full_number(equip_work, field_name)
    local ok, value = pcall(function()
        return equip_work:get_field(field_name)
    end)
    if not ok or value == nil then
        return nil
    end
    local direct = tonumber(value)
    if direct ~= nil then
        return direct
    end
    local converted_ok, converted = pcall(function()
        return tonumber(sdk.to_int64(value))
    end)
    if converted_ok and converted ~= nil then
        return converted
    end
    local text = tostring(value)
    local digits = text ~= nil and text:gsub("%D", "") or nil
    return digits ~= nil and digits ~= "" and tonumber(digits) or nil
end

local function skill_type_from_bonus_by_creating(bonus_by_creating)
    bonus_by_creating = tonumber(bonus_by_creating)
    if bonus_by_creating == nil or bonus_by_creating <= 0 then
        return nil
    end
    local skill_digit_1 = math.floor(bonus_by_creating / 10000000) % 10
    local skill_digit_2 = math.floor(bonus_by_creating / 10000) % 10
    local skill_digit_3 = math.floor(bonus_by_creating / 10) % 10
    local fixed_skill_type = skill_digit_1 * 100 + skill_digit_2 * 10 + skill_digit_3
    return table_skill_type_from_runtime(fixed_skill_type - 1)
end

local function compact_gogma_reinforcements(packed)
    local parts = {}
    local is_gogma = packed_reinforcement_tier(packed) == "gogma"
    local ids = is_gogma and unpack_gogma_bonus_ids(packed) or {}
    if not is_gogma then
        local remaining = tonumber(packed) or 0
        for _ = 1, 5 do
            table.insert(ids, remaining % 1000)
            remaining = math.floor(remaining / 1000)
        end
    end
    for _, id in ipairs(ids) do
        local name = is_gogma and (gogma_bonus_names_by_id[id]
            or ("Bonus " .. tostring(id + 1)))
            or (saved_base_reinforcement_id_names[id] or ("Bonus " .. tostring(id)))
        name = name:gsub("Attack Boost", "Atk")
            :gsub("Affinity Boost", "Aff")
            :gsub("Element Boost", "Ele")
            :gsub("Sharpness/Ammo Boost", "Sharp")
            :gsub("Sharpness Boost", "Sharp")
        table.insert(parts, name)
    end
    return table.concat(parts, ", ")
end

local function attribute_force_from_performance_type(performance_type)
    performance_type = tonumber(performance_type)
    if performance_type == nil then
        return nil
    end
    local known = {
        [31204] = skill_attribute_force_for_recipe(1), -- None
        [22611] = skill_attribute_force_for_recipe(2), -- Fire
        [31749] = skill_attribute_force_for_recipe(3), -- Water
        [22190] = skill_attribute_force_for_recipe(4), -- Thunder
        -- Ice displays as attribute 5, but its existing-weapon roll seed uses
        -- force 3. This is distinct from the material recipe selector value.
        [29119] = 3, -- Ice
        [18812] = skill_attribute_force_for_recipe(6), -- Dragon
        [27364] = skill_attribute_force_for_recipe(7), -- Poison
        [19855] = skill_attribute_force_for_recipe(8), -- Paralysis
        [19961] = skill_attribute_force_for_recipe(9), -- Sleep
        [410] = skill_attribute_force_for_recipe(10), -- Blast
    }
    if known[performance_type] ~= nil then
        return known[performance_type]
    end
    -- Saved Artian equipment stores the performance type directly in FreeVal2.
    -- The first ten values line up with the attribute-force values used by the
    -- skill RNG seed; later values are non-elemental weapon performance variants.
    if performance_type >= 1 and performance_type <= 9 then
        return performance_type
    end
    return nil
end

local function attribute_index_from_performance_type(performance_type)
    local known = {
        [31204] = 1, -- None
        [22611] = 2, -- Fire
        [31749] = 3, -- Water
        [22190] = 4, -- Thunder
        [29119] = 5, -- Ice
        [18812] = 6, -- Dragon
        [27364] = 7, -- Poison
        [19855] = 8, -- Paralysis
        [19961] = 9, -- Sleep
        [410] = 10, -- Blast
    }
    return known[tonumber(performance_type)]
end

local function read_existing_gogma_weapons()
    local equip_param = resolve_artian_create_param ~= nil
        and resolve_artian_create_param(state.target_weapon_type - 1, 7) or nil
    if equip_param == nil then
        return {}, "Could not find the loaded character's equipment box."
    end
    local equip_box = try_object_field(equip_param, "_EquipBox")
    if equip_box == nil then
        return {}, "Could not read _EquipBox from the loaded character."
    end

    local weapons = {}
    local empty_streak = 0
    for index = 0, 999 do
        local equip_work = collection_item(equip_box, index)
        if equip_work == nil then
            empty_streak = empty_streak + 1
            if empty_streak > 30 then
                break
            end
        else
            empty_streak = 0
            local category = equip_field_number(equip_work, "Category_Gender") or 0
            local weapon_type = equip_field_number(equip_work, "FreeVal0")
            local bonus_by_creating = equip_field_number(equip_work, "BonusByCreating")
            local bonus_by_grinding_low = equip_field_number(equip_work, "BonusByGrinding") or 0
            local bonus_by_grinding = equip_field_full_number(equip_work, "BonusByGrinding")
                or bonus_by_grinding_low
            local performance_type = equip_field_number(equip_work, "FreeVal2")
            if category % 16 == 13 and weapon_type ~= nil
                    and bonus_by_grinding_low > 0 and performance_type ~= nil
                    and performance_type >= 0 then
                local attribute_force = attribute_force_from_performance_type(performance_type)
                local attribute_index = attribute_index_from_performance_type(performance_type)
                if attribute_force_method ~= nil then
                    local ok, value = pcall(function()
                        return attribute_force_method:call(equip_work)
                    end)
                    if ok and attribute_force == nil then
                        attribute_force = to_u32_number(value)
                    end
                end
                local skill_type = skill_type_from_bonus_by_creating(bonus_by_creating)
                if artian_skill_type_method ~= nil then
                    local ok, value = pcall(function()
                        return artian_skill_type_method:call(equip_work)
                    end)
                    if ok and skill_type == nil then
                        skill_type = table_skill_type_from_runtime(to_u32_number(value))
                    end
                end
                if attribute_force ~= nil and attribute_index == nil then
                    for candidate, _ in ipairs(attribute_names) do
                        if skill_attribute_force_for_recipe(candidate) == attribute_force then
                            attribute_index = candidate
                            break
                        end
                    end
                end
                if attribute_force ~= nil and attribute_index ~= nil and skill_type ~= nil then
                    local set_name, group_name = names_for_artian_skill_type(skill_type)
                    local label = "#" .. tostring(index + 1) .. " "
                        .. tostring(weapon_type_names[weapon_type + 1]
                            or ("Weapon " .. tostring(weapon_type)))
                        .. " / " .. tostring(attribute_names[attribute_index]
                            or ("Attribute " .. tostring(attribute_index)))
                    if set_name ~= nil and group_name ~= nil then
                        label = label .. " / " .. set_name .. " / " .. group_name
                    end
                    label = label .. " / " .. compact_gogma_reinforcements(bonus_by_grinding)
                    table.insert(weapons, {
                        label = label,
                        index = index,
                        weapon_type = weapon_type,
                        attribute_index = attribute_index,
                        attribute_force = attribute_force,
                        skill_type = skill_type,
                        gogma_value = bonus_by_grinding,
                    })
                end
            end
        end
    end
    return weapons, nil
end

local function refresh_existing_weapon_list()
    local previously_selected = state.existing_weapons ~= nil
        and state.existing_weapons[state.existing_weapon_index] or nil
    local weapons, err = read_existing_gogma_weapons()
    state.existing_weapons = weapons
    state.existing_weapon_index = clamp_index(state.existing_weapon_index, weapons)
    if previously_selected ~= nil then
        for index, weapon in ipairs(weapons) do
            if weapon.index == previously_selected.index then
                state.existing_weapon_index = index
                break
            end
        end
    end
    state.existing_weapon_status = err or ("Found " .. tostring(#weapons)
        .. " existing Gogma weapon(s).")
    return err == nil
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
        if rerolls % 100 == 0 then
            maybe_yield_full_plan("Searching skill resets: "
                .. tostring(rerolls) .. "/5000")
        end
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

local function desired_artian_skill_type()
    return artian_skill_type_for_names(
        set_skill_names[state.desired_set_skill],
        group_skill_names[state.desired_group_skill]
    )
end

local function recalculate_saved_plan_skill_target()
    local capture = state.full_plan_skill_capture
    if capture == nil or state.full_plan_initial_skill_type == nil then
        return
    end

    local desired_type = desired_artian_skill_type()
    local distance
    if state.full_plan_initial_skill_type == desired_type then
        distance = 0
    else
        local ignored_prediction
        ignored_prediction, distance = predict_skill_route(capture, desired_type)
    end
    local previous = state.full_plan_skill_resets or 0
    local updated = distance ~= nil and math.max(0, distance - 1) or nil
    state.full_plan_total = math.max(0, (state.full_plan_total or 0) - previous)
    state.full_plan_skill_resets = updated
    if updated ~= nil then
        state.full_plan_total = state.full_plan_total + updated
        state.full_plan_status =
            "Plan target updated from the saved skill-stream position."
    else
        state.full_plan_status =
            "The new skill target was not found within 5000 stream advances."
    end
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

local function derive_material_recipe()
    local counts = {}
    for slot = 1, 3 do
        local attribute = state["material_attribute_" .. tostring(slot)] or 1
        if attribute > 1 then
            counts[attribute] = (counts[attribute] or 0) + 1
        end
    end
    local final_attribute = 1
    local matching_parts = 0
    for attribute, count in pairs(counts) do
        if count > matching_parts then
            final_attribute = attribute
            matching_parts = count
        end
    end
    if matching_parts < 2 then
        final_attribute = 1
    end
    return final_attribute, matching_parts == 3
end

function skill_attribute_force_for_recipe(attribute)
    -- Element values observed so far match the selector index. Status values
    -- use the game's status enum range, where Poison starts at 6 and Blast is 9.
    return attribute >= 7 and attribute - 1 or attribute
end

local function configured_base_reinforcement_pool()
    local final_attribute = derive_material_recipe()
    local limits
    local order
    if final_attribute == 1 then
        limits = { [6] = 5, [7] = 2, [8] = 5 }
        order = { 6, 7, 8 }
    elseif final_attribute <= 6 then
        limits = { [4] = 5, [6] = 5, [7] = 2, [8] = 5 }
        order = { 6, 4, 7, 8 }
    else
        limits = { [4] = 5, [6] = 5, [7] = 2, [8] = 5 }
        order = { 4, 6, 7, 8 }
    end
    local pool = {}
    for _, bonus_id in ipairs(order) do
        if limits[bonus_id] > 0 then
            table.insert(pool, {
                bonus_id = bonus_id,
                count = 0,
                max_count = limits[bonus_id],
            })
        end
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

local function same_gogma_families(left, right)
    if #(left or {}) ~= #(right or {}) then
        return false
    end
    local counts = {}
    for _, id in ipairs(left) do
        local family = gogma_family_id(id)
        counts[family] = (counts[family] or 0) + 1
    end
    for _, id in ipairs(right) do
        local family = gogma_family_id(id)
        counts[family] = (counts[family] or 0) - 1
        if counts[family] < 0 then
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
        tostring(state.creation_base_seed), tostring(state.artian_create_weapon_type),
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
    if state.creation_base_seed == nil or state.artian_create_weapon_type == nil
        or state.artian_create_rarity == nil or state.artian_create_count_after == nil then
        return
    end

    local seed = u32(
        state.creation_base_seed + state.artian_create_weapon_type * 1000
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

function packed_reinforcement_tier(packed)
    packed = tonumber(packed)
    if packed == nil then
        return "unknown"
    end
    local has_gogma_id = false
    for _ = 1, 5 do
        local value = packed % 1000
        if value >= 9 then
            has_gogma_id = true
            break
        end
        packed = math.floor(packed / 1000)
    end
    return has_gogma_id and "gogma" or "base"
end

local function format_existing_reinforcements(packed)
    if packed_reinforcement_tier(packed) == "gogma" then
        return format_gogma_reinforcements(packed)
    end
    packed = tonumber(packed)
    if packed == nil then
        return "unknown"
    end
    local names = {}
    for _ = 1, 5 do
        local id = packed % 1000
        table.insert(names, saved_base_reinforcement_id_names[id]
            or ("Bonus " .. tostring(id)))
        packed = math.floor(packed / 1000)
    end
    return table.concat(names, " | ")
end

local function copy_rng(rng)
    return { x = rng.x, y = rng.y, z = rng.z, w = rng.w }
end

maybe_yield_full_plan = function(progress)
    if full_plan_yield_enabled then
        state.full_plan_progress = progress
        coroutine.yield()
    end
end

local function find_mixed_gogma_route_from(capture, current_value, target, limit)
    if current_value == nil or capture == nil or capture.gogma_counter == nil
        or capture.base_seed == nil or capture.weapon_type == nil
        or capture.attribute_force == nil then
        return nil, nil
    end
    local rng = initialize_gogma_rng(capture)
    if rng == nil then
        return nil, nil
    end
    local states = {
        { packed = current_value, last_reset = nil },
    }
    for distance = 1, limit or 5000 do
        if distance % 25 == 0 then
            maybe_yield_full_plan("Searching Gogma amendments: "
                .. tostring(distance) .. "/" .. tostring(limit or 5000))
        end
        local next_states = {}
        local seen = {}

        -- Reset ignores the previous reinforcement value, so every state has
        -- the same Reset successor at a given stream counter.
        local reset_result, reset_ids = simulate_gogma_roll(
            copy_rng(rng), current_value, 0
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

local function find_keep_gogma_route_from(capture, current_value, target, limit)
    local rng = initialize_gogma_rng(capture)
    if rng == nil then
        return nil, nil
    end
    local packed = current_value
    for distance = 1, limit or 5000 do
        local result, ids = simulate_gogma_roll(copy_rng(rng), packed, 1)
        if result == nil then
            return nil, nil
        end
        if same_multiset(ids, target) then
            return distance, result
        end
        packed = result
        for _ = 1, 10 do
            rng.x, rng.y, rng.z, rng.w = rng_step(rng.x, rng.y, rng.z, rng.w)
        end
    end
    return nil, nil
end

local function find_mixed_gogma_route(target)
    return find_mixed_gogma_route_from({
        base_seed = state.rng_base_seed,
        weapon_type = state.rng_weapon_type,
        attribute_force = state.rng_attribute_force,
        gogma_counter = state.gogma_next_counter,
        counter_gate = state.rng_counter_gate,
    }, state.gogma_current_value, target, 5000)
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
                state.rng_base_seed = current_skill_capture.base_seed
                state.rng_base_seed_raw = current_skill_capture.base_seed_raw
                state.rng_counter_gate = current_skill_capture.counter_gate
                state.rng_counter = current_skill_capture.counter
                state.rng_base_bonus = current_skill_capture.base_bonus
                state.rng_attribute_force = current_skill_capture.attribute_force
                state.rng_weapon_type = current_skill_capture.weapon_type
                state.skill_counter_is_next = false
                state.skill_route_cache_key = nil
                refresh_skill_route()
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

local function install_create_count_hooks()
    local type_def = sdk.find_type_definition("app.savedata.cEquipParam")
    local get_method = type_def:get_method(
        "getArtianCreateCount(app.WeaponDef.TYPE,app.ItemDef.RARE)"
    ) or type_def:get_method("getArtianCreateCount")
    local add_method = type_def:get_method(
        "addArtianCreateCount(app.WeaponDef.TYPE,app.ItemDef.RARE)"
    ) or type_def:get_method("addArtianCreateCount")
    get_artian_create_count_method = get_method

    sdk.hook(get_method, function(args)
        local storage = thread.get_hook_storage()
        storage["create_counter_probe"] = resolving_create_counter_candidates
        local ok, object = pcall(sdk.to_managed_object, args[2])
        if not storage["create_counter_probe"] and ok and object ~= nil then
            artian_create_param = object
        end
        storage["create_type"] = tonumber(sdk.to_int64(args[3]))
        storage["create_rarity"] = tonumber(sdk.to_int64(args[4]))
    end, function(retval)
        local storage = thread.get_hook_storage()
        local weapon_type = storage["create_type"]
        local rarity = storage["create_rarity"]
        if not storage["create_counter_probe"]
            and state.enabled and weapon_type ~= nil and rarity ~= nil then
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
            state.artian_create_counter_value = count + 1
            local ok, rng = pcall(read_skill_rng_state)
            if ok and rng ~= nil then
                state.creation_base_seed = rng.base_seed
            end
            state.base_reinforcement_predicted = predict_base_reinforcement(
                state.creation_base_seed, weapon_type, rarity, count,
                state.base_reinforcement_pool
            )
            state.base_reinforcement_prediction_valid = nil
            state.base_forge_route_cache_key = nil
        end
        storage["create_type"] = nil
        storage["create_rarity"] = nil
        storage["create_counter_probe"] = nil
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
                state.creation_base_seed,
                weapon_type,
                rarity,
                latest_create_counter.before,
                active_base_pool_capture ~= nil
                    and active_base_pool_capture.entries
                    or state.base_reinforcement_pool
            )
            latest_create_counter.after = latest_create_counter.before + 1
            state.artian_create_count_after = latest_create_counter.after
            state.artian_create_counter_value = latest_create_counter.after + 1
            state.base_forge_route_cache_key = nil
        end
    end, function(retval)
        return retval
    end)
end

local function calculate_from_scratch_plan()
    state.full_plan_status = nil
    state.full_plan_forges = nil
    state.full_plan_base_value = nil
    state.full_plan_initial_skill_type = nil
    state.full_plan_skill_resets = nil
    state.full_plan_skills_pending = false
    state.full_plan_skill_counter_snapshot = nil
    state.full_plan_skill_capture = nil
    state.full_plan_gogma_capture = nil
    state.full_plan_gogma_resets = nil
    state.full_plan_gogma_keeps = nil
    state.full_plan_gogma_value = nil
    state.full_plan_total = nil

    local _, target_error = sync_reinforcement_target()
    if target_error ~= nil then
        state.full_plan_status = target_error
        return
    end

    local rng_state, input_error = capture_target_planning_inputs()
    if rng_state == nil then
        state.full_plan_status = input_error
        return
    end

    local weapon_type = state.target_weapon_type - 1
    local attribute = skill_attribute_force_for_recipe(state.target_attribute)
    local pool = state.base_reinforcement_pool
    if pool == nil or #pool == 0 then
        state.full_plan_status = "The final recipe's base bonus pool is not identified."
        return
    end

    state.full_plan_skill_counter_snapshot = rng_state.counter

    local skill_resets = 0
    if state.include_skill_predictions then
        local skill_capture = {
            base_seed = rng_state.base_seed,
            weapon_type = weapon_type,
            attribute_force = attribute,
            counter = rng_state.counter,
            counter_gate = rng_state.counter_gate,
            counter_is_next = false,
        }
        local desired_type = desired_artian_skill_type()
        local initial_type, distance = predict_skill_route(skill_capture, desired_type)
        state.full_plan_initial_skill_type = initial_type
        state.full_plan_skill_capture = skill_capture
        if initial_type == desired_type then
            skill_resets = 0
        elseif distance ~= nil then
            skill_resets = distance
        else
            state.full_plan_status =
                "The selected Gogma skill target was not found within 5000 resets."
            return
        end
    end

    local base_target = selected_base_bonus_ids()
    local constrain_base_target = state.include_base_predictions
        and not state.include_gogma_predictions
    if constrain_base_target then
        local reason = unavailable_base_target_reason(pool, base_target)
        if reason ~= nil then
            state.full_plan_status = "Final recipe cannot produce the base target: " .. reason
            return
        end
    end

    local gogma_capture = {
        base_seed = rng_state.base_seed,
        weapon_type = weapon_type,
        attribute_force = attribute,
        gogma_counter = rng_state.gogma_counter,
        counter_gate = rng_state.counter_gate,
    }
    state.full_plan_gogma_capture = gogma_capture
    local gogma_target = selected_gogma_bonus_ids()
    local seed = u32(rng_state.base_seed + weapon_type * 1000 + 7) ~ 0x00ac9365
    local x, y, z, w = initialize_rng(seed)
    for _ = 1, state.artian_create_count_after * 10 do
        x, y, z, w = rng_step(x, y, z, w)
    end

    local best = nil
    local route_cache = {}
    for offset = 0, 4999 do
        if offset % 10 == 0 then
            maybe_yield_full_plan("Searching base forges: "
                .. tostring(offset + 1) .. "/5000")
        end
        local packed, bonuses
        x, y, z, w, packed, bonuses = draw_base_reinforcement(x, y, z, w, pool)
        local forge_count = offset + 1
        local eligible = not constrain_base_target
            or same_multiset(bonuses, base_target)
        if eligible then
            local reset_count, keep_count, result = 0, 0, packed
            local amendments = 0
            if state.include_gogma_predictions
                and not same_multiset(unpack_gogma_bonus_ids(packed), gogma_target) then
                local route_key = gogma_family_layout(packed)
                local cached = route_cache[route_key]
                if cached == nil then
                    local remaining = best ~= nil
                        and math.max(0, best.total - forge_count - skill_resets - 1)
                        or 5000
                    local distance, value, last_reset = find_mixed_gogma_route_from(
                        gogma_capture, packed, gogma_target, remaining
                    )
                    if distance == nil then
                        cached = false
                    else
                        cached = {
                            distance = distance,
                            value = value,
                            resets = last_reset or 0,
                            keeps = last_reset ~= nil
                                and distance - last_reset or distance,
                        }
                    end
                    route_cache[route_key] = cached
                end
                if cached == false then
                    eligible = false
                else
                    amendments = cached.distance
                    reset_count = cached.resets
                    keep_count = cached.keeps
                    result = cached.value
                end
            end
            if eligible then
                local total = forge_count + skill_resets + amendments
                if best == nil or total < best.total then
                    best = {
                        total = total,
                        forges = forge_count,
                        base_value = packed,
                        resets = reset_count,
                        keeps = keep_count,
                        gogma_value = result,
                    }
                end
            end
        end
        if best ~= nil and forge_count >= best.total then
            break
        end
        for _ = 1, 5 do
            x, y, z, w = rng_step(x, y, z, w)
        end
    end

    if best == nil then
        state.full_plan_status = "No complete route was found within 5000 target-type forges."
        return
    end
    state.full_plan_forges = best.forges
    state.full_plan_base_value = best.base_value
    state.full_plan_skill_resets = skill_resets
    state.full_plan_gogma_resets = best.resets
    state.full_plan_gogma_keeps = best.keeps
    state.full_plan_gogma_value = best.gogma_value
    state.full_plan_total = best.total
    state.full_plan_status = nil
end

local function calculate_existing_weapon_route()
    state.existing_route_status = nil
    state.existing_skill_resets = nil
    state.existing_gogma_resets = nil
    state.existing_gogma_keeps = nil
    state.existing_gogma_value = nil
    state.existing_start_gogma_value = nil
    state.existing_skill_capture = nil
    state.existing_gogma_capture = nil
    state.existing_rng_state = nil
    state.existing_total = nil

    if not refresh_existing_weapon_list() then
        state.existing_route_status = state.existing_weapon_status
        return
    end

    local mode, target_error = sync_reinforcement_target()
    if target_error ~= nil then
        state.existing_route_status = target_error
        return
    end

    local rng_state = read_skill_rng_state()
    if rng_state == nil then
        state.existing_route_status =
            "Existing weapon route needs Artian RNG state. Open the smithy, then try again."
        return
    end
    state.existing_rng_state = rng_state

    local weapons = state.existing_weapons
    local selected_weapon = weapons ~= nil and weapons[state.existing_weapon_index] or nil
    if selected_weapon == nil then
        state.existing_route_status =
            "Refresh existing weapons, then choose a Gogma weapon."
        return
    end

    local total = 0
    if state.include_skill_predictions then
        local current_type = selected_weapon.skill_type
        local desired_type = desired_artian_skill_type()
        if current_type == desired_type then
            state.existing_skill_resets = 0
        else
            local ignored_prediction, distance = predict_skill_route({
                base_seed = rng_state.base_seed,
                weapon_type = selected_weapon.weapon_type,
                attribute_force = selected_weapon.attribute_force,
                counter = rng_state.counter,
                counter_gate = rng_state.counter_gate,
                counter_is_next = true,
            }, desired_type)
            if distance == nil then
                state.existing_route_status =
                    "The selected Gogma skill target was not found within 5000 resets."
                return
            end
            state.existing_skill_resets = distance
            state.existing_skill_capture = {
                base_seed = rng_state.base_seed,
                weapon_type = selected_weapon.weapon_type,
                attribute_force = selected_weapon.attribute_force,
                counter = rng_state.counter,
                counter_gate = rng_state.counter_gate,
                counter_is_next = true,
            }
            total = total + distance
        end
    else
        state.existing_skill_resets = 0
    end

    if state.include_reinforcement_predictions then
        if mode ~= "gogma" then
            state.existing_route_status =
                "Existing weapon amendments require a Gogma-tier reinforcement target."
            return
        end
        local current_value = selected_weapon.gogma_value
        state.existing_start_gogma_value = current_value
        if packed_reinforcement_tier(current_value) ~= "gogma" then
            state.existing_route_status =
                "The selected weapon is still base Artian; upgrade it to Gogma before amendment planning."
            return
        end
        local target = selected_gogma_bonus_ids()
        if same_multiset(unpack_gogma_bonus_ids(current_value), target) then
            state.existing_gogma_resets = 0
            state.existing_gogma_keeps = 0
            state.existing_gogma_value = current_value
        else
            local capture = {
                base_seed = rng_state.base_seed,
                weapon_type = selected_weapon.weapon_type,
                attribute_force = selected_weapon.attribute_force,
                gogma_counter = rng_state.gogma_counter,
                counter_gate = rng_state.counter_gate,
            }
            local current_ids = unpack_gogma_bonus_ids(current_value)
            local distance, value, last_reset
            if same_gogma_families(current_ids, target) then
                distance, value = find_keep_gogma_route_from(
                    capture, current_value, target, 5000
                )
            end
            if distance == nil then
                distance, value, last_reset = find_mixed_gogma_route_from(
                    capture, current_value, target, 5000
                )
            end
            if distance == nil then
                state.existing_route_status =
                    "The selected Gogma reinforcement target was not found within 5000 amendments."
                return
            end
            state.existing_gogma_resets = last_reset or 0
            state.existing_gogma_keeps = last_reset ~= nil
                and distance - last_reset or distance
            state.existing_gogma_value = value
            state.existing_gogma_capture = {
                base_seed = rng_state.base_seed,
                weapon_type = selected_weapon.weapon_type,
                attribute_force = selected_weapon.attribute_force,
                gogma_counter = rng_state.gogma_counter,
                counter_gate = rng_state.counter_gate,
            }
            total = total + distance
        end
    else
        state.existing_gogma_resets = 0
        state.existing_gogma_keeps = 0
    end

    state.existing_total = total
    state.existing_route_status = "Existing weapon route calculated."
end

local function start_full_plan_calculation()
    if state.full_plan_running then
        return
    end
    state.full_plan_running = true
    state.full_plan_progress = "Starting..."
    state.full_plan_status = "Calculating full plan..."
    full_plan_coroutine = coroutine.create(function()
        full_plan_yield_enabled = true
        local ok, err = pcall(calculate_from_scratch_plan)
        full_plan_yield_enabled = false
        if not ok then
            state.full_plan_status = "Calculation failed: " .. tostring(err)
        end
    end)
end

local function resume_full_plan_calculation()
    if full_plan_coroutine == nil then
        return
    end
    for _ = 1, 4 do
        if full_plan_coroutine == nil then
            return
        end
        local ok, err = coroutine.resume(full_plan_coroutine)
        if not ok then
            full_plan_yield_enabled = false
            state.full_plan_running = false
            state.full_plan_progress = nil
            full_plan_coroutine = nil
            state.full_plan_status = "Calculation failed: " .. tostring(err)
            return
        end
        local status = coroutine.status(full_plan_coroutine)
        if status == "dead" then
            full_plan_yield_enabled = false
            state.full_plan_running = false
            state.full_plan_progress = nil
            full_plan_coroutine = nil
            return
        end
    end
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

local function find_equip_param_in_object(object, depth, visited, budget)
    if object == nil or depth > 5 or budget.remaining <= 0 then
        return nil
    end
    local object_type = type_name_of(object)
    if object_type == "app.savedata.cEquipParam" then
        return object
    end
    if object_type == nil then
        return nil
    end
    local address = tostring(object)
    if visited[address] then
        return nil
    end
    visited[address] = true
    budget.remaining = budget.remaining - 1

    local ok, type_def = pcall(function()
        return object:get_type_definition()
    end)
    if not ok or type_def == nil then
        return nil
    end

    while type_def ~= nil do
        local fields_ok, fields = pcall(function()
            return type_def:get_fields()
        end)
        if fields_ok and fields ~= nil then
            for _, field in ipairs(fields) do
                local field_type = field:get_type():get_full_name()
                if field_type == "app.savedata.cEquipParam" then
                    local value_ok, value = pcall(function()
                        return object:get_field(field:get_name())
                    end)
                    if value_ok and value ~= nil then
                        return value
                    end
                elseif depth < 6 and (field_type:find("app.", 1, true) == 1
                        or field_type:find("ace.", 1, true) == 1) then
                    local value_ok, value = pcall(function()
                        return object:get_field(field:get_name())
                    end)
                    if value_ok and value ~= nil then
                        local found = find_equip_param_in_object(
                            value, depth + 1, visited, budget)
                        if found ~= nil then
                            return found
                        end
                    end
                end
            end
        end
        local parent_ok, parent = pcall(function()
            return type_def:get_parent_type()
        end)
        type_def = parent_ok and parent or nil
    end
    return nil
end

local function collect_equip_params_in_object(object, depth, visited, budget, results)
    if object == nil or depth > 5 or budget.remaining <= 0 then
        return
    end
    local object_type = type_name_of(object)
    if object_type == "app.savedata.cEquipParam" then
        local key = tostring(object)
        if not visited[key] then
            visited[key] = true
            table.insert(results, object)
        end
        return
    end
    if object_type == nil then
        return
    end
    local address = tostring(object)
    if visited[address] then
        return
    end
    visited[address] = true
    budget.remaining = budget.remaining - 1

    local ok, type_def = pcall(function()
        return object:get_type_definition()
    end)
    if not ok or type_def == nil then
        return
    end
    while type_def ~= nil do
        local fields_ok, fields = pcall(function()
            return type_def:get_fields()
        end)
        if fields_ok and fields ~= nil then
            for _, field in ipairs(fields) do
                local field_type = field:get_type():get_full_name()
                if field_type == "app.savedata.cEquipParam"
                        or (depth < 5 and (field_type:find("app.", 1, true) == 1
                            or field_type:find("ace.", 1, true) == 1)) then
                    local value_ok, value = pcall(function()
                        return object:get_field(field:get_name())
                    end)
                    if value_ok and value ~= nil then
                        collect_equip_params_in_object(
                            value, depth + 1, visited, budget, results)
                    end
                end
            end
        end
        local parent_ok, parent = pcall(function()
            return type_def:get_parent_type()
        end)
        type_def = parent_ok and parent or nil
    end
end

function try_object_field(object, field_name)
    if object == nil then
        return nil
    end
    local ok, value = pcall(function()
        return object:get_field(field_name)
    end)
    return ok and value or nil
end

function collection_item(collection, index)
    if collection == nil or index == nil or index < 0 then
        return nil
    end
    local accessors = { "get_Item", "GetValue" }
    for _, accessor in ipairs(accessors) do
        local ok, value = pcall(function()
            return collection:call(accessor, index)
        end)
        if ok and value ~= nil then
            return value
        end
    end
    local ok, value = pcall(function()
        return collection:get_element(index)
    end)
    return ok and value or nil
end

local function read_create_count_without_capture(param, weapon_type, rarity)
    resolving_create_counter_candidates = true
    local ok, value = pcall(function()
        return get_artian_create_count_method:call(
            param, weapon_type, rarity)
    end)
    resolving_create_counter_candidates = false
    return ok, value
end

local function equip_param_from_save_slot(collection, index)
    local slot = collection_item(collection, index)
    if slot == nil then
        return nil
    end
    return find_equip_param_in_object(
        slot, 0, {}, { remaining = 500 })
end

local function resolve_active_equip_param(singleton, user_save, user_data)
    -- Prefer an actual active-save reference. _UserSaveData._Data is the
    -- complete save-slot array, so recursively taking its first cEquipParam
    -- can silently read another character's Artian counter.
    local active_object_fields = {
        "_CurrentUserSaveData", "CurrentUserSaveData",
        "_CurrentSaveData", "CurrentSaveData",
        "_LoadedUserSaveData", "LoadedUserSaveData",
        "_ActiveUserSaveData", "ActiveUserSaveData",
    }
    for _, owner in ipairs({ singleton, user_save }) do
        for _, field_name in ipairs(active_object_fields) do
            local active = try_object_field(owner, field_name)
            local found = find_equip_param_in_object(
                active, 0, {}, { remaining = 500 })
            if found ~= nil then
                return found
            end
        end
    end

    local active_index_fields = {
        "CurrentUserDataIndex", "_CurrentUserDataIndex",
        "_CurrentUserSaveDataIndex", "CurrentUserSaveDataIndex",
        "_CurrentSaveDataIndex", "CurrentSaveDataIndex",
        "_LoadedSaveDataIndex", "LoadedSaveDataIndex",
        "_ActiveSaveDataIndex", "ActiveSaveDataIndex",
        "_UserSaveDataIndex", "UserSaveDataIndex",
        "_CurrentSaveSlot", "CurrentSaveSlot",
        "_SaveDataIndex", "SaveDataIndex",
    }
    for _, owner in ipairs({ singleton, user_save }) do
        for _, field_name in ipairs(active_index_fields) do
            local index = tonumber(try_object_field(owner, field_name))
            if index ~= nil then
                -- Runtime indices are normally zero-based. Also accept a
                -- one-based slot number for fields exposed as a save slot.
                local found = equip_param_from_save_slot(user_data, index)
                if found == nil and index > 0 then
                    found = equip_param_from_save_slot(user_data, index - 1)
                end
                if found ~= nil then
                    return found
                end
            end
        end
    end

    -- Game updates sometimes rename private fields while retaining descriptive
    -- metadata. Discover equivalent active-save fields without traversing the
    -- slot contents themselves.
    for _, owner in ipairs({ singleton, user_save }) do
        local type_ok, type_def = pcall(function()
            return owner ~= nil and owner:get_type_definition() or nil
        end)
        if type_ok and type_def ~= nil then
            local fields_ok, fields = pcall(function()
                return type_def:get_fields()
            end)
            if fields_ok and fields ~= nil then
                for _, field in ipairs(fields) do
                    local name = field:get_name()
                    local lower = name:lower()
                    if lower:find("save", 1, true) ~= nil
                            and (lower:find("current", 1, true) ~= nil
                                or lower:find("active", 1, true) ~= nil
                                or lower:find("loaded", 1, true) ~= nil) then
                        local value = try_object_field(owner, name)
                        local found = find_equip_param_in_object(
                            value, 0, {}, { remaining = 500 })
                        if found ~= nil then
                            return found
                        end
                        if lower:find("index", 1, true) ~= nil
                                or lower:find("slot", 1, true) ~= nil then
                            local index = tonumber(value)
                            if index ~= nil then
                                found = equip_param_from_save_slot(user_data, index)
                                if found == nil and index > 0 then
                                    found = equip_param_from_save_slot(
                                        user_data, index - 1)
                                end
                                if found ~= nil then
                                    return found
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function find_equip_param_in_collection(collection)
    if collection == nil then
        return nil
    end
    local direct = find_equip_param_in_object(
        collection, 0, {}, { remaining = 500 })
    if direct ~= nil then
        return direct
    end

    local count = nil
    local get_count_ok, get_count = pcall(function()
        return collection:call("get_Count")
    end)
    if get_count_ok then
        count = tonumber(get_count)
    end
    if count == nil then
        local length_ok, length = pcall(function()
            return collection:call("get_Length")
        end)
        if length_ok then
            count = tonumber(length)
        end
    end
    if count == nil then
        local size_ok, size = pcall(function()
            return collection:get_size()
        end)
        if size_ok then
            count = tonumber(size)
        end
    end
    if count == nil then
        return nil
    end

    for index = 0, math.min(count - 1, 15) do
        local item = nil
        local item_ok, item_value = pcall(function()
            return collection:call("get_Item", index)
        end)
        if item_ok then
            item = item_value
        end
        if item == nil then
            item_ok, item_value = pcall(function()
                return collection:call("GetValue", index)
            end)
            if item_ok then
                item = item_value
            end
        end
        if item == nil then
            item_ok, item_value = pcall(function()
                return collection:get_element(index)
            end)
            if item_ok then
                item = item_value
            end
        end
        if item ~= nil then
            local found = find_equip_param_in_object(
                item, 0, {}, { remaining = 500 })
            if found ~= nil then
                return found
            end
        end
    end
    return nil
end

function resolve_artian_create_param(weapon_type, rarity)
    -- Save reloads replace the active save graph without reloading this Lua
    -- script. Reacquire the parameter object before consulting the cached hook
    -- value, otherwise plans can silently use a counter from the previous save.
    local cached_param = artian_create_param
    local singleton_names = {
        "app.SaveDataManager",
        "app.SavedataManager",
        "app.SaveDataSystem",
    }
    local resolvers = {
        sdk.get_managed_singleton,
        sdk.get_native_singleton,
    }
    for _, resolver in ipairs(resolvers) do
        if resolver ~= nil then
            for _, singleton_name in ipairs(singleton_names) do
                local ok, singleton = pcall(resolver, singleton_name)
                if ok and singleton ~= nil then
                    local user_save = try_object_field(singleton, "_UserSaveData")
                    local user_data = try_object_field(user_save, "_Data")
                    local found = resolve_active_equip_param(
                        singleton, user_save, user_data)
                    if found == nil then
                        -- A hook-captured parameter is known to belong to the
                        -- live save and is safer than guessing the first slot.
                        found = cached_param
                    end
                    if found ~= nil then
                        artian_create_param = found
                        return found
                    end
                end
            end
        end
    end
    return cached_param
end

local function read_target_create_count(weapon_type, rarity)
    local create_param = resolve_artian_create_param(weapon_type, rarity)
    if create_param == nil or get_artian_create_count_method == nil then
        return nil, "Could not locate the loaded character's Artian creation counter."
    end
    local ok, value = read_create_count_without_capture(
        create_param, weapon_type, rarity)
    if not ok then
        return nil, tostring(value)
    end
    return tonumber(value), nil
end

capture_target_planning_inputs = function()
    local weapon_type = state.target_weapon_type - 1
    local rarity = 7
    local final_attribute = derive_material_recipe()
    state.target_attribute = final_attribute
    local count, count_error = read_target_create_count(weapon_type, rarity)
    if count == nil then
        state.planning_input_error = count_error
        return nil, count_error
    end

    local rng_state = read_skill_rng_state()
    if rng_state == nil then
        state.planning_input_error = "Could not read the saved RNG state."
        return nil, state.planning_input_error
    end

    local pool = configured_base_reinforcement_pool()
    local capacity = 0
    for _, entry in ipairs(pool) do
        capacity = capacity + entry.max_count
    end
    if capacity < 5 then
        state.planning_input_error =
            "The selected materials cannot produce a five-bonus reinforcement pool."
        return nil, state.planning_input_error
    end

    state.artian_create_weapon_type = weapon_type
    state.artian_create_rarity = rarity
    -- getArtianCreateCount returns the RNG block consumed by the next forge.
    -- Validation against the live forge hook must therefore use it unchanged.
    local next_create_index = count
    state.planning_saved_create_count = count
    state.planning_create_index = next_create_index
    state.artian_create_counter_value = next_create_index + 1
    state.artian_create_count_before = next_create_index
    state.artian_create_count_after = next_create_index
    state.creation_base_seed = rng_state.base_seed
    set_base_reinforcement_pool(pool, "selected final materials")
    state.base_reinforcement_prediction_valid = nil
    state.base_reinforcement_validation_detail = nil
    state.base_forge_route_cache_key = nil
    state.planning_input_error = nil
    return rng_state, nil
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
                    state.creation_base_seed,
                    state.artian_create_weapon_type,
                    state.artian_create_rarity,
                    expected_count,
                    state.base_reinforcement_pool
                )
            end
            state.base_reinforcement_actual = actual

            local nearby = {}
            if state.creation_base_seed ~= nil
                and state.artian_create_weapon_type ~= nil
                and state.artian_create_rarity ~= nil
                and expected_count ~= nil then
                for count = math.max(0, expected_count - 3), expected_count + 3 do
                    local value = predict_base_reinforcement(
                        state.creation_base_seed,
                        state.artian_create_weapon_type,
                        state.artian_create_rarity,
                        count,
                        state.base_reinforcement_pool
                    )
                    table.insert(nearby, tostring(count) .. "=" .. tostring(value))
                end
            end
            state.base_nearby_predictions = table.concat(nearby, " | ")

            if predicted ~= actual and expected_count ~= nil then
                local fitted_pool = fit_base_reinforcement_pool(
                    state.creation_base_seed,
                    state.artian_create_weapon_type,
                    state.artian_create_rarity,
                    expected_count,
                    actual
                )
                if fitted_pool ~= nil then
                    set_base_reinforcement_pool(fitted_pool, "fitted native recipe pool")
                    predicted = predict_base_reinforcement(
                        state.creation_base_seed,
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
                and state.creation_base_seed ~= nil
                and state.artian_create_weapon_type ~= nil
                and state.artian_create_rarity ~= nil then
                local first_count = math.max(0, expected_count - 3)
                for count = first_count, expected_count + 3 do
                    local candidate = predict_base_reinforcement(
                        state.creation_base_seed,
                        state.artian_create_weapon_type,
                        state.artian_create_rarity,
                        count,
                        state.base_reinforcement_pool
                    )
                    if candidate == actual then
                        predicted = candidate
                        state.artian_create_count_before = count
                        state.artian_create_count_after = count + 1
                        state.artian_create_counter_value = count + 2
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
                "seed " .. tostring(state.creation_base_seed),
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

local function draw_export_status(text)
    if text:sub(1, 13) == "Export failed" then
        draw_colored_text(text, 0xff8080ff)
    else
        imgui.text(text)
    end
end

local function reinforcement_target_json()
    return table.concat({
        tostring(state.desired_reinforcement_1), tostring(state.desired_reinforcement_2),
        tostring(state.desired_reinforcement_3), tostring(state.desired_reinforcement_4),
        tostring(state.desired_reinforcement_5),
    }, ", ")
end

local function attribute_index_for_force(attribute_force)
    for index, _ in ipairs(attribute_names) do
        if skill_attribute_force_for_recipe(index) == attribute_force then
            return index
        end
    end
    return 1
end

local function existing_weapon_web_json(weapon)
    local set_name, group_name = names_for_artian_skill_type(weapon.skill_type)
    local set_index = index_of(set_skill_names, set_name)
    local group_index = index_of(group_skill_names, group_name)
    if set_index == nil or group_index == nil then
        return nil
    end
    local tier = packed_reinforcement_tier(weapon.gogma_value)
    local reinforcements = {}
    local packed = tonumber(weapon.gogma_value) or 0
    for _ = 1, 5 do
        local value = packed % 1000
        table.insert(reinforcements, tostring(tier == "gogma" and value - 1 or value))
        packed = math.floor(packed / 1000)
    end
    return "{"
        .. '"weaponType":' .. tostring(weapon.weapon_type) .. ","
        .. '"existingAttribute":' .. tostring(weapon.attribute_index
            or attribute_index_for_force(weapon.attribute_force)) .. ","
        .. '"attributeForce":' .. tostring(weapon.attribute_force) .. ","
        .. '"currentSetSkill":' .. tostring(set_index) .. ","
        .. '"currentGroupSkill":' .. tostring(group_index) .. ","
        .. '"currentReinforcementTier":"' .. tier .. '",'
        .. '"currentReinforcements":[' .. table.concat(reinforcements, ",") .. "]"
        .. "}"
end

local function new_weapon_web_calculator_values_text()
    local final_attribute = derive_material_recipe()
    local skill_capture = state.full_plan_skill_capture or {}
    local gogma_capture = state.full_plan_gogma_capture or {}
    local lines = {
        "{",
        '  "baseSeed": ' .. tostring(state.creation_base_seed
            or skill_capture.base_seed or state.rng_base_seed or 0) .. ",",
        '  "skillCounter": ' .. tostring(skill_capture.counter
            or state.rng_counter or 0) .. ",",
        '  "gogmaCounter": ' .. tostring(gogma_capture.gogma_counter or 0) .. ",",
        '  "counterGate": ' .. tostring(skill_capture.counter_gate
            or gogma_capture.counter_gate or state.rng_counter_gate or 0) .. ",",
        '  "createCount": ' .. tostring(state.planning_create_index
            or state.artian_create_count_after or 0) .. ",",
        '  "weaponType": ' .. tostring(state.target_weapon_type - 1) .. ",",
        '  "rarity": 7,',
        '  "attribute": ' .. tostring(final_attribute) .. ",",
        '  "attributeForce": ' .. tostring(skill_attribute_force_for_recipe(final_attribute)) .. ",",
        '  "materialAttributes": [' .. table.concat({
            tostring(state.material_attribute_1), tostring(state.material_attribute_2),
            tostring(state.material_attribute_3),
        }, ", ") .. "],",
        '  "materialInfusions": [' .. table.concat({
            tostring(state.material_infusion_1), tostring(state.material_infusion_2),
            tostring(state.material_infusion_3),
        }, ", ") .. "],",
        '  "planMode": "new",',
        '  "desiredReinforcements": [' .. reinforcement_target_json() .. "],",
        '  "desiredSetSkill": ' .. tostring(state.desired_set_skill) .. ",",
        '  "desiredGroupSkill": ' .. tostring(state.desired_group_skill) .. ",",
        '  "includeSkills": ' .. tostring(state.include_skill_predictions) .. ",",
        '  "includeReinforcements": ' .. tostring(state.include_reinforcement_predictions),
        "}",
    }
    return table.concat(lines, "\n")
end

local function existing_weapon_web_calculator_values_text(selected_weapon)
    local rng_state = state.existing_rng_state
    if rng_state == nil then
        return nil, "Export failed: calculate an existing weapon plan first."
    end
    if packed_reinforcement_tier(selected_weapon.gogma_value) ~= "gogma" then
        return nil, "Export failed: the selected weapon must be Gogma Artian."
    end
    local selected_json = existing_weapon_web_json(selected_weapon)
    if selected_json == nil then
        return nil, "Export failed: the selected weapon's skills could not be mapped."
    end
    local selected_set, selected_group = names_for_artian_skill_type(selected_weapon.skill_type)
    local selected_set_index = index_of(set_skill_names, selected_set)
    local selected_group_index = index_of(group_skill_names, selected_group)
    local weapon_json = {}
    local selected_export_index = nil
    for _, weapon in ipairs(state.existing_weapons or {}) do
        local encoded = existing_weapon_web_json(weapon)
        if encoded ~= nil then
            table.insert(weapon_json, encoded)
            if weapon.index == selected_weapon.index then
                selected_export_index = #weapon_json - 1
            end
        end
    end
    if selected_export_index == nil then
        return nil, "Export failed: the selected weapon is not in the detected weapon list."
    end
    local lines = {
        "{",
        '  "planMode": "existing",',
        '  "baseSeed": ' .. tostring(rng_state.base_seed or 0) .. ",",
        '  "skillCounter": ' .. tostring(rng_state.counter or 0) .. ",",
        '  "gogmaCounter": ' .. tostring(rng_state.gogma_counter or 0) .. ",",
        '  "counterGate": ' .. tostring(rng_state.counter_gate or 0) .. ",",
        '  "selectedExistingWeapon": ' .. tostring(selected_export_index) .. ",",
        '  "existingWeapons": [' .. table.concat(weapon_json, ",") .. "],",
        '  "weaponType": ' .. tostring(selected_weapon.weapon_type) .. ",",
        '  "existingAttribute": ' .. tostring(selected_weapon.attribute_index
            or attribute_index_for_force(selected_weapon.attribute_force)) .. ",",
        '  "attributeForce": ' .. tostring(selected_weapon.attribute_force) .. ",",
        '  "currentSetSkill": ' .. tostring(selected_set_index) .. ",",
        '  "currentGroupSkill": ' .. tostring(selected_group_index) .. ",",
        '  "currentReinforcementTier": "gogma",',
        '  "currentReinforcements": [' .. table.concat(unpack_gogma_bonus_ids(selected_weapon.gogma_value), ", ") .. "],",
        '  "desiredReinforcements": [' .. reinforcement_target_json() .. "],",
        '  "desiredSetSkill": ' .. tostring(state.desired_set_skill) .. ",",
        '  "desiredGroupSkill": ' .. tostring(state.desired_group_skill) .. ",",
        '  "includeSkills": ' .. tostring(state.include_skill_predictions) .. ",",
        '  "includeReinforcements": ' .. tostring(state.include_reinforcement_predictions),
        "}",
    }
    return table.concat(lines, "\n")
end

local function write_web_calculator_values()
    local text
    if state.plan_mode == 2 then
        if state.existing_total == nil then
            state.web_values_status = "Export failed: calculate an existing weapon plan first."
            return
        end
        local selected_weapon = state.existing_weapons
            and state.existing_weapons[state.existing_weapon_index] or nil
        if selected_weapon == nil then
            state.web_values_status = "Export failed: choose an existing weapon first."
            return
        end
        local err
        text, err = existing_weapon_web_calculator_values_text(selected_weapon)
        if text == nil then
            state.web_values_status = err
            return
        end
    else
        if state.full_plan_forges == nil then
            state.web_values_status = "Export failed: calculate a New weapon plan first."
            return
        end
        text = new_weapon_web_calculator_values_text()
    end

    local path = resolve_data_path(WEB_VALUES_PATH)
    local file, err = io.open(path, "w")
    if file == nil then
        state.web_values_status = "Web values export failed: " .. tostring(err)
        return
    end
    file:write(text, "\n")
    file:close()
    state.web_values_status = "Web values exported: GogmaWebCalculatorValues.json"
end

local function draw_quick_start()
    draw_colored_text("Quick start", 0xff73d7ff)
    imgui.text("1. Choose a plan type, then set the weapon, skills, and bonuses below.")
    imgui.text("2. Press the calculate button for that plan.")
    imgui.text("3. The calculated result stays fixed while you browse.")
end

local function draw_plan_mode_selector()
    draw_colored_text("Plan type", 0xff73d7ff)
    local modes = { "New weapon", "Existing weapon" }
    local changed
    changed, state.plan_mode = imgui.combo("Plan type", state.plan_mode, modes)
end

local function draw_target_inputs(id_suffix)
    id_suffix = id_suffix or ""
    local changed
    draw_colored_text("Desired reinforcements", 0xff73d7ff)
    draw_checkbox("Include reinforcements in plan##reinforcements" .. id_suffix,
        "include_reinforcement_predictions")
    for slot = 1, 5 do
        local key = "desired_reinforcement_" .. tostring(slot)
        changed, state[key] = imgui.combo(
            "Bonus " .. tostring(slot) .. "##" .. key .. id_suffix,
            state[key], reinforcement_names)
    end
    local mode, target_error = sync_reinforcement_target()
    if target_error ~= nil then
        draw_colored_text(target_error, 0xff8080ff)
    end
    draw_colored_text("Gogma set and group skills", 0xff73d7ff)
    draw_checkbox("Include set/group skills in plan##skills" .. id_suffix,
        "include_skill_predictions")
    changed, state.desired_set_skill = imgui.combo(
        "Set skill##set_skill" .. id_suffix, state.desired_set_skill,
        set_skill_names
    )
    changed, state.desired_group_skill = imgui.combo(
        "Group skill##group_skill" .. id_suffix, state.desired_group_skill,
        group_skill_names
    )
    return mode, target_error
end

local function draw_from_scratch_plan()
    draw_colored_text("New weapon", 0xff73d7ff)
    local changed
    imgui.text("Final weapon")
    changed, state.target_weapon_type = imgui.combo(
        "Weapon type", state.target_weapon_type, weapon_type_names
    )
    imgui.text("Final rarity-8 materials")
    local part_labels = weapon_material_parts[state.target_weapon_type]
    for slot = 1, 3 do
        local attribute_key = "material_attribute_" .. tostring(slot)
        local infusion_key = "material_infusion_" .. tostring(slot)
        changed, state[attribute_key] = imgui.combo(
            part_labels[slot] .. " element##material_attribute_" .. tostring(slot),
            state[attribute_key], attribute_names)
        changed, state[infusion_key] = imgui.combo(
            part_labels[slot] .. " bonus##material_infusion_" .. tostring(slot),
            state[infusion_key], infusion_names)
    end
    local final_attribute, has_element_infusion = derive_material_recipe()
    imgui.text("Forged attribute: " .. attribute_names[final_attribute])
    if has_element_infusion then
        imgui.text("Production bonus: Element Infusion")
    end
    draw_target_inputs("full")
    imgui.separator()
    draw_colored_text("Ready to calculate", 0xff73d7ff)
    local calculate_label = state.full_plan_running
        and "Calculating..." or "Calculate plan"
    if imgui.button(calculate_label) then
        start_full_plan_calculation()
    end
    imgui.separator()
    draw_colored_text("Calculated route", 0xff73d7ff)
    if state.full_plan_status ~= nil then
        local color = state.full_plan_forges ~= nil and 0xff80ff80 or 0xff80c0ff
        draw_colored_text(state.full_plan_status, color)
    end
    if state.full_plan_progress ~= nil then
        imgui.text(state.full_plan_progress)
    end
    if state.full_plan_forges == nil then
        return
    end

    local step = 1
    if state.full_plan_forges > 1 then
        imgui.text(tostring(step) .. ". Forge "
            .. tostring(state.full_plan_forges - 1) .. " disposable rarity-8 "
            .. weapon_type_names[state.target_weapon_type] .. " weapon(s) using any parts.")
        step = step + 1
    end
    imgui.text(tostring(step) .. ". Forge the target "
        .. attribute_names[state.target_attribute] .. " "
        .. weapon_type_names[state.target_weapon_type] .. " with the selected materials.")
    step = step + 1
    if state.include_skill_predictions or state.include_gogma_predictions then
        imgui.text(tostring(step) .. ". Reinforce it to 5/5, then upgrade it to Gogma Artian.")
        step = step + 1
    else
        imgui.text(tostring(step) .. ". Reinforce it to 5/5. The base Artian weapon is complete.")
        step = step + 1
    end
    imgui.text("   Base result: "
        .. format_base_reinforcements(state.full_plan_base_value))

    if state.include_skill_predictions then
        if state.full_plan_skills_pending then
            draw_colored_text(tostring(step)
                .. ". Upgrade it; the mod will then read its initial skills and finish this route.",
                0xff80c0ff)
        else
            local initial_set, initial_group = names_for_artian_skill_type(
                state.full_plan_initial_skill_type)
            imgui.text(tostring(step) .. ". Upgrade assigned initial skills: "
                .. tostring(initial_set) .. " / " .. tostring(initial_group) .. ".")
            if (state.full_plan_skill_resets or 0) > 0 then
                imgui.text("   Reset Skills " .. tostring(state.full_plan_skill_resets)
                    .. " time(s).")
            else
                imgui.text("   The upgrade skills already match the target.")
            end
        end
        step = step + 1
    end
    if state.include_gogma_predictions then
        if (state.full_plan_gogma_resets or 0) > 0 then
            imgui.text(tostring(step) .. "a. Amend (Reset Bonuses) "
                .. tostring(state.full_plan_gogma_resets) .. " time(s).")
        end
        if (state.full_plan_gogma_keeps or 0) > 0 then
            imgui.text(tostring(step) .. "b. Amend (Keep Bonuses) "
                .. tostring(state.full_plan_gogma_keeps) .. " time(s).")
        end
        if (state.full_plan_gogma_resets or 0) == 0
            and (state.full_plan_gogma_keeps or 0) == 0 then
            imgui.text(tostring(step) .. ". Gogma reinforcements already match the target.")
        end
        imgui.text("   Gogma result: "
            .. format_gogma_reinforcements(state.full_plan_gogma_value))
    end
    if state.full_plan_skills_pending then
        imgui.text("Known planned RNG actions (skill resets pending): "
            .. tostring(state.full_plan_total))
    else
        imgui.text("Planned RNG actions: " .. tostring(state.full_plan_total))
    end

    local costs = full_plan_costs()
    if costs ~= nil then
        imgui.separator()
        draw_colored_text("Estimated material cost", 0xff73d7ff)
        local total_line = "Total: " .. format_number(costs.forge_parts)
            .. " Artian parts + "
            .. format_number((costs.base_points + costs.amend_points) / COSTS.oricalcite_points)
            .. " Oricalcite (" .. format_number(costs.base_points + costs.amend_points) .. " material points) + "
            .. format_number(costs.upgrade_devices) .. " Tarred Devices + "
            .. format_number(costs.total_zenny) .. "z"
        if state.full_plan_skills_pending then
            total_line = total_line .. " (skill-reset cost pending)"
        end
        imgui.text(total_line)
    end
end

local function draw_existing_weapon_plan()
    draw_colored_text("Existing weapon", 0xff73d7ff)
    imgui.text("Choose a Gogma weapon from the loaded character's equipment box.")
    imgui.text("Only Gogma weapons are displayed; base Artian weapons are not included.")
    imgui.text("After an amendment, confirm or cancel the smithy preview before calculating again.")

    if imgui.button("Refresh existing weapons") then
        refresh_existing_weapon_list()
    end
    if state.existing_weapons == nil then
        refresh_existing_weapon_list()
    end
    if state.existing_weapon_status ~= nil then
        imgui.text(state.existing_weapon_status)
    end

    local weapon_labels = {}
    for _, weapon in ipairs(state.existing_weapons or {}) do
        table.insert(weapon_labels, weapon.label)
    end
    if #weapon_labels == 0 then
        imgui.text("No Gogma weapons were detected.")
        return
    end
    local changed
    changed, state.existing_weapon_index = imgui.combo(
        "Existing weapon", state.existing_weapon_index, weapon_labels
    )
    local selected_weapon = state.existing_weapons[state.existing_weapon_index]
    if selected_weapon ~= nil then
        local set_name, group_name = names_for_artian_skill_type(selected_weapon.skill_type)
        imgui.text("Current skills: " .. tostring(set_name)
            .. " / " .. tostring(group_name))
        imgui.text("Current reinforcements: "
            .. format_existing_reinforcements(selected_weapon.gogma_value))
    end

    draw_target_inputs("existing")
    imgui.separator()
    draw_colored_text("Ready to calculate", 0xff73d7ff)
    if imgui.button("Calculate plan") then
        local ok, err = pcall(calculate_existing_weapon_route)
        if not ok then
            state.existing_route_status = "Calculation failed: " .. tostring(err)
        end
    end
    if state.existing_route_status ~= nil then
        local is_error = state.existing_route_status:find("failed", 1, true) ~= nil
            or state.existing_route_status:find("not found", 1, true) ~= nil
            or state.existing_route_status:find("require", 1, true) ~= nil
            or state.existing_route_status:find("needs", 1, true) ~= nil
        if is_error then
            draw_colored_text(state.existing_route_status, 0xff8080ff)
        else
            imgui.text(state.existing_route_status)
        end
    end
    if state.existing_total == nil then
        return
    end

    if state.include_skill_predictions then
        if (state.existing_skill_resets or 0) > 0 then
            imgui.text("Reset Skills " .. tostring(state.existing_skill_resets)
                .. " time(s).")
        else
            imgui.text("Current skills already match the target.")
        end
    end
    if state.include_reinforcement_predictions then
        if (state.existing_gogma_resets or 0) > 0 then
            imgui.text("Amend (Reset Bonuses) "
                .. tostring(state.existing_gogma_resets) .. " time(s).")
        end
        if (state.existing_gogma_keeps or 0) > 0 then
            imgui.text("Amend (Keep Bonuses) "
                .. tostring(state.existing_gogma_keeps) .. " time(s).")
        end
        if (state.existing_gogma_resets or 0) == 0
            and (state.existing_gogma_keeps or 0) == 0 then
            imgui.text("Current reinforcements already match the target.")
        end
        if state.existing_gogma_value ~= nil then
            imgui.text("Gogma result: "
                .. format_gogma_reinforcements(state.existing_gogma_value))
        end
    end
    imgui.text("Planned RNG actions: " .. tostring(state.existing_total))
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
    local distance = state.full_plan_forges
    if distance == nil or state.creation_base_seed == nil
        or state.artian_create_weapon_type == nil or state.artian_create_rarity == nil
        or state.artian_create_count_after == nil then
        return overall_step
    end
    local seed = u32(state.creation_base_seed + state.artian_create_weapon_type * 1000
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
            0, COSTS.rarity8_forge_zenny, 0,
            COSTS.rarity8_parts_per_forge, 0,
        })
        for _ = 1, 5 do
            x, y, z, w = rng_step(x, y, z, w)
        end
    end
    return overall_step
end

local function append_skill_prediction_rows(rows, overall_step, distance, capture)
    distance = distance or state.full_plan_skill_resets
    capture = capture or state.full_plan_skill_capture
    if distance == nil or distance <= 0 or capture == nil
        or capture.weapon_type == nil or capture.attribute_force == nil
        or capture.base_seed == nil or capture.counter == nil then
        return overall_step
    end
    local seed = u32(capture.weapon_type * 1000 + capture.attribute_force
        + capture.base_seed) ~ 0x00ac9365
    local x, y, z, w = initialize_rng(seed)
    local counter_steps = capture.counter_gate ~= nil and capture.counter_gate < 0x36
        and 0 or capture.counter * 10
    for _ = 1, counter_steps do
        x, y, z, w = rng_step(x, y, z, w)
    end
    x, y, z, w = rng_step(x, y, z, w)
    local target = set_skill_names[state.desired_set_skill] .. " / "
        .. group_skill_names[state.desired_group_skill]
    for step = 1, distance do
        if not (capture.counter_is_next and step == 1) then
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
            0, COSTS.skill_reset_zenny, COSTS.skill_reset_points, 0, 0,
        })
    end
    return overall_step
end

local function append_gogma_prediction_rows(rows, overall_step, start_value,
        capture, resets, keeps)
    resets = resets or state.full_plan_gogma_resets or 0
    keeps = keeps or state.full_plan_gogma_keeps or 0
    local distance = resets + keeps
    start_value = start_value or state.full_plan_base_value
    capture = capture or state.full_plan_gogma_capture
    if distance <= 0 or start_value == nil or capture == nil then
        return overall_step
    end
    local rng = initialize_gogma_rng(capture)
    if rng == nil then
        return overall_step
    end
    local packed = start_value
    local target = selected_gogma_target_text()
    for step = 1, distance do
        local mode = step <= resets and 0 or 1
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
            0, COSTS.gogma_amend_zenny, COSTS.gogma_amend_points, 0, 0,
        })
        for _ = 1, 10 do
            rng.x, rng.y, rng.z, rng.w = rng_step(rng.x, rng.y, rng.z, rng.w)
        end
    end
    return overall_step
end

local function export_prediction_rows()
    local _, target_error = sync_reinforcement_target()
    if target_error ~= nil then
        state.export_status = "Export failed: " .. target_error
        return
    end
    if state.full_plan_forges == nil then
        state.export_status = "Export failed: calculate a full plan first."
        return
    end

    local rows = {
        { "Row", "Stage step", "Stage", "Action", "Predicted result", "Target",
            "Base reinforcement points", "Zenny", "Gogma material points",
            "Rarity-8 Artian parts", "Tarred Devices" },
    }
    local overall_step = 0
    if state.include_base_predictions then
        overall_step = append_base_prediction_rows(rows, overall_step)
    end
    if state.include_skill_predictions then
        overall_step = append_skill_prediction_rows(rows, overall_step)
    end
    if state.include_gogma_predictions then
        overall_step = append_gogma_prediction_rows(rows, overall_step)
    end

    local costs = full_plan_costs()
    if costs ~= nil then
        overall_step = overall_step + 1
        table.insert(rows, {
            overall_step, "", "New weapon", "Estimated totals",
            state.full_plan_skills_pending and "Skill reset cost pending"
                or "Complete known costs",
            "", costs.base_points, costs.total_zenny,
            costs.skill_points + costs.amend_points, costs.forge_parts,
            costs.upgrade_devices,
        })
    end

    local path = resolve_data_path(EXPORT_PATH)
    local file, err = io.open(path, "w")
    if file == nil then
        state.export_status = "Export failed: " .. tostring(err)
        return
    end
    for _, row in ipairs(rows) do
        local cells = {}
        for column = 1, 11 do
            table.insert(cells, csv_cell(row[column]))
        end
        file:write(table.concat(cells, ","), "\n")
    end
    file:close()
    state.export_status = "Exported " .. tostring(#rows - 1)
        .. " steps: GogRollPlannerPredictions.csv"
end

local function export_existing_prediction_rows()
    local _, target_error = sync_reinforcement_target()
    if target_error ~= nil then
        state.export_status = "Export failed: " .. target_error
        return
    end
    if state.existing_total == nil then
        state.export_status = "Export failed: calculate an existing weapon first."
        return
    end
    local selected_weapon = state.existing_weapons ~= nil
        and state.existing_weapons[state.existing_weapon_index] or nil
    if selected_weapon == nil then
        state.export_status = "Export failed: choose an existing weapon first."
        return
    end

    local set_name, group_name = names_for_artian_skill_type(selected_weapon.skill_type)
    local rows = {
        { "Row", "Stage step", "Stage", "Action", "Predicted result", "Target",
            "Base reinforcement points", "Zenny", "Gogma material points",
            "Rarity-8 Artian parts", "Tarred Devices" },
        { 1, "", "Existing weapon", "Starting state",
            tostring(weapon_type_names[selected_weapon.weapon_type + 1] or "Weapon")
                .. " / " .. tostring(attribute_names[selected_weapon.attribute_index]
                    or attribute_name_for_force(selected_weapon.attribute_force))
                .. " / " .. tostring(set_name) .. " / " .. tostring(group_name)
                .. " / " .. format_existing_reinforcements(selected_weapon.gogma_value),
            "", 0, 0, 0, 0, 0 },
    }
    local overall_step = 1
    if state.include_skill_predictions then
        overall_step = append_skill_prediction_rows(rows, overall_step,
            state.existing_skill_resets, state.existing_skill_capture)
    end
    if state.include_reinforcement_predictions then
        overall_step = append_gogma_prediction_rows(rows, overall_step,
            state.existing_start_gogma_value, state.existing_gogma_capture,
            state.existing_gogma_resets, state.existing_gogma_keeps)
    end
    overall_step = overall_step + 1
    table.insert(rows, {
        overall_step, "", "Existing weapon", "Estimated totals",
        "Complete known costs", "", 0,
        (state.existing_skill_resets or 0) * COSTS.skill_reset_zenny
            + ((state.existing_gogma_resets or 0)
                + (state.existing_gogma_keeps or 0)) * COSTS.gogma_amend_zenny,
        (state.existing_skill_resets or 0) * COSTS.skill_reset_points
            + ((state.existing_gogma_resets or 0)
                + (state.existing_gogma_keeps or 0)) * COSTS.gogma_amend_points,
        0, 0,
    })

    local path = resolve_data_path(EXPORT_PATH)
    local file, err = io.open(path, "w")
    if file == nil then
        state.export_status = "Export failed: " .. tostring(err)
        return
    end
    for _, row in ipairs(rows) do
        local cells = {}
        for column = 1, 11 do
            table.insert(cells, csv_cell(row[column]))
        end
        file:write(table.concat(cells, ","), "\n")
    end
    file:close()
    state.export_status = "Exported " .. tostring(#rows - 1)
        .. " steps: GogRollPlannerPredictions.csv"
end

local function export_active_prediction_rows()
    if state.plan_mode == 2 then
        export_existing_prediction_rows()
    else
        export_prediction_rows()
    end
end

local function draw_export()
    imgui.separator()
    imgui.text("Export")
    if imgui.button("Export active plan to CSV") then
        local ok, err = pcall(export_active_prediction_rows)
        if not ok then
            state.export_status = "Export failed: " .. tostring(err)
        end
    end
    if state.export_status ~= nil then
        draw_export_status(state.export_status)
    end
    if imgui.button("Export web calculator values") then
        write_web_calculator_values()
    end
    if state.web_values_status ~= nil then
        draw_export_status(state.web_values_status)
    end
    imgui.text("")
    imgui.text("")
end

re.on_config_save(save_config)

re.on_frame(function()
    if state.enabled then
        resume_full_plan_calculation()
    end
end)

re.on_draw_ui(function()
    if not imgui.tree_node(MOD_NAME) then
        return
    end
    local ok, err = pcall(function()
        imgui.text("Version " .. VERSION)
        imgui.separator()
        draw_checkbox("Enable", "enabled")
        imgui.separator()
        draw_quick_start()
        imgui.separator()
        draw_plan_mode_selector()
        imgui.separator()
        if state.plan_mode == 2 then
            draw_existing_weapon_plan()
        else
            draw_from_scratch_plan()
        end
        draw_export()
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
