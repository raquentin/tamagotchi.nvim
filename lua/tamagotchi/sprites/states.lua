-- Fallback frames for the `sick` and `dead` states.
--
-- A sprite set may define its own `sick`/`dead` lists; when it does not -- which
-- is true of every user-authored set, and of most of the built-in ones -- these
-- stand in, so enabling `stakes` never leaves a pet with an empty sprite.
return {
    sick = {
        [[
 ~ ~ ~
( x_x )
 (   )
]],
        [[
 ~ ~ ~
( -_- )
 ( ~ )
]],
        [[
 ~ ~ ~
( o_o )
 (   )
]],
        [[
 ~ ~ ~
( ;_; )
 ( ~ )
]],
    },

    dead = {
        [[
  _____
 /     \
| R.I.P |
|_______|
]],
    },
}
