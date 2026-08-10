-- Rows: ears / face / paws. Every frame moves at least two of the three, so the
-- cat reads as alive rather than as a blinking mask on a frozen body.
local kitty_sprites = {
    happy = {
        [[
 /\_/\
( ^.^ )
 >   <
]],
        [[
 /\_/\
( ^w^ )
 > ^ <
]],
        [[
 -\_/\
( ^o^ )
 >   <
]],
        [[
 /\_/-
( ^w^ )
 < ^ >
]],
    },

    hungry = {
        [[
 -\_/-
( ;_; )
 > n <
]],
        [[
 /\_/\
( o_o )
 >   <
]],
        [[
 -\_/-
( T_T )
 > n <
]],
        [[
 /\_/\
( ._. )
 >   <
]],
    },

    neutral = {
        [[
 /\_/\
( -.- )
 >   <
]],
        [[
 /\_/\
( o.o )
 > ^ <
]],
        [[
 -\_/\
( -.- )
 >   <
]],
        [[
 /\_/\
( u_u )
 > ^ <
]],
    },
}

return kitty_sprites
