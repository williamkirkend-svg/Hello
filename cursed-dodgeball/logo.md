# Logo and intro animation (v0.3)

## The logo

Two words, two worlds.

**DODGEBALL** is the fun half, in the spirit of a classic platformer title: huge bold chunky 3D block letters with thick rounded bevels and a deep silver-white extrusion, every letter a different bright glossy colour (red, green, blue, yellow, orange) with a sparkle highlight, slightly tilted and bouncing along an arc. The second O can be a red rubber ball. Nothing about it is threatening. (The owner's reference is the Super Mario Galaxy logo; we borrow the feel, chunky multicolour 3D block letters, not the lettering itself, which is Nintendo's.)

**CURSED** is the surprise: about a third the size of DODGEBALL, slapped onto its upper-left corner over the first two letters, rotated about 15 degrees counter-clockwise like a sticker slammed on in a hurry. Craggy letters carved out of dark cracked rock, jagged chipped edges, fissures with lava glowing orange inside, small flames and embers off the tops, a puff of rock dust and hairline cracks on the big letters right where it hit. DODGEBALL stays dominant and cheerful; CURSED is the thing that ruins it, and that contrast is the joke.

Rules for the final asset:
- Reads at 128 px wide (the Roblox experience icon) and at 1920 px (the thumbnail). At icon size the crop is the top-left of the logo: the D, the O and the CURSED sticker, so both words read.
- Two separate layers, exported as two PNGs with alpha: `logo_dodgeball.png` and `logo_cursed.png`, plus a flattened `logo_full.png`. The intro animation needs the layers apart.
- One accent palette for the whole game comes from it: the bright primaries of the block letters for the friendly world (stands, lobby, cosmetics), dark rock and lava orange for the cursed world (cursed balls, the Flood warning, the jumbotron alert state).

Concept candidates are in `concept-images.md`: images 13 to 16 are the earlier bubble-letter direction, images 17 to 20 are the chosen chunky-block direction. The final logo should be redrawn as 3D or vector art from the chosen direction so the edges are clean at every size.

## The intro animation (plays when a player joins)

Total 3.5 seconds, skippable with a tap after 1 second. It runs over the loading screen before the stands fade in.

| Time | What happens | Sound |
|---|---|---|
| 0.0 | Starry blue background. DODGEBALL pops in letter by letter from the left, each chunky block letter overshooting and settling with a bounce (0.08 s apart), each in its own colour. The red ball O rolls in last and bounces twice. | A cheerful xylophone run, one note per letter, a boing for the ball |
| 0.9 | Hold. A sparkle twinkles on the B. Everything is lovely. | A soft twinkle |
| 1.3 | Nothing warns you. Maybe one pebble bounces across the D. | A single small rock click |
| 1.5 | CURSED comes in fast from off-screen top-left, small, spinning slightly, and slaps onto the upper-left corner of DODGEBALL at a 15-degree tilt. Screen shake, 0.15 s. The D and the first O squash and crack under it, a puff of rock dust, a handful of pebbles and embers scatter. It is a surprise, not a build-up. | A sharp rock slap with a bass thump, then a short rattle of pebbles |
| 1.8 | CURSED wobbles once and settles, still tilted. Lava glows in its cracks, small flames flicker on top and keep moving. DODGEBALL's letters bounce back up, slightly dented, carrying on as if nothing happened. | Flames crackle quietly, a short comic boing on the bounce-back |
| 2.6 | The one-sentence tagline fades in beneath, small, in the block font: "It's dodgeball. The balls are cursed. Your friends are worse." (or the owner's choice). | None |
| 3.2 | The whole logo shrinks to the top centre and the stands fade in behind it. The logo stays as a small HUD watermark for 2 seconds, then hides. | Crowd noise swells |

Skipping: any tap after 1.0 s jumps to 3.2.

## How it will be built in Roblox (later, not now)

- A ScreenGui with two ImageLabels (the two layers) over a full-screen Frame.
- DODGEBALL letters: either one image with a size-and-position tween, or seven small ImageLabels (one per letter) tweened in sequence with `Enum.EasingStyle.Back` for the overshoot. Seven labels gives the letter-by-letter pop; use them.
- CURSED: one ImageLabel about a third of DODGEBALL's width, starting off-screen top-left at Rotation -40, tweened in 0.2 s with `Enum.EasingStyle.Quart` In to its corner anchor with Rotation -15, then a 0.15 s shake on the root Frame, then a 0.2 s wobble tween (Rotation -18 to -15). Anchored over the first two letters so the two labels can be positioned independently of screen size.
- Flames: a ParticleEmitter cannot live in a ScreenGui, so flames are a 12-frame flipbook ImageLabel on top of CURSED, looping at 12 fps, or a spritesheet animated with ImageRectOffset. The flipbook is one more exported PNG.
- Dust, pebbles and cracks: one crack image fading in under CURSED, scaled from 0.6 to 1.0 over 0.3 s, plus six small rock ImageLabels flung outward on short arcs.
- Alternative for a true 3D logo: build the letters as MeshParts in a ViewportFrame and animate the CURSED model's CFrame dropping; this gives real bevels and lighting but costs more to make. Decide after the vector version exists.
- Sounds: five SoundIds, played from a SoundGroup so the intro volume is one setting.
- Reuse: the same slap animates at every show's crowning (the CURSED sticker slaps onto the winner's name), on the thumbnail, and as the OUT stamp style when a player is eliminated (a small rock stamp, same rotation).

## Owner's words that drove this

"It should start you off actually on just a screen with dodgeball on it. It should be funny and cute, like bubble letters, making it seem friendly. Then a giant CURSED will come crashing down on it. The design for the cursed should be totally different. It should have almost flames coming from it, making it actually seem cursed. Make it jagged and crazy."
