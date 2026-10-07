# Logo and intro animation (v0.4, approved)

**Approved reference:** `concepts/logo-approved-reference.png` (the Figma take 1 render, image 25 in `concept-images.md`). This is the look. The production asset is a clean rebuild of it in separate layers, not the render itself.

## The logo

Two words, two worlds, on black.

**DODGEBALL** is plain and friendly, in the spirit of a party-game title: big bold letters that are very round and puffy, soft bubble-shaped letterforms with no sharp corners, stretched a little wider than normal so the word spans almost the full width, flat white fill with no texture, a thick black outline and a thin white keyline around that, letter heights slightly staggered so it bounces. The whole word stays readable at all times. The owner's reference is the "MARIO PARTY" lettering in the Super Mario Party Jamboree logo; we borrow the feel (plain white, rounded, bold, outlined), not the lettering itself.

**CURSED** is the surprise, about 40 percent of DODGEBALL's height, landing on the top-left corner in front of the word so it overlaps only the upper part of the first two or three letters and leaves the rest of DODGEBALL clear (it is always the top layer), tilted about 12 degrees clockwise so its right end sits lower than its left. It changes the look without hiding the word. The letterforms follow the owner's reference, a tall, condensed, heavy display font with cracked-rock texture (the "Desert Rock" style): tall narrow bold letters, chipped jagged edges, a dark outline and a short 3D drop shadow. In our version the cracked stone is only a thick border around each letter, and the hollow inside of every letter is purple fire: violet and magenta flames curling upward out of the top of the letters, purple embers drifting, purple light spilling onto the white letters beneath. The stone is the frame; the flames are the letter.

Rules for the final asset:
- Background is black in the logo, the intro and the thumbnail. The white letters and purple fire are built for it.
- Reads at 128 px wide (the Roblox experience icon) and at 1920 px (the thumbnail). The icon crop is the overlap: the first letters of DODGEBALL with CURSED across them.
- Layers, exported as separate PNGs with alpha: `logo_dodgeball.png`, `logo_cursed_frame.png` (the stone outlines only, hollow), `logo_cursed_fire.png` (a 12-frame flipbook of the purple flames masked to the letter interiors), plus a flattened `logo_full.png`. The flipbook is what makes the fire move in the real intro.
- One accent palette for the whole game comes from it: white and black for the friendly world (stands, lobby, HUD), grey stone and purple fire for the cursed world (cursed balls, the Flood warning, the jumbotron alert state, the ability flash for Phase and Vanish).

Concept candidates are in `concept-images.md`: images 13 to 16 were the bubble-letter direction, 17 to 20 the multicolour block direction, 21 and 22 the current white-and-purple-fire direction. The final logo should be redrawn as vector art from the chosen image so the edges are clean at every size.

## The main screen (plays when a player joins)

The logo is the main screen, not a splash. Total about 5 seconds before the stands fade in, skippable with a tap after the slam. The owner's sequence: DODGEBALL alone in the middle, a few seconds of calm, CURSED slams down, then the purple fire ignites right after it lands.

