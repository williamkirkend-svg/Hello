# Logo and intro animation (v0.3)

## The logo

Two words, two worlds.

**DODGEBALL** is the friendly half: fat glossy bubble letters, candy pastels (pink, sky blue, mint, yellow), thick dark outline, white sparkle highlights, a slightly bouncy baseline. The second O is a tiny red rubber ball. It should look like a lunchbox sticker. Nothing about it is threatening.

**CURSED** is the other half: enormous, jagged, splintered letters that look like scorched black metal with lava-orange cracks, spiky serifs like broken glass, orange and violet flames and embers pouring off the tops, tilted a few degrees. It sits on top of DODGEBALL as if it just crashed down from above, with a dent, cracks and dust where it landed. The bubble letters are squashed a little under it.

Rules for the final asset:
- Reads at 128 px wide (the Roblox experience icon) and at 1920 px (the thumbnail). At icon size only CURSED needs to be legible; DODGEBALL can be a pastel shape underneath.
- Two separate layers, exported as two PNGs with alpha: `logo_dodgeball.png` and `logo_cursed.png`, plus a flattened `logo_full.png`. The intro animation needs the layers apart.
- One accent palette for the whole game comes from it: candy pastels for the friendly world (stands, lobby, cosmetics), scorched black and lava orange for the cursed world (cursed balls, the Flood warning, the jumbotron alert state).

Concept candidates are in `concept-images.md` (images 13 to 16). The final logo should be redrawn as vector art from the chosen direction so the edges are clean at every size.

## The intro animation (plays when a player joins)

Total 3.5 seconds, skippable with a tap after 1 second. It runs over the loading screen before the stands fade in.

| Time | What happens | Sound |
|---|---|---|
| 0.0 | Cream background. DODGEBALL pops in letter by letter from the left, each letter overshooting and settling (a bounce, 0.08 s apart). The little red ball O rolls in last and bounces twice. | A cheerful xylophone run, one note per letter, a boing for the ball |
| 0.9 | Hold. A sparkle twinkles on the B. Everything is lovely. | A soft twinkle |
| 1.3 | The screen darkens at the top. A shadow grows over DODGEBALL. The bubble letters look up (a 5-degree squash upward, like a flinch). | A low rumble builds |
| 1.6 | CURSED slams down from above the frame at full speed and lands on DODGEBALL. Screen shake, 0.25 s. The bubble letters squash under the impact and a dust ring and cracks spread outward. Embers burst up. | A huge metal impact with a bass drop |
| 1.9 | CURSED settles with a slight tilt. Flames rise off the letter tops and keep moving. The cream background cracks and goes dark around the logo. Embers drift. | Flames crackle under a ringing tail |
| 2.6 | The one-sentence tagline fades in beneath, small, in the bubble font: "It's dodgeball. The balls are cursed. Your friends are worse." (or the owner's choice). | None |
| 3.2 | The whole logo shrinks to the top centre and the stands fade in behind it. The logo stays as a small HUD watermark for 2 seconds, then hides. | Crowd noise swells |

Skipping: any tap after 1.0 s jumps to 3.2.

## How it will be built in Roblox (later, not now)

- A ScreenGui with two ImageLabels (the two layers) over a full-screen Frame.
- DODGEBALL letters: either one image with a size-and-position tween, or seven small ImageLabels (one per letter) tweened in sequence with `Enum.EasingStyle.Back` for the overshoot. Seven labels gives the letter-by-letter pop; use them.
- CURSED: one ImageLabel starting above the screen, tweened down with `Enum.EasingStyle.Quart` In (accelerating), then a 0.25 s shake on the whole ScreenGui by offsetting the root Frame, then a 0.3 s settle tween to the final tilt (Rotation).
- Flames: a ParticleEmitter cannot live in a ScreenGui, so flames are a 12-frame flipbook ImageLabel on top of CURSED, looping at 12 fps, or a spritesheet animated with ImageRectOffset. The flipbook is one more exported PNG.
- Dust and cracks: one crack image fading in under CURSED, scaled from 0.6 to 1.0 over 0.3 s.
- Sounds: five SoundIds, played from a SoundGroup so the intro volume is one setting.
- Reuse: the same two layers animate at every show's crowning (CURSED slams onto the winner's name instead of DODGEBALL) and on the thumbnail.

## Owner's words that drove this

"It should start you off actually on just a screen with dodgeball on it. It should be funny and cute, like bubble letters, making it seem friendly. Then a giant CURSED will come crashing down on it. The design for the cursed should be totally different. It should have almost flames coming from it, making it actually seem cursed. Make it jagged and crazy."
