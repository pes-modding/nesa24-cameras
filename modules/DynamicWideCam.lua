--[[
=========================
DynamicWideCam module and Game research by: nesa24
Requires: sider.dll 6.2.3+
modified to use nesalib by juce
=========================
--]]

local m = { version = "2.0" }
local hex = memory.hex
local helper

local overlay_states = {
    { ui = "DynWide Zoom: %0.3f", prop = "zoom", decr = -0.5, incr = 0.5 },
    { ui = "DynWide Height: %0.3f", prop = "height", decr = -0.01, incr = 0.01 },
    { ui = "DynWide Angle: %0.3f", prop = "angle", decr = -0.1, incr = 0.1 },
}

local game_info = {
    zoom = { base = "dynwide_zoom", offs = 0, format = "f", len = 4, def = 28.698, save_as = "%0.4f" },
    height = { base = "dynwide_height", offs = 0, format = "f", len = 4, def = 0.3798, save_as = "%0.4f" },
    angle  = { base = "dynwide_angle", offs = 0, format = "f", len = 4, def = 0.2, save_as = "%0.4f" },
}

function m.init(ctx)
    if not ctx.nesalib then
        error("nesalib not found. Install nesalib")
    end

    helper = ctx.nesalib.helper(m.version, "modules\\DynamicWideCam.ini", overlay_states, game_info)
    helper.load_ini(ctx)
    helper.set_ini_comment("Dynamic Wide Camera Settings")

    local loc
    local cache = ctx.nesalib.cache(ctx, _FILE)

    local rel_offset, addr

    -- Find angle reading instruction for Dynamic Wide camera.
    -- this code pattern immediately follows the instruction we need:
    -- 000000014AD14892 | F3 41 0F 59 FA                     | mulss xmm7,xmm10                       |
    -- 000000014AD14897 | F3 45 0F 5E C2                     | divss xmm8,xmm10                       |
    -- 000000014AD1489C | F3 41 0F 5E F2                     | divss xmm6,xmm10                       |
    -- 000000014AD148A1 | F3 41 0F 5C C0                     | subss xmm0,xmm8                        |
    local loc = cache.find_pattern("\xf3\x41\x0f\x59\xfa\xf3\x45\x0f\x5e\xc2\xf3\x41\x0f\x5e\xf2\xf3\x41\x0f\x5c\xc0", 1)
    if loc then
        rel_offset = memory.unpack("i32", memory.read(loc - 4, 4))
        log(string.format("Dynamic Wide angle read at: %s", hex(loc - 9)))
        log(string.format("Dynamic Wide org angle address: %s", hex(loc + rel_offset)))
        -- codecave concept: modify instruction, change relative offset.
        -- We need to make the game to read a value from a different location,
        -- so that we can safely modify the value.
        rel_offset = rel_offset + 0x2c -- there's an unused memory slot there
        addr = loc + rel_offset
        memory.write(loc - 4, memory.pack("i32", rel_offset))
        helper.set_base("dynwide_angle", addr)
        log(string.format("Dynamic Wide new angle address: %s", hex(addr)))
    else
        error("problem: unable to find code pattern for dynamic wide camera angle read")
    end

    -- Instruction to read zoom is immediately before angle read
    rel_offset = memory.unpack("i32", memory.read(loc - 13, 4))
    addr = loc - 9 + rel_offset
    log(string.format("Dynamic Wide zoom address: %s", hex(addr)))
    helper.set_base("dynwide_zoom", addr)

    -- Instruction to read height is immediately after the code sequence we searched for
    rel_offset = memory.unpack("i32", memory.read(loc + 24, 4))
    addr = loc + 28 + rel_offset
    log(string.format("Dynamic Wide height address: %s", hex(addr)))
    helper.set_base("dynwide_height", addr)

    -- save locations cache
    cache.save()

    -- apply our values
    helper.apply_settings(ctx, true)

    -- register for events
    ctx.register("overlay_on", helper.overlay_on)
    ctx.register("key_down", helper.key_down)
    ctx.register("gamepad_input", helper.gamepad_input)
end

return m