| Time | What happens | Sound |
|---|---|---|
| 0.0 | Black screen. DODGEBALL pops in letter by letter from the left, centred in the middle of the screen, each wide white letter overshooting and settling with a bounce (0.08 s apart). | A cheerful xylophone run, one note per letter |
| 0.8 to 2.8 | Hold. DODGEBALL sits alone in the centre, plain and friendly. A sparkle twinkles on the B around 1.5 s. Nothing warns you. Two full seconds of calm so the slam lands as a surprise. | Soft crowd murmur, one twinkle |
| 2.8 | CURSED SLAMS down from above the frame at full speed, stone frames dark and unlit, and lands on the top-left corner of DODGEBALL at a 12-degree clockwise tilt, overlapping the top of the first letters. Screen shake 0.2 s. The letters under it squash and crack, a burst of grey dust and pebbles scatters. | A huge rock slam with a bass drop, pebbles rattling |
| 3.1 | The purple fire ignites inside the stone frames, letter by letter from left to right (0.05 s apart), flames bursting up above the tops, purple embers rising, purple glow flooding down onto the white letters. The fire keeps burning: the flipbook loops. DODGEBALL's letters bounce back up slightly dented. | A sharp whoosh per letter, then a low purple-fire crackle, a comic boing on the bounce-back |
| 3.8 | The tagline fades in beneath, small, in the DODGEBALL font: "It's dodgeball. The balls are cursed. Your friends are worse." (owner's choice pending). PLAY prompt appears: "TAP TO PLAY" on phones, "PRESS ANY KEY" on PC. | None |
| on input | The logo shrinks to the top centre and the stands fade in behind it. The logo stays as a small HUD watermark for 2 seconds, then hides. | Crowd noise swells |

Skipping: any tap after 2.8 s jumps straight to the end of the fire ignition at 3.8.

The same slam-then-ignite beat reuses at every show's crowning (the CURSED sticker slaps onto the winner's name and lights up) and the OUT stamp uses the same stone style.

## How it will be built in Roblox (later, not now)

- A ScreenGui with two ImageLabels (the two layers) over a full-screen Frame.
- DODGEBALL letters: nine ImageLabels (one per letter) tweened in sequence with `Enum.EasingStyle.Back` for the overshoot, centred as a group in the middle of the screen. The letter-by-letter pop is the friendly beat.
- CURSED: two stacked ImageLabels about 40 percent of DODGEBALL's height, anchored at the top-left of the word, the stone frame and the fire flipbook, in one Frame starting above the screen at Rotation 20, held invisible until 2.8 s, then tweened in 0.18 s with `Enum.EasingStyle.Quart` In to its top-left overlap anchor with Rotation 12 (clockwise), then a 0.2 s shake on the root Frame, then a 0.2 s wobble tween (Rotation 15 to 12). The fire label stays at ImageTransparency 1 until 3.1 s, then six masked sub-labels (one per letter) fade in 0.05 s apart and the flipbook starts looping. CURSED's ZIndex is above DODGEBALL's so it always covers the white letters. The fire label starts at ImageTransparency 1 and fades in per letter using six masked sub-labels, or as one label if per-letter ignition proves fiddly. Anchored over the first letters so the two words can be positioned independently of screen size.
- Flames: a ParticleEmitter cannot live in a ScreenGui, so the purple fire is a 12-frame flipbook masked to the letter interiors, looping at 12 fps through ImageRectOffset on a spritesheet. The stone frame sits on top so the fire is clipped to the letter shapes.
- Dust, pebbles and cracks: one crack image fading in under CURSED, scaled from 0.6 to 1.0 over 0.3 s, plus six small rock ImageLabels flung outward on short arcs.
- Alternative for a true 3D logo: build the letters as MeshParts in a ViewportFrame and animate the CURSED model's CFrame dropping; this gives real bevels and lighting but costs more to make. Decide after the vector version exists.
- Sounds: six SoundIds (xylophone run, twinkle, rock slam, pebble rattle, fire whoosh, fire crackle loop), played from a SoundGroup so the intro volume is one setting.
- The main screen is a LocalScript in StarterPlayerScripts that runs once per join, before the stands camera takes over; the show state keeps running underneath so the timer is live the moment the screen clears.
- Reuse: the same slap animates at every show's crowning (the CURSED sticker slaps onto the winner's name), on the thumbnail, and as the OUT stamp style when a player is eliminated (a small rock stamp, same rotation).

## Owner's words that drove this

"It should start you off actually on just a screen with dodgeball on it. It should be funny and cute, making it seem friendly. Then a giant CURSED will come crashing down on it. The design for the cursed should be totally different." Then: "make the Dodgeball the white mario font, I want it to look plain like that and then the cursed comes down, overlapping dodgeball. Instead of the actual word being the stone, I want it to have a thick, boxy outline for each letter, and the inside of the stone should be purple flames, we can make them move and look like actual flames for the real intro. Black background."
