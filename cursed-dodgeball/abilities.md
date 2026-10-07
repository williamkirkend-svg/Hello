# Abilities (v0.3)

One ability per player. Picked between games, locked for the whole game, one use per round, refreshed at every round start. Ghosts and Spectators cannot use abilities. No ability ever puts a player out; only a ball does.

## The pick

- **Where:** the ability board on the concourse behind the top row, and the same eight tiles as a panel in the HUD during the intermission (so phones never have to walk anywhere).
- **When:** any time during the intermission. Locked the moment round 1 starts. Changing a pick mid-game is not possible.
- **Default:** a new player who never picks gets Blink.
- **Readability:** during the intermission everyone's pick floats above their head as an icon. Once the round starts the icon hides, so reading the field is a thing you do before the rush.
- **Server rules:** the server stores the pick per player, rejects any ability use when `usedThisRound` is true, when the role is not Live, when the phase is not Round, and rejects a pick change outside Intermission.

## Shared presentation

- One button: E on keyboard, ButtonL1 on gamepad, a round touch button above Dodge on phones. The button shows the ability icon and greys out after the use.
- Every use: a 0.3-second flash in the ability's colour on the player, a short sound, a 2-second ticker line on the jumbotron ("Alex used BLINK"), and a small icon pop above the head visible from the stands.
- Every ability is between 1 and 3 seconds long. The simplest counter to all of them is to wait.

## The eight

### Blink (colour: electric blue)
- **Effect:** teleport 12 studs in your current movement direction (your facing if standing still). You keep your held ball. If a wall is in the way you stop 1 stud short of it. You cannot blink through the pit wall, the kerb or into the Flood: the server clamps the destination inside the live court.
- **Timing:** instant; 0.15 s of blue afterimage at the start point.
- **Counter:** blinks are straight lines in the movement direction. Throw at the landing spot.
- **Ball interactions:** a ball already in flight at your old position misses. The Eye Ball re-acquires you after the blink (it steers, it is allowed to).
- **Server validation:** destination = server position + direction x 12, raycast for walls, clamp to court. The client never sends a destination.

