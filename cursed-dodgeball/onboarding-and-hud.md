# Onboarding and HUD (v0.3)

Wireframes: `hud-wireframe.svg` (in-round, phone landscape) and `hud-pick-panel.svg` (intermission).

## The first minute for a new player

The owner's rule: one loading sentence, funny and over the top, then one how-to-play screen before their first match. Nothing else, ever again.

**Loading sentence.** Three candidates; pick one or write your own:
1. "Twenty kids. Eight haunted balls. One crown. Everybody else goes home crying."
2. "It's dodgeball. The balls are cursed. Your friends are worse."
3. "Get hit, you're out. Catch it, they're out. Everything else is the ball lying to you."

**How-to-play screen.** Shown once, during the new player's first intermission, the moment they land in the stands. One screen, four panels, big icons, one line each, a single DISMISS button. It never shows again (stored per player).

| Panel | Line | Icon |
|---|---|---|
| 1 | GET HIT, YOU'RE OUT. | ball hitting a kid, OUT stamp |
| 2 | CATCH IT, THEY'RE OUT. (and you get a 3-second shield) | kid catching, shield ring |
| 3 | THE BALLS ARE CURSED. Watch the colour. A number above a ball means it's about to wake up. | three balls: eye, slime, fuse with a countdown |
| 4 | PICK ONE ABILITY. One use per round. It never kills. | the eight tiles, one glowing |
| Footer | SHIFT sprint, Q dodge (even in the air), hold JUMP on a wall to run it, E ability. Phone: the round buttons. | small key icons |

After dismissing, the pick panel is already open underneath.

**Live hints.** None beyond the two the HUD already carries for everyone: "INCOMING" 0.3 s before a ball reaches you, and the Ghost ring prompt "1 PLAIN THROW. HIT TO GET BACK IN." The owner chose not to add first-time hints.

**Mid-show joiner.** Lands in a stands seat, camera on seat view, HUD shows "NEXT SHOW IN 1:42" and "12 LEFT, ROUND 2" so they can tell a show is running. A tap on CAM cycles to the broadcast view. The pick panel opens 20 s before the next show like everyone else's. If they are new, the how-to-play screen comes first.

## In-round HUD (see `hud-wireframe.svg`)

| Element | Where | Shows |
|---|---|---|
| Live count and timer | top centre, large | "14 LEFT  0:52" |
| Round and Flood | under it | "ROUND 1", becomes "FLOOD  ROUND 1" in pink when the band is moving |
| Ticker | under that, 360 px wide, two lines max | ability uses and catches: "Alex used BLINK", "Sam caught Jo". Each line lives 2 s |
| Role | top left | LIVE, GHOST (with throws left), SPECTATOR, WAITING |
| Camera hint | top right, spectators only | "CAM" and the current mode |
| Stamina | bottom left bar, green, turns red below the dodge cost | mirrors the strip on the player's back |
| Hold timer | bottom left under stamina, only while holding | drains over 8 s |
| Target bracket | in world, above the target's head | red in range, grey out of range, hidden in smoke or on a vanished player |
| Incoming | centre, 0.3 s before impact | "! INCOMING" in pale red |
| Dormant countdown | in world, above the ball, visible to all | the number, then the burst |
| Ghost prompt | centre lower, only on the ring | "GHOST: 1 PLAIN THROW. HIT TO GET BACK IN." |
| Toasts | centre, 2 s | OUT!, CAUGHT!, BACK IN!, CUT!, FLOOD!, "<name> WINS" |

**Phone buttons.** Right cluster, bottom to top: CATCH, THROW (hold to charge), DODGE, ABILITY (icon, ring drains when spent). RUN sits left of the cluster above the joystick. Jump is the default Roblox button. Swipe left or right on the right half of the screen cycles the target.

**PC keys.** WASD, Shift sprint, Space jump (hold on a wall to wall run), Q dodge, E ability, mouse 1 hold-to-charge throw, mouse 2 or F catch, Tab cycle target, C cycle camera.

## Intermission panel (see `hud-pick-panel.svg`)

- Header: next-show timer and the stands count.
- Eight ability tiles, 4 by 2, each with the icon, the name, and "one use per round". The current pick has a thick border in the ability's colour.
- Footer: "Your pick: BLINK. Icon floats above your head until the rush."
- The Wildcard vote is a thin strip under the tiles with the 12 ball icons; tap one. The leading ball shows a crown.
- At 8 s left the panel locks and fades, leaving only the timer and "GET TO THE TUNNELS."

## Jumbotron

The jumbotron is the HUD for the stands. It shows, in order of priority: the countdown, the live count and timer, the ticker's last line, the Flood warning, the replay, the winner. It never shows anything a player on the court does not also get on their own screen, so nobody has to look up to know the state.
