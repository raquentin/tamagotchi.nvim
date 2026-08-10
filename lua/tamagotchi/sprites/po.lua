-- Po. Rows: face / body / arms / feet. Uses narrow multibyte glyphs, which is
-- why the layout has to measure in display cells rather than bytes.
local po_sprites = {
    happy = {
        [[
 ʕ•ᴥ•ʔ
( O O )
 \   /
 d   b
]],
        [[
 ʕ^ᴥ^ʔ
( o o )
 \ ♥ /
 d   b
]],
        [[
 ʕ*ᴥ*ʔ
( O O )
 \   /
 b   d
]],
        [[
 ʕ>ᴥ<ʔ
( o o )
 \ ~ /
 d   b
]],
    },

    hungry = {
        [[
 ʕ-ᴥ-ʔ
( O O )
 \   /
 d   b
]],
        [[
 ʕ;ᴥ;ʔ
( o o )
 \ ~ /
 d   b
]],
        [[
 ʕTᴥTʔ
( O O )
 \___/
 b   d
]],
        [[
 ʕoᴥoʔ
( o o )
 \ ? /
 d   b
]],
    },

    neutral = {
        [[
 ʕ-ᴥ-ʔ
( O O )
 \   /
 d   b
]],
        [[
 ʕ·ᴥ·ʔ
( o o )
 \   /
 d   b
]],
        [[
 ʕuᴥuʔ
( O O )
 \___/
 b   d
]],
        [[
 ʕ•ᴥ•ʔ
( o o )
 \ - /
 d   b
]],
    },
}

return po_sprites
