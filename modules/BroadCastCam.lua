--[[
=========================
BroadCastCam module and Game research by: nesa24
Requires: sider.dll 6.2.3+
updated to use nesalib by juce
=========================
--]]

local m = { version = "2.0" }
local hex = memory.hex

local overlay_states = {
    { ui = "Broadcast Height: %0.2f", prop = "broad_height", decr = -0.01, incr = 0.01 },
    { ui = "Broadcast Zoom: %0.2f", prop = "broad_zoom", decr = -0.25, incr = 0.25 },
    { ui = "Broadcast Angle: %0.2f", prop = "broad_angle", decr = -0.50, incr = 0.50 },
	{ ui = "Broadcast Pitch: %0.2f", prop = "broad_pitch", decr = -0.05, incr = 0.05 },
}

local game_info = {
    broad_zoom = { base = "bzoom_pitch", offs = 0x04, format = "f", len = 4, def = 14.41, save_as = "%0.2f" },
	broad_pitch  = { base = "bzoom_pitch", offs = 0x0c, format = "f", len = 4, def = 0.5, save_as = "%0.2f" },
    broad_angle  = { base = "bheight_angle", offs = 0x0a, format = "f", len = 4, def = 70, save_as = "%0.2f" },
    broad_height   = { base = "bheight_angle", offs = 0x03, format = "f", len = 4, def = 0.3, save_as = "%0.2f" },
}

function m.init(ctx)
    if not ctx.nesalib then
        error("nesalib not found. Install nesalib")
    end

    helper = ctx.nesalib.helper(m.version, "modules\\BroadCastCam.ini", overlay_states, game_info)
    helper.load_ini(ctx)
    helper.set_ini_comment("Broadcast Camera Settings")

    local loc, offset, addr
    local cache = ctx.nesalib.cache(ctx, _FILE)

    -- BroadCast camera zoom/pitch base
    -- 000000014712ABF2 | 48 31 E0                           | xor rax,rsp                            |
    -- 000000014712ABF5 | 48 89 45 27                        | mov qword ptr ss:[rbp+27],rax          |
    -- 000000014712ABF9 | 48 63 41 78                        | movsxd rax,dword ptr ds:[rcx+78]       |
    -- 000000014712ABFD | 4C 8D 05 DC A4 2E FC               | lea r8,qword ptr ds:[1434150E0]        |
    loc = cache.find_pattern(
        "\x48\x31\xe0" ..
        "\x48\x89\x45\x27" ..
        "\x48\x63\x41\x78" ..
        "\x4c\x8d\x05", 1)
    if loc then
        offset = memory.unpack("i32", memory.read(loc + 14))
        addr = loc + 18 + offset
        log(string.format("broadcast camera zoom/pitch base addr: %s", hex(addr)))
        helper.set_base("bzoom_pitch", addr)
    else
        error("unable to find broadcast camera zoom/pitch base addr")
    end

    -- Height/Pitch are set nearby:
    addr = loc + (0xac39 - 0xabf2)
    log(string.format("broadcast camera height/angle base addr: %s", hex(addr)))
    helper.set_base("bheight_angle", addr)

    local start_from = loc

    -- find NOP location further down
    -- 000000014712AEFC | F3 0F 11 45 D7                     | movss dword ptr ss:[rbp-29],xmm0       |
    -- 000000014712AF01 | 4C 8D 45 C7                        | lea r8,qword ptr ss:[rbp-39]           |
    loc = cache.find_pattern(
        "\xf3\x0f\x11\x45\xd7" ..
        "\x4c\x8d\x45\xc7", 2, start_from)
    if loc then
        log(string.format("broadcast camera NOP addr: %s", hex(loc)))
        helper.set_base("bnop", loc)
    else
        error("unable to find broadcast camera NOP addr")
    end

    -- save locations cache
    cache.save()

    -- write NOPs: to remove angle lock
    memory.write(helper.get_base("bnop"), "\x90\x90\x90\x90\x90")

    -- apply our values
    helper.apply_settings(ctx, true)

    -- register for events
    ctx.register("overlay_on", helper.overlay_on)
    ctx.register("key_down", helper.key_down)
    ctx.register("gamepad_input", helper.gamepad_input)
end

return m
