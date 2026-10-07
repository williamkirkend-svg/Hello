# Logo and intro animation (v0.3)

## The logo

Two words, two worlds, on black.

**DODGEBALL** is plain and friendly, in the spirit of a party-game title: big bold rounded chunky letters, flat white fill with no texture, a thick black outline and a thin white keyline around that, letter heights slightly staggered so it bounces. The owner's reference is the "MARIO PARTY" lettering in the Super Mario Party Jamboree logo; we borrow the feel (plain white, rounded, bold, outlined), not the lettering itself.

**CURSED** is the surprise, about half the size, falling onto DODGEBALL and overlapping its upper-left part at a tilt of about 12 degrees. Each letter is a thick, boxy, blocky stone border with square corners and chipped edges, like a frame of rough grey rock, and the hollow inside of every letter is purple fire: violet and magenta flames curling upward out of the top of the letters, purple embers drifting, purple light spilling onto the white letters beneath. The stone is the frame; the flames are the letter.

Rules for the final asset:
- Background is black in the logo, the intro and the thumbnail. The white letters and purple fire are built for it.
- Reads at 128 px wide (the Roblox experience icon) and at 1920 px (the thumbnail). The icon crop is the overlap: the first letters of DODGEBALL with CURSED across them.
- Layers, exported as separate PNGs with alpha: `logo_dodgeball.png`, `logo_cursed_frame.png` (the stone outlines only, hollow), `logo_cursed_fire.png` (a 12-frame flipbook of the purple flames masked to the letter interiors), plus a flattened `logo_full.png`. The flipbook is what makes the fire move in the real intro.
- One accent palette for the whole game comes from it: white and black for the friendly world (stands, lobby, HUD), grey stone and purple fire for the cursed world (cursed balls, the Flood warning, the jumbotron alert state, the ability flash for Phase and Vanish).

Concept candidates are in `concept-images.md`: images 13 to 16 were the bubble-letter direction, 17 to 20 the multicolour block direction, 21 and 22 the current white-and-purple-fire direction. The final logo should be redrawn as vector art from the chosen image so the edges are clean at every size.

## The intro animation (plays when a player joins)

Total 3.5 seconds, skippable with a tap after 1 second. It runs over the loading screen before the stands fade in.

| Time | What happens | Sound |
|---|---|---|
| 0.0 | Black background. DODGEBALL pops in letter by letter from the left, each plain white letter overshooting and settling with a bounce (0.08 s apart). | A cheerful xylophone run, one note per letter |
| 0.9 | Hold. A sparkle twinkles on the B. Plain, white, lovely. | A soft twinkle |
| 1.3 | Nothing warns you. Maybe one pebble bounces across the D. | A single small rock click |
| 1.5 | CURSED falls in fast from above, its stone frames dark and unlit, and lands overlapping the upper-left part of DODGEBALL at a 12-degree tilt. Screen shake, 0.15 s. The white letters under it squash, a puff of grey dust, a handful of pebbles scatter. It is a surprise, not a build-up. | A sharp rock slap with a bass thump, then a short rattle of pebbles |
| 1.7 | The purple fire ignites inside the stone frames, letter by letter from left to right (0.05 s apart), and keeps burning: the flipbook loops, embers drift up, purple light flickers onto the white letters. DODGEBALL's letters bounce back up, slightly dented, carrying on as if nothing happened. | A whoosh as each letter lights, then a low purple-fire crackle, a short comic boing on the bounce-back |
| 2.6 | The one-sentence tagline fades in beneath, small, in the block font: "It's dodgeball. The balls are cursed. Your friends are worse." (or the owner's choice). | None |
| 3.2 | The whole logo shrinks to the top centre and the stands fade in behind it. The logo stays as a small HUD watermark for 2 seconds, then hides. | Crowd noise swells |

Skipping: any tap after 1.0 s jumps to 3.2.

## How it will be built in Roblox (later, not now)

- A ScreenGui with two ImageLabels (the two layers) over a full-screen Frame.
- DODGEBALL letters: either one image with a size-and-position tween, or seven small ImageLabels (one per letter) tweened in sequence with `Enum.EasingStyle.Back` for the overshoot. Seven labels gives the letter-by-letter pop; use them.
- CURSED: two stacked ImageLabels about half of DODGEBALL's width, the stone frame and the fire flipbook, in one Frame starting above the screen at Rotation -20, tweened in 0.2 s with `Enum.EasingStyle.Quart` In to its overlap anchor with Rotation -12, then a 0.15 s shake on the root Frame, then a 0.2 s wobble tween (Rotation -15 to -12). The fire label starts at ImageTransparency 1 and fades in per letter using six masked sub-labels, or as one label if per-letter ignition proves fiddly. Anchored over the first letters so the two words can be positioned independently of screen size.
- Flames: a ParticleEmitter cannot live in a ScreenGui, so the purple fire is a 12-frame flipbook masked to the letter interiors, looping at 12 fps through ImageRectOffset on a spritesheet. The stone frame sits on top so the fire is clipped to the letter shapes.
- Dust, pebbles and cracks: one crack image fading in under CURSED, scaled from 0.6 to 1.0 over 0.3 s, plus six small rock ImageLabels flung outward on short arcs.
- Alternative for a true 3D logo: build the letters as MeshParts in a ViewportFrame and animate the CURSED model's CFrame dropping; this gives real bevels and lighting but costs more to make. Decide after the vector version exists.
- Sounds: five SoundIds, played from a SoundGroup so the intro volume is one setting.
- Reuse: the same slap animates at every show's crowning (the CURSED sticker slaps onto the winner's name), on the thumbnail, and as the OUT stamp style when a player is eliminated (a small rock stamp, same rotation).

## Owner's words that drove this

"It should start you off actually on just a screen with dodgeball on it. It should be funny and cute, making it seem friendly. Then a giant CURSED will come crashing down on it. The design for the cursed should be totally different." Then: "make the Dodgeball the white mario font, I want it to look plain like that and then the cursed comes down, overlapping dodgeball. Instead of the actual word being the stone, I want it to have a thick, boxy outline for each letter, and the inside of the stone should be purple flames, we can make them move and look like actual flames for the real intro. Black background."
