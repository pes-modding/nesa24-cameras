--[[
=========================
ReplayCam game research by: nesa24
Requires: sider.dll 6.2.3+
module written by: juce
=========================
--]]

local m = { version = "1.0" }
local hex = memory.hex
local helper

local overlay_states = {
    { ui = "ReplayCam Height (cam0): %0.2f", prop = "replay_height_0", decr = -0.1, incr = 0.1 },
    { ui = "ReplayCam Height (cam3): %0.2f", prop = "replay_height_3", decr = -0.1, incr = 0.1 },
    { ui = "ReplayCam Zoom: %0.2f", prop = "replay_zoom", decr = -0.01, incr = 0.01 },
}

local game_info = {
    replay_height_0 = { base = "rheight0", offs = 0x00, format = "f", len = 4, def = 0.4, save_as = "%0.2f" },
    replay_height_3 = { base = "rheight3", offs = 0x00, format = "f", len = 4, def = 1.3, save_as = "%0.2f" },
    replay_zoom = { base = "rzoom", offs = 0x00, format = "f", len = 4, def = 0.66, save_as = "%0.2f" },
}

function m.init(ctx)
    if not ctx.nesalib then
        error("nesalib not found. Install nesalib")
    end

    helper = ctx.nesalib.helper(m.version, "modules\\ReplayCam.ini", overlay_states, game_info)
    helper.load_ini(ctx)
    helper.set_ini_comment("Replay Camera Settings")

    local loc
    local cache = ctx.nesalib.cache(ctx, _FILE)

    -- Height 1 (for camid=0)
    -- 0000000156E51E1C | C7 45 AB CD CC CC 3E               | mov dword ptr ss:[rbp-55],3ECCCCCD     |
    -- 0000000156E51E23 | F3 41 0F 58 C0                     | addss xmm0,xmm8                        |
    -- 0000000156E51E28 | F3 0F 11 45 A7                     | movss dword ptr ss:[rbp-59],xmm0       |
    -- 0000000156E51E2D | 0F 28 C6                           | movaps xmm0,xmm6                       |
    loc = cache.find_pattern(
        "\xc7\x45\xab\xcd\xcc\xcc\x3e" ..
        "\xf3\x41\x0f\x58\xc0" ..
        "\xf3\x0f\x11\x45\xa7" ..
        "\x0f\x28\xc6", 1)
    if loc then
        local addr = loc + 3
        log(string.format("replay camera height (cam0) addr: %s", hex(addr)))
        helper.set_base("rheight0", addr)
    else
        error("unable to find replay camera height (cam0) addr")
    end

    -- Height 2 (for camid=3)
    -- 0000000156E54337 | F3 0F 58 E0                        | addss xmm4,xmm0                        |
    -- 0000000156E5433B | F3 0F 11 46 14                     | movss dword ptr ds:[rsi+14],xmm0       |
    -- 0000000156E54340 | C7 46 10 66 66 A6 3F               | mov dword ptr ds:[rsi+10],3FA66666     |
    loc = cache.find_pattern(
        "\xf3\x0f\x58\xe0" ..
        "\xf3\x0f\x11\x46\x14" ..
        "\xc7\x46\x10\x66\x66\xa6\x3f", 2)
    if loc then
        local addr = loc + 12
        log(string.format("replay camera height (cam3) addr: %s", hex(addr)))
        helper.set_base("rheight3", addr)
    else
        error("unable to find replay camera height (cam3) addr")
    end

    -- Zoom
    -- 0000000156E51CD1 | C7 46 30 C3 F5 28 3F               | mov dword ptr ds:[rsi+30],3F28F5C3     | write replay zoom
    -- 0000000156E51CD8 | F3 44 0F 10 06                     | movss xmm8,dword ptr ds:[rsi]          |
    -- 0000000156E51CDD | F3 44 0F 10 4E 08                  | movss xmm9,dword ptr ds:[rsi+8]        |
    -- 0000000156E51CE3 | F3 44 0F 11 45 C7                  | movss dword ptr ss:[rbp-39],xmm8       |
    loc = cache.find_pattern(
        "\xc7\x46\x30\xc3\xf5\x28\x3f" ..
        "\xf3\x44\x0f\x10\x06" ..
        "\xf3\x44\x0f\x10\x4e\x08" ..
        "\xf3\x44\x0f\x11\x45\xc7", 3)
    if loc then
        local addr = loc + 3
        log(string.format("replay camera zoom addr: %s", hex(addr)))
        helper.set_base("rzoom", addr)
    else
        error("unable to find replay camera zoom addr")
    end

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
