-- Lucy, the star mascot of the Gleam programming language.
--
-- Every frame moves the face and at least one point, so an idle Lucy shimmers
-- rather than sitting frozen. ASCII on purpose: this is the widest sprite in
-- the plugin, and its outline would carry five multibyte glyphs per frame.
local lucy_sprites = {
    happy = {
        [[
    /\
 __/  \__
 \  ^ ^  /
  \  v  /
  /_\ /_\
]],
        [[
.   /\    .
 __/  \__
 \  o o  /
  \  w  /
  /_\ /_\
]],
        [[
    /\
 __/  \__
 \  ^ ^  /
  \  o  /
  /_\ /_\
]],
        [[
*   /\    *
 __/  \__
 \  - -  /
  \  w  /
  /_\ /_\
]],
        [[
    /\
 __/  \__
 \  o o  /
  \  v  /
  /_\ /_\
]],
    },

    -- The tip droops and the arms sag; a hungry star has nothing left to
    -- twinkle with.
    hungry = {
        [[
    /\
 __/  \__
 \  - -  /
  \  n  /
  /_\ /_\
]],
        [[
    \/
 __/  \__
 \  o o  /
  \  n  /
  /_\ /_\
]],
        [[
    \/
 _./  \._
 \  ; ;  /
  \  n  /
  /_. ._\
]],
        [[
    /\
 _./  \._
 \  ; ;  /
  \  o  /
  /_. ._\
]],
    },

    neutral = {
        [[
    /\
 __/  \__
 \  - -  /
  \  .  /
  /_\ /_\
]],
        [[
.   /\
 __/  \__
 \  o o  /
  \  .  /
  /_\ /_\
]],
        [[
    /\
 __/  \__
 \  - -  /
  \  v  /
  /_\ /_\
]],
        [[
    /\    .
 __/  \__
 \  u u  /
  \  .  /
  /_\ /_\
]],
    },
}

return lucy_sprites
