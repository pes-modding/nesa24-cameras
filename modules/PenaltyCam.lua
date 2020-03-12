--[[
Penalty camera zoom/height/angle changer.
research and initial version: nesa24, Chuny, digitalfoxx
modified to use nesalib by juce
--]]

local m = { version = "3.1" }
local helper
 
local overlay_states = {
    { ui = "Penalty Height: %0.2f", prop = "Penalty_height", decr = -0.2, incr = 0.2 },
    { ui = "Penalty Zoom: %0.2f", prop = "Penalty_zoom", decr = -0.3, incr = 0.3 },
    { ui = "Penalty Angle: %0.2f", prop = "Penalty_angle", decr = -0.5, incr = 0.5 },
}

local game_info = {
    Penalty_zoom = { base = "pzoom", offs = 0x00, format = "f", len = 4, def = 17.60000038, save_as = "%0.2f" },
    Penalty_height = { base = "pheight", offs = 0x00, format = "f", len = 4, def = 3, save_as = "%0.2f" },
    Penalty_angle = { base = "pangle", offs = 0x00, format = "f", len = 4, def = 0, save_as = "%0.2f" },
}
 
function m.init(ctx)
    if not ctx.nesalib then
        error("PROBLEM: nesalib not found. Install nesalib")
    end

    helper = ctx.nesalib.helper(m.version, "modules\\PenaltyCam.ini", overlay_states, game_info)
    helper.load_ini(ctx)
    helper.set_ini_comment("Penalty Camera settings")
        
    local cache = ctx.nesalib.cache(ctx, _FILE)

    -- 0000000146D634B3 | F3 0F 10 8B 88 08 00 00            | movss xmm1,dword ptr ds:[rbx+888]      |
    -- 0000000146D634BB | F3 0F 59 35 19 53 82 FB            | mulss xmm6,dword ptr ds:[1425887DC]    | 
    local loc = cache.find_pattern("\xf3\x0f\x10\x8b\x88\x08\x00\x00\xf3\x0f\x59\x35", 1)
    if loc then
        local rel_offset = memory.unpack("i32", memory.read(loc + 12, 4))
        helper.set_base("pzoom", loc + 16 + rel_offset)
        log(string.format("penalty camera zoom address: %s", memory.hex(helper.get_base("pzoom"))))
    else
        error("problem: unable to find code pattern for penalty camera zoom")
    end

    -- 0000000146D65042 | 48 8D 4E 08                        | lea rcx,qword ptr ds:[rsi+8]           | rcx:"p=&B"
    -- 0000000146D65046 | 48 89 9C 24 00 01 00 00            | mov qword ptr ss:[rsp+100],rbx         |
    -- 0000000146D6504E | F3 44 0F 58 35 8D 11 7C FB         | addss xmm14,dword ptr ds:[1425261E4]   | 
    local loc = cache.find_pattern("\x48\x8d\x4e\x08\x48\x89\x9c\x24\x00\x01\x00\x00\xf3\x44\x0f\x58\x35", 2)
    if loc then
        local rel_offset = memory.unpack("i32", memory.read(loc + 17, 4))
        -- need to "cave" the value, meaning: change offset to another location in memory
        -- then put the value in there.
        rel_offset = rel_offset + 0x18  -- there is a free/unused 4-bytes
        memory.write(loc + 17, memory.pack("i32", rel_offset))
        helper.set_base("pheight", loc + 21 + rel_offset)
        log(string.format("penalty camera height address: %s", memory.hex(helper.get_base("pheight"))))
    else
        error("problem: unable to find code pattern for penalty camera height")
    end

    -- Angle
    -- 0000000147282B75 | 8B 86 84 08 00 00                  | mov eax,dword ptr ds:[rsi+884]         |
    -- 0000000147282B7B | 41 89 44 24 0C                     | mov dword ptr ds:[r12+C],eax           |
    -- 0000000147282B80 | 8B 86 88 08 00 00                  | mov eax,dword ptr ds:[rsi+888]         |
    -- 0000000147282B86 | 41 89 44 24 10                     | mov dword ptr ds:[r12+10],eax          |
    loc = cache.find_pattern(
        "\x8b\x86\x84\x08\x00\x00" ..
        "\x41\x89\x44\x24\x0c" ..
        "\x8b\x86\x88\x08\x00\x00" ..
        "\x41\x89\x44\x24\x10", 3)
    if loc then
        -- Patch to set angle
        -- 0000000147282B8B | 41 C7 44 24 14 00 00 00 00         | mov dword ptr ds:[r12+14],00000000     |
        -- 0000000147282B94 | 90                                 | nop                                    |
        -- 0000000147282B95 | 90                                 | nop                                    |
        local patch = "\x41\xc7\x44\x24\x14\x00\x00\x00\x00\x90\x90";
        memory.write(loc + 22, patch)
        helper.set_base("pangle", loc + 22 + 5)
    else
        error("problem: unable to find code pattern for penalty camera angle")
    end

    -- save found locations to disk
    cache.save()

    -- set our new values
    helper.apply_settings(ctx, true)
 
    -- register for events
    ctx.register("overlay_on", helper.overlay_on)
    ctx.register("key_down", helper.key_down)
    ctx.register("gamepad_input", helper.gamepad_input)
end
 
return m