### Grapple (colour: orange)
- **Effect:** fire a hook at the nearest grapple anchor within 30 studs in the camera direction (pillar tops, rails, the pit wall's top edge). You zip there in a straight line at 60 studs per second and arrive standing on it. Holding a ball is fine.
- **Timing:** 0.1 s hook, up to 0.5 s zip.
- **Counter:** the zip is a straight line and the arrival point is on a known anchor. Throw at the anchor.
- **Ball interactions:** you can be hit mid-zip. Arriving on the pit wall top edge puts you on the Ghost ring side of the rail: that counts as leaving the court and you are out, so the server refuses the pit wall as a destination during the Flood or final and warns with a red hook icon.
- **Server validation:** the anchor must be in the server's anchor list and within range; the zip path is server-driven.

### Snatch (colour: green)
- **Effect:** the nearest loose ball within 20 studs flies into your hand over 0.3 s. Only idle balls; never a held ball, never a ball in flight.
- **Timing:** 0.3 s.
- **Counter:** pick up loose balls near a Snatch player before they do, or hold yours.
- **Ball interactions:** a dormant cursed ball can be snatched and arrives still dormant. A Black Hole pulling a ball loses the tug-of-war to Snatch.
- **Server validation:** the server picks the ball; if you already hold one, Snatch fails and is not consumed.

### Bubble (colour: cyan)
- **Effect:** a translucent bubble around you for 1.5 seconds. The first ball that would hit you is caught: the thrower is out, you gain the 3-second shield, you now hold that ball. The bubble pops on the catch.
- **Timing:** 1.5 s, pops early on a catch.
- **Counter:** do not throw into a bubble. Wait 1.5 seconds. A Giant cannot be caught by one player, so a Giant pops the bubble and hits.
- **Ball interactions:** Fuse caught by a bubble still ticks in your hand. A Boomerang caught stops its return. A Shadow caught becomes visible. A Decoy's fake pops the bubble harmlessly (the bubble treats it as a catch of nothing, which is the one way to waste a Bubble).
- **Server validation:** the server resolves the catch inside its normal hit step, treating an active bubble as a catch press with a perfect window.

### Phase (colour: violet)
- **Effect:** 1 second of translucency. Balls pass straight through you. This is not a catch: no thrower is out, no shield. You cannot throw or catch while phased.
- **Timing:** 1 s.
- **Counter:** it is short and loud. Throw after it ends. Phase does not stop the Flood or the kerb.
- **Ball interactions:** a ball that passes through a phased player stays live and can hit someone behind them. Glue already on your feet keeps you stuck while phased.
- **Server validation:** the hit step skips the player for 1 s from the server's own timestamp.

### Vanish (colour: white)
- **Effect:** fully invisible for 1.5 seconds. Target brackets drop off you and cannot re-lock until you reappear. Your held ball stays visible, floating where your hand is, so a player carrying a ball is not truly hidden. Footstep dust still shows.
- **Timing:** 1.5 s.
- **Counter:** watch for the floating ball or the dust, throw at where they were heading. Vanish gives no immunity: a thrown ball still hits an invisible player.
- **Ball interactions:** none special. You can throw while invisible; the throw reveals you for 0.3 s.
- **Server validation:** the server sets a replicated `Invisible` attribute; clients hide the character and the picker ignores it. Hits still resolve normally.

### Slam (colour: red)
- **Effect:** you jump 6 studs and slam down. On landing, a shockwave pushes every other player within 8 studs 6 studs away from you and knocks every loose ball within 8 studs outward. Nobody is put out by the push itself. The kerb and the Flood can finish what the push started. A player on a rail is pushed off it.
- **Timing:** 0.6 s total, you are vulnerable in the air.
- **Counter:** stay out of 8 studs, or catch them in the air.
- **Ball interactions:** held balls are kept. Balls pushed outside the kerb roll back after 2 seconds as usual.
- **Server validation:** the push is applied by the server as a short impulse; the client only requests the slam.

### Smoke (colour: grey)
- **Effect:** a 10-stud-wide smoke cloud at your feet for 4 seconds. Target brackets cannot lock onto anyone inside the cloud, and the bracket on anyone inside drops. Players inside see out; players outside see shapes.
- **Timing:** 4 s.
- **Counter:** the cloud does not move. Throw into it at where the shapes are, or wait.
- **Ball interactions:** balls fly through smoke normally. The Eye Ball cannot acquire a target inside smoke.
- **Server validation:** the server owns the cloud position and lifetime; the picker on every client excludes players inside it.

## Interactions table (ability versus ball, the ones that matter)

| | Eye | Giant | Fuse | Shadow | Boomerang | Swap |
|---|---|---|---|---|---|---|
| Blink | re-acquires you | fine | fine | fine | fine | fine |
| Bubble | caught | pops bubble, hits | caught, still ticking | caught, becomes visible | caught, no return | caught, no swap |
| Phase | passes through | passes through | passes through, then lands | passes through | passes through | passes through |
| Vanish | can still home on you | hits | hits | hits | hits | swaps you, revealing you |
| Smoke | cannot acquire inside | fine | fine | fine | fine | fine |

## Roadmap abilities (one line each)

Quickdraw: next throw within 5 s is fully charged with no charge time. Shrink: half size for 3 s, slower. Magnet: loose balls within 15 studs roll to you over 2 s. Swap Places: trade spots with your bracketed target. Spring: a bounce pad under you for 6 s. Rewind: return to where you stood 3 s ago. Decoy: a clone runs ahead for 3 s and pops when hit.

## Mobile layout

Right-hand cluster, bottom to top: Catch, Throw (hold to charge), Dodge, Ability. Sprint sits left of the cluster. Jump is the default Roblox button. The ability button carries the ability icon and a thin ring that drains to show it is spent.
