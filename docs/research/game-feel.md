# Game Feel ("Juice") for Our Platform Fighter, and How to Build It on Roblox

Scope: the *feel* of hits, KOs and movement (sound, haptics, VFX, camera, UI). Knockback math and frame data are covered in the separate mechanics report. This doc gives suggested starting values; treat every number as a first tuning pass to be tested in play.

Researched 2026-10-05. Claims I could not confirm against a primary source are marked **[unverified]**.

---

## Top takeaways for our game

1. **Hitstop is the single biggest win, so build it first.** Freeze both fighters for a short time scaled by damage. Smash Ultimate uses `floor(damage * 0.65 + 6)` frames, capped at 30 ([SmashWiki: Hitlag](https://www.ssbwiki.com/Hitlag)). We should start with a slightly shorter curve (formula below), because Roblox latency already adds some "weight".
2. **Make the victim shake during hitstop, not the attacker.** Shake horizontally when the victim is grounded and vertically when airborne, and let the shake decay over the freeze. This is Sakurai's own list of techniques ([Eight Hit Stop Techniques, via Nintendo Wire](https://nintendowire.com/news/2022/12/12/this-week-in-sakurai-12-5-12-11-fine-tuning-hit-stop-and-cheating-the-system/); [video](https://www.youtube.com/watch?v=tycbMSjDDLg)).
3. **Control our own simulation clock.** Roblox cannot pause physics. The cleanest way to get hitstop, slow-mo and KO zoom is a custom kinematic 2.5D character controller with a per-fighter `timeScale`. The fallbacks (anchor or zero the velocity, plus `AnimationTrack:AdjustSpeed(0)`) work but are fragile.
4. **Play all feedback on the client, right away.** The attacker's client plays the hit spark, sound, hitstop and rumble as soon as its local hitbox overlaps, without waiting for the server (Swink: response must land within about 100 ms to feel "real-time", per [Wikipedia: Game feel](https://en.wikipedia.org/wiki/Game_feel)). The server confirms damage and knockback. If the server rejects the hit, we just skip the knockback. The VFX has already been forgiven.
5. **Use trauma-based camera shake.** Hits add "trauma" (0 to 1). Shake = trauma² × max offset, driven by Perlin noise, with linear decay (Eiserloh, GDC 2016; [summary](https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math)). Keep the shake small on light hits and large only on heavies and KOs.
6. **Give KO hits their own signature.** Use extra hitstop, a camera punch-in toward the impact, about 0.4 s of slow-mo, a background tint/flash, a unique sound, and a blast-zone "explosion" column. Copy Smash Ultimate's Finish Zoom, which fires when a hit *will* win the game, with a red background, slow-mo and zoom ([SmashWiki: Finish Zoom](https://www.ssbwiki.com/Finish_Zoom)). Use a lighter version for every non-final KO.
7. **Layer impact sounds and add ±5–10% pitch randomization.** Use 3 layers (transient "snap", body "thump", tail/sweetener), scale volume and low end by hit tier, and duck music/ambience briefly on heavy hits. Roblox's new Audio API (`AudioPlayer` + `AudioPitchShifter`/`AudioEqualizer`/`AudioCompressor` over `Wire`s) is now the recommended path. `Sound`/`SoundGroup` are "discouraged" ([Audio objects](https://create.roblox.com/docs/audio/objects)).
8. **Use the new `HapticEffect` API for rumble on gamepad and mobile.** It covers Xbox/PlayStation pads and most iPhone/Pixel/Galaxy phones ([HapticEffect](https://create.roblox.com/docs/reference/engine/classes/HapticEffect)). It has `GameplayCollision`/`GameplayExplosion` presets plus custom waveforms. The legacy `HapticService:SetMotor` is marked deprecated and only targets gamepads ([HapticService](https://create.roblox.com/docs/reference/engine/classes/HapticService)).
9. **Flash the victim white with a `Highlight` for 1–3 frames.** Keep the flash short and never strobe it. The Highlight cap is now 255 per DataModel (it used to be 31), but each one costs a draw call ([DevForum: Lights, Camera, More Highlights](https://devforum.roblox.com/t/lights-camera-more-highlights/4061534)).
10. **Movement juice is cheap and matters as much as hit juice.** Add dust puffs on dash, jump and landing, landing squash, a tiny jump and land sound, and a short smoke trail behind launched fighters, so players can read launch speed and direction.
11. **Make the damage % UI readable.** Shake and scale-pop the number on each hit (scaled by damage), and ramp its color from white to yellow, orange, red and dark red as % rises, so players can read KO danger at a glance.
12. **Ship accessibility toggles on day one.** Include sliders for screen shake (0–100%), flash intensity (with a "reduce flashing" option), rumble/haptics on/off, and slow-mo/zoom on/off. Never let anything flash more than 3 times per second ([WCAG 2.3.1](https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold)). Xbox guidelines say to "avoid or allow disabling camera shake" ([XAG 117](https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/117)). Put the shake budget in competitive mode on the low end.

---

## Hit tier table (starting values)

Times are given in seconds (Roblox frame rate varies) with 60 fps frame equivalents. "Shake" is trauma added to the camera's trauma pool (0–1); the max camera offset at trauma 1 is about 0.6 studs translation and about 1.5 degrees roll for a side-on 2.5D camera at a typical fighting distance (tune to your FOV).

| Tier | Example damage | Hitstop (both fighters) | Victim shake (during hitstop) | Camera trauma added | Camera punch / zoom | Rumble (attacker / victim) | Sound | VFX |
|---|---|---|---|---|---|---|---|---|
| **Light** (jab, tilts) | 1–6% | 0.05–0.08 s (3–5 f) | ±0.10 studs, decaying | 0.10–0.15 (barely visible) | none | Victim: 60 ms, intensity 0.25 (small/high-freq motor). Attacker: 40 ms, 0.15, or off | 1–2 layers, short "snap" transient, pitch ±10%, vol 0.5 | Small spark (8–12 particles), 1-frame white Highlight on victim |
| **Medium** (smash-tilts, aerials) | 7–12% | 0.09–0.13 s (5–8 f) | ±0.20 studs | 0.25–0.35 | none, or 2–3% FOV punch | Victim: 100 ms, 0.5 (both motors). Attacker: 60 ms, 0.3 | 2–3 layers: snap + body thump, pitch ±7%, vol 0.7 | Medium spark + ring/shockwave decal, 2-frame flash, short smoke trail if launched |
| **Heavy** (smash attacks, strong specials) | 13–20% | 0.14–0.22 s (8–13 f) | ±0.35 studs, decaying | 0.45–0.6 | 4–6% FOV punch-in, ease back over 0.25 s | Victim: 180 ms, 0.8 (large motor), fast decay. Attacker: 100 ms, 0.5 | 3 layers + sweetener (crunch/whoosh tail), pitch ±5%, vol 0.9, 150 ms music duck (-4 dB) | Large spark, 1–2 impact frames (screen-space burst lines), 3-frame flash, thick launch trail + smoke puffs |
| **KO hit** (hit computed to send past blast zone) | any | Base tier hitstop × 1.5, min 0.25 s (15 f), max 0.4 s (24 f) | ±0.45 studs | 0.8, plus a separate trauma 1.0 burst on blast-zone exit | Zoom 10–15% toward impact over 0.08 s, hold during slow-mo, return 0.35 s. Slow-mo 0.25× for 0.35–0.5 s real time. Game-winning KO: tinted background (red, like Smash Finish Zoom) | Victim + attacker: 300 ms custom waveform (spike 1.0, decay to 0.3, tail to 0 at 300 ms). On blast-zone exit: `GameplayExplosion` preset | Unique "KO sting" sample + all heavy layers, low-pass the rest of the mix 0.4 s, crowd "ooh" swell, announcer on final stock | Biggest spark, background darken/tint 0.1 s, speed lines, rainbow/colored blast-zone column at exit point |

Hitstop formula (start here):

```
hitstopFrames = clamp(floor(damage * 0.5 + 3), 3, 20)       -- 60 fps frames
hitstopSeconds = hitstopFrames / 60
if isKO then hitstopSeconds = clamp(hitstopSeconds * 1.5, 0.25, 0.40) end
if isElectric (or "zappy" moves) then hitstopSeconds *= 1.5    -- Smash does this (SmashWiki: Hitlag)
if isProjectile then attackerHitstop = 0                        -- only the projectile object freezes in Smash
```

Compared with Ultimate's `floor(d * 0.65 + 6)` ([SmashWiki](https://www.ssbwiki.com/Hitlag)): a 15% hit gives 10 frames with ours and 15 with Ultimate's. Start lower, because a 2.5D Roblox game at variable frame rates with network jitter tends to feel sticky when freezes run long. Raise it if hits feel weak. For multi-hit moves (rapid jabs, drill kicks), use the light tier on every hit except the last, and give the last hit the full value.

---

## Part 1: Techniques and what the best games do

### 1.1 Hitstop / hitlag / hit freeze

- **What:** at the moment of contact, both attacker and victim freeze for N frames, and the rest of the world keeps running. It "sells that the collision actually happened." Games without it (critpoints cites Dark Souls 2) make hits harder to perceive ([critpoints.net: Hitstop](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/)).
- **Smash:** hitlag scales linearly with damage. The formulas are Melee `d/3 + 3`, Brawl/Smash 4 `d * 0.3846 + 5`, and Ultimate `d * 0.65 + 6`. The cap is 30 frames (20 in Melee). Electric attacks get ×1.5, crouch-cancel ×0.67, and shielded hits ×0.67. In Ultimate, hitlag shrinks with player count (×0.925 for 3 players down to ×0.75 for 8), so free-for-alls don't stutter constantly ([SmashWiki: Hitlag](https://www.ssbwiki.com/Hitlag)). **Copy that player-count reduction for 4-player lobbies.**
- **Attacker vs. victim:** in Smash the attacker freezes on the frame of contact and the victim snaps into the flinch pose. Projectiles don't freeze their thrower (same source).
- **Traditional fighters:** heavier normals get more hitstop. KOF XIII uses about 7 frames for lights and 11 for heavies ([SRK wiki, KOF XIII states](https://srk.shib.live/w/The_King_of_Fighters_XIII/Character_States/Hitstun_Blockstun_state)). In Street Fighter, hitstop also creates the cancel window for hit-confirms ([critpoints](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/); [SF6 game data](https://srk.shib.live/w/Street_Fighter_6/Game_Data)). SF6's Punish Counters get extra-long hitstop.
- **Sakurai's eight hit-stop techniques** ([video](https://www.youtube.com/watch?v=tycbMSjDDLg), [summary](https://nintendowire.com/news/2022/12/12/this-week-in-sakurai-12-5-12-11-fine-tuning-hit-stop-and-cheating-the-system/)):
  1. Shake the character being hit more.
  2. Keep the hitbox/attacker frozen in place.
  3. Shake horizontally on the ground and vertically in the air.
  4. Reduce the shake gradually.
  5. Control the amount of hitstop.
  6. Interpolate frames into the damage pose.
  7. Keep the attacker moving just a little.
  8. Vary the shake intensity with camera distance.

  His earlier video "Stop for Big Moments!" introduces the idea of freezing for big events ([Automaton](https://automaton-media.com/en/news/20220824-15208/)).
- **Gameplay side effect:** Smash lets the victim SDI (nudge their position) during hitlag. That is a mechanics decision for the other report, but if we add SDI, the hitstop freeze is where it happens.

### 1.2 Screen shake

- **Vlambeer, "The Art of Screenshake"** (Jan Willem Nijman, INDIGO 2013, ~40 min; [YouTube](https://www.youtube.com/watch?v=AJdEqssNZ-U); [Kenney's must-see list](https://kenney.nl/learn/must-see-videos-for-indie-developers)). He builds a dull shooter into a juicy one step by step. The techniques he stacks include bigger/faster bullets, muzzle flash, impact effects, enemy hit flashes, knockback, permanence (corpses and shells stay), camera lerp and look-ahead, screen shake, "sleep" (hit pause), gun kickback, and more bass in the sound **[unverified: exact list and order taken from memory of the talk]**. The point that matters for us is that no single effect does it. The stack does.
- **Trauma model (Squirrel Eiserloh, GDC 2016, "Math for Game Programmers: Juicing Your Cameras With Math")** ([Game Developer summary](https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math); [Bevy example implementing it](https://bevy.org/examples/camera/2d-screen-shake/)):
  - `trauma` lives in [0,1]. Events *add* to it, and it decays linearly (about 1.0–1.5 per second).
  - `shake = trauma^2` (or `^3`). This makes small hits nearly invisible and big hits violent, with a smooth falloff.
  - The offsets come from **Perlin noise**, not `math.random`, so the motion is continuous. Use a different noise seed per axis.
  - **Rotational shake** (roll) reads stronger than translational shake. In 2D/2.5D, use small roll plus translation.
- **Directional shake / camera kick:** push the camera along the knockback direction first (a "kick"), then add a little noise. It reads as force in a direction instead of an earthquake. Vlambeer also kicks the camera back opposite the gun. For us: kick the camera toward the launch direction by 0.2–0.5 studs on heavy/KO hits.
- **Don't shake during hitstop *and* after with equal strength.** Smash shakes the *victim* during hitlag. Camera shake is reserved for heavier hits and KOs.

### 1.3 Camera punch, zoom and slow-mo on KO

- **Smash Ultimate "Special Zoom":** certain hard-to-land attacks (Falcon Punch, Warlock Punch) give a blue flash with sparks pointing at the impact, heavy slow-down, and a camera zoom to the impact, plus a signature sound ([SmashWiki: Special Zoom](https://www.ssbwiki.com/Finish_Zoom)).
- **"Finish Zoom":** fires when the game calculates that a hit will produce the *game-winning* KO. It ignores DI, so a fighter can occasionally survive one. It shows a red background, a brief slow-down, a camera zoom, a distinct "ping + sword slash" sound, and the victim's face switches to a shocked expression ([SmashWiki: Finish Zoom](https://www.ssbwiki.com/Finish_Zoom)).
- **What to do:** (a) a lighter "KO punch" on every KO hit, using predicted knockback vs. distance to the blast zone, and (b) the full Finish Zoom treatment only on the match-ending hit. Keep it short (0.35–0.5 s real time). Longer becomes annoying in a fast game and steals control in a 4-player match.

### 1.4 Hit sparks and VFX layering

Build each hit effect from layers that fire on the same frame:

1. **Flash core** (1–2 frames, additive, bright): a quick star/burst at the contact point.
2. **Spark burst**: 8–30 small streaks with high initial speed and high drag, lasting 0.15–0.3 s.
3. **Shockwave ring**: an expanding ring/decal facing the camera, lasting 0.15 s.
4. **Directional slash/arc**: oriented along the attack direction (a slash for blades, a "dent" for blunt hits).
5. **Lingering debris/smoke**: for heavies only, 0.4–0.8 s.

- **Color-code by tier or element.** Light hits are white/yellow, heavy hits orange/red, KO hits a unique color. Players learn to read "how strong was that?" from the color.
- **Impact frames / smear frames:** for 1–2 frames on heavy hits, swap in a high-contrast frame. This can be a stylized silhouette (black/white inverted), radial speed lines, or a smear pose stretched along the motion. This is anime-style "impact frame" language and suits brainrot meme characters. Keep it to ≤2 frames and gate it behind the flash setting.
- **Hurt flash:** tint the victim white for 1–3 frames at contact (Vlambeer and most action games do this). Smash uses hitlag shake plus a colored hit effect instead. Use a brief white fill, then a red tint fading over 0.15 s.
- **Squash and stretch:** victim squashes toward the attacker for about 2 frames, then stretches along the launch vector as they fly. Attacker gets a small stretch on the active frame ([Juice It or Lose It, Jonasson & Purho, GDC Europe 2012](https://www.gamedeveloper.com/design/video-is-your-game-juicy-enough-): "tween, stretch, or squeeze" objects to give them life).
- **Knockback trails/smoke:** a `Trail` on launched fighters whose width/brightness scales with launch speed. Emit smoke puffs every ~0.05 s while knockback speed is above a threshold. Smash does similar launch smoke, which also tells players the fighter is still in hitstun.

### 1.5 Audio design

- **Layering:** each impact sound = transient (click/snap, 20–60 ms) + body (thump/punch, 100–250 ms) + tail/sweetener (crunch, whoosh, debris, reverb). Light hits use transient + small body. Heavies add a low-end boom (about 60–120 Hz) and a tail.
- **Variation:** randomize pitch per hit (±5–10%) and keep 2–4 alternate samples per layer, so 20 jabs in a row don't machine-gun.
- **Scale with damage:** volume, low-end gain and tail length all increase with tier. The heavy/KO tier ducks music and ambience briefly (-3 to -6 dB for 150–400 ms).
- **Hitstop-synced audio:** the impact sound plays at the *start* of hitstop. During KO slow-mo, pitch the world down (0.7–0.8×) or low-pass it, and keep the KO sting at normal pitch so it cuts through.
- **Crowd and announcer:** a crowd "ooh" on heavy hits, a swell or cheer on KOs, and an announcer on game end, last stock and "GAME!". This fits the brainrot theme well with meme-voice announcer lines. Keep a cooldown on crowd reactions (≥1.5 s) so they don't stack.
- **Movement sounds:** soft jump "hup"/whoosh, landing thud scaled by fall speed, dash scuff. These are quiet but present. "More bass" is literally one of Vlambeer's steps **[unverified]**.

### 1.6 Controller rumble and mobile haptics

- **Principle:** rumble should be *short and sharp* for hits (40–200 ms) and *long* only for big events (KO, explosion, stage hazard). Long, low-level constant rumble numbs players.
- **Two-motor pads:** the small motor (high frequency) is crisp and suits light hits. The large motor (low frequency) is heavy and suits heavy hits and KOs. Xbox/PlayStation pads expose both. Roblox's legacy enum has `Large`, `Small`, `LeftTrigger`, `RightTrigger`, `LeftHand`, `RightHand` ([VibrationMotor](https://create.roblox.com/docs/reference/engine/enums/VibrationMotor)).
- **Who rumbles:** the victim always (they need the "I got hit" signal most). The attacker gets a lighter tick (a confirmation that the hit landed). Nobody else does, except during a KO or explosion near them.
- **Mobile:** phone haptics are far weaker and coarser. Use them only for medium+, KO and UI clicks, with short durations. Over-buzzing a phone feels cheap and drains battery.
- **Rate-limit:** max one rumble start per ~50 ms per player, and take the max instead of summing when hits overlap.

### 1.7 Movement feel

- **Dust:** puff on dash start, turnaround (skid), jump takeoff, landing (size scaled by fall speed), and wall jump. Use 4–10 particles, short life (0.2–0.35 s), and ground-colored.
- **Landing squash:** for 2–4 frames, scale Y 0.85 / X 1.1, then spring back. Jump stretch: Y 1.1 / X 0.92 for 2–3 frames.
- **Sound:** every movement verb gets a tiny sound (see 1.5).
- **Responsiveness beats animation:** Swink frames game feel as "realtime control of virtual objects in a simulated space, with interactions emphasized by polish". The real-time part means a response within about 100 ms ([Wikipedia: Game feel](https://en.wikipedia.org/wiki/Game_feel); [Liz England's review of *Game Feel*](https://lizengland.com/blog/review-game-feel-by-steve-swink/)). Movement must be simulated on the local client with zero added input delay. Juice never makes up for laggy controls.

### 1.8 UI feedback

- **Damage %:** on each hit, pop the scale to 1.2–1.5× (by tier) and ease back over 0.15 s. Shake the number ±2–6 px for the hitstop duration. Show the change instantly, not with a count-up animation.
- **Color ramp:** 0–35% white, 35–70% yellow, 70–100% orange, 100–150% red, 150%+ dark red, with an optional pulse at 150%+. Smash uses a similar white-to-red ramp **[unverified: exact thresholds are ours]**.
- **Stock loss:** icon breaks or flies off, plus a portrait flash.
- **Hit counter / combo text:** optional, but fun for a meme game ("SKIBIDI x5"). Keep it off the play area's center.

### 1.9 Readability and accessibility limits

- **Competitive readability:** shake and flash hide spacing information. The camera should never shake on light hits during competitive play, and big shake should be limited to KOs, ideally after the hitstop (when nobody can act anyway).
- **Photosensitivity:** nothing should flash more than 3 times in any 1-second window, and large saturated-red flashes are especially risky ([WCAG 2.3.1](https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold)). A 4-player brawl with white-flash-on-hit can easily exceed 3 flashes per second **across the screen**. Mitigations: (a) cap global full-screen flashes to 1 per 0.5 s, (b) keep per-character flashes small (≤ a character's screen area), (c) provide a "Reduce flashing" setting that turns white flashes into brief outline color changes and disables impact frames.
- **Motion sickness:** Xbox Accessibility Guidelines say to "avoid or allow disabling camera shake, camera bobbing, motion blur" ([XAG 117](https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/117)).
- **Settings to ship:** Screen Shake (0–100%, default 70%), Flash/Impact Frames (On / Reduced / Off), Rumble/Haptics (On/Off plus intensity), KO Slow-Mo and Zoom (On/Off), plus a "Competitive" preset (shake 25%, flashes reduced, slow-mo off in non-final KOs).

---

## Part 2: Roblox implementation

### 2.1 Architecture: who plays what

- **All feel effects are client-side.** The server owns damage, %, knockback values and KOs. Each client renders its own juice.
- **Flow for a hit** (the attacker is a client):
  1. The attacker's client detects the local hitbox overlap and immediately plays the attacker-side hitstop, hit spark, impact sound and attacker rumble, then sends `HitRequest` to the server.
  2. The server validates (range, timing, rate) and computes damage/knockback, then broadcasts `HitConfirmed{attacker, victim, damage, kbVector, tier, isKO}` to all clients.
  3. The victim's client applies victim hitstop + shake + rumble + flash, then the knockback after hitstop (if the victim's client owns its character physics).
  4. Third-party clients play spark + sound at the victim's position, unless they already did.
  5. If the server *rejects* the attacker's predicted hit, the attacker has already seen a spark. That's acceptable, and players rarely notice. Do **not** predict damage % or knockback on the victim.
- **Hitstop sync:** apply hitstop locally on each client, starting from when it learns of the hit. The attacker freezes first (at prediction) and the victim later (on confirm). That's fine, because each player mostly perceives their own character.
- **Remotes:** cosmetic-only broadcasts (extra sparks for spectators, dust) can use `UnreliableRemoteEvent` ([docs](https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent)). Hit confirmation that changes state must use a normal `RemoteEvent`.

### 2.2 Faking hitstop (Roblox has no global pause)

There is no workspace time scale, so pick one of these approaches.

**Option A (recommended): custom kinematic character controller.** For a 2.5D platform fighter, fighters should be moved by our own code (position/velocity integrated per frame on the owning client, collision via raycasts/shapecasts against stage geometry), not by Humanoid physics. Each fighter has `localTimeScale`. Hitstop sets it to 0 for N seconds, KO slow-mo sets it to 0.25, and the simulation does `dt * localTimeScale`. This also gives deterministic-feeling knockback and easy rollback later. **This is the strongest recommendation in this doc.** Every effect above becomes a one-liner.

**Option B: Humanoid/physics characters.**
- On the client that owns the character's physics (by default each player owns their own character), cache `HumanoidRootPart.AssemblyLinearVelocity`, then either set `Anchored = true` or zero the velocity every frame for the duration. After the freeze, unanchor and apply the stored velocity (or the server's knockback). Anchoring a network-owned part has side effects (ownership reset, replication of the anchored state) **[unverified: test this]**. Zeroing velocity every `PreSimulation`/`Stepped` step is usually safer.
- Freeze animations: for each playing `AnimationTrack`, call `track:AdjustSpeed(0)`, then restore the previous speed (`track.Speed` is read-only, so cache it first) ([AnimationTrack](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)). The doc marks `Speed` as not replicated. Whether `AdjustSpeed` on the owner's client propagates to other clients is **[unverified]**, so have every client freeze tracks locally on `HitConfirmed` rather than relying on replication.
- Freeze particles attached to the fighter: `ParticleEmitter.TimeScale` exists ([ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)). Set it to 0 during hitstop and to 0.25 during slow-mo. Do **not** freeze the hit spark itself. It should play out during the freeze, which is what makes the freeze read.
- Victim shake during hitstop: offset the character's *visual* model, not the physics root. Use a cosmetic `Motor6D`/`Bone` offset on the root joint, or render a separate visual rig that follows the physics rig. Do `offset = dir * amp * (1 - t/T) * sign(alternating each frame)`, where `dir` is horizontal if grounded and vertical if airborne (Sakurai). Amplitude: light 0.1, medium 0.2, heavy 0.35 studs.

**KO slow-mo:** with Option A, set every fighter's timeScale to 0.25. With Option B, you can only fake it through `AdjustSpeed(0.25)` on all tracks, `TimeScale` on emitters, and scaling velocities, which is messy. Alternatively, make KO slow-mo purely cinematic: freeze gameplay entirely, play a 0.4 s camera + VFX sequence, then resume. Since the victim is already doomed, nobody needs to act during it.

### 2.3 Camera shake and punch

- Use a `Scriptable` camera for 2.5D (a fixed side view that frames all fighters). Compute a **base CFrame** every frame (framing/zoom logic), then add shake and punch as **additive offsets** on top. Never accumulate shake into the base, or the camera drifts.
- Bind with `RunService:BindToRenderStep("FighterCamera", Enum.RenderPriority.Camera.Value + 1, fn)`. `Camera` is priority 200 ([RenderPriority](https://create.roblox.com/docs/reference/engine/enums/RenderPriority)). If we keep the default camera scripts, binding just after them lets us add offsets to their result.

```lua
-- Trauma shake (Eiserloh). Client-only module sketch.
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera
local Shake = { trauma = 0, decay = 1.2, maxOffset = 0.6, maxRoll = math.rad(1.5), scale = 1 } -- scale = settings slider
local t = 0

function Shake.add(amount) Shake.trauma = math.min(1, Shake.trauma + amount) end

RunService:BindToRenderStep("FighterCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	t += dt
	local base = computeBaseCFrame() -- framing logic, our code
	local s = (Shake.trauma ^ 2) * Shake.scale
	local nx = math.noise(t * 25, 0, 1)   -- range ~[-1,1]
	local ny = math.noise(0, t * 25, 2)
	local nr = math.noise(t * 25, 3, 0)
	local offset = CFrame.new(nx * Shake.maxOffset * s, ny * Shake.maxOffset * s, 0)
		* CFrame.Angles(0, 0, nr * Shake.maxRoll * s)
	cam.CFrame = base * punchOffset() * offset -- punchOffset: KO zoom/kick tween
	Shake.trauma = math.max(0, Shake.trauma - Shake.decay * dt)
end)
```

- **Camera punch / KO zoom:** tween the FOV (`Camera.FieldOfView`) down 4–15% (or move the camera closer), with a fast ease-out (0.06–0.1 s) and a slower ease-back (0.25–0.35 s). Direct the punch toward the impact point by lerping the look-at 20–40% toward it.

### 2.4 Hit flash with `Highlight`

- Create one `Highlight` per fighter up front (pooled) and toggle `FillTransparency` instead of creating and destroying it. For a flash: `FillColor = white`, `FillTransparency = 0.2`, `OutlineTransparency = 1`, `DepthMode = Occluded` (or `AlwaysOnTop` if the flash should show through stage pieces). Hold 1–3 frames, then tween to `FillTransparency = 1` over 0.1 s, optionally through a red tint ([Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)).
- Limit: up to 255 Highlights per DataModel now (it was 31 visible on the client). **Disabled Highlights still use a slot**, and every visible highlight adds a draw call and post-processing cost ([DevForum announcement](https://devforum.roblox.com/t/lights-camera-more-highlights/4061534)). With 4 to 8 fighters we are fine.

### 2.5 Particles, Beams, Trails

- **`ParticleEmitter`**: keep emitters disabled (`Enabled = false`) on pooled attachments and fire bursts with `emitter:Emit(n)`. Useful props: `LightEmission` (additive glow), `Brightness`, `Drag` (fast start, quick stop for sparks), `Squash` (stretch streaks), `FlipbookLayout`/`FlipbookMode` (animated spark sheets), `ZOffset` (push in front of characters), `LockedToPart`, `TimeScale` ([ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)).
- **`Trail`**: attach to two Attachments on the fighter's torso. Enable it when knockback speed exceeds a threshold, and drive `WidthScale`/`Transparency` from speed.
- **`Beam`**: use for slash arcs and KO blast columns. Animate `TextureSpeed`/`Width0/Width1` with a tween.
- **Impact frames:** a full-screen `Frame` / `ImageLabel` overlay (black/white burst lines) shown for 1–2 frames, gated by the flash setting. A `ColorCorrectionEffect` on `Lighting` can briefly push contrast/saturation/tint (KO red tint) and is cheap to tween.
- **Pooling:** pre-create spark/dust emitters per fighter at startup. Don't `Instance.new` per hit.

### 2.6 Sound

- **New Audio API (recommended for new work):** `AudioPlayer` → `Wire` → effects → `AudioDeviceOutput` (2D) or → `AudioEmitter` (3D, heard via `AudioListener`). Docs: "Sound, SoundGroup, and SoundEffect objects are now discouraged in favor of the more robust functionality of audio objects" ([Audio objects](https://create.roblox.com/docs/audio/objects)). Available effects: `AudioEqualizer`, `AudioCompressor` (supports ducking), `AudioReverb`, `AudioChorus`, `AudioDistortion`, `AudioEcho`, `AudioFlanger`, `AudioPitchShifter` (pitch without changing speed), `AudioTremolo`, `AudioFader`, `AudioAnalyzer` ([Audio effects](https://create.roblox.com/docs/audio/effects)).
- **Suggested bus layout:** `SFX_Hits` / `SFX_Movement` / `Voice_Announcer` / `Crowd` / `Music` faders → master. Put a compressor on Music side-chained (ducked) by SFX_Hits for heavy/KO hits, and a short reverb send on hits for "arena" space.
- **Pitch variation:** set `AudioPlayer.PlaybackSpeed = 1 + random(-0.08, 0.08)` per play (changes pitch and duration together, which is fine for hits). Use `AudioPitchShifter` for slow-mo world pitch-down.
- **Legacy `Sound`** still works: `PlaybackSpeed` is "not replicated" ([Sound](https://create.roblox.com/docs/reference/engine/classes/Sound)). Sounds played from a LocalScript are heard only by that client, which is exactly what we want for juice. The server should never play hit sounds. Clients play them on prediction/confirm.
- **Responsiveness:** preload (`ContentProvider:PreloadAsync`) all hit/movement audio during the loading screen. Keep a small pool of `AudioPlayer`s per sound so overlapping hits don't cut each other off.

### 2.7 Haptics

**New API: `HapticEffect`** ([class](https://create.roblox.com/docs/reference/engine/classes/HapticEffect), [enum](https://create.roblox.com/docs/reference/engine/enums/HapticEffectType), [announcement](https://devforum.roblox.com/t/3606858)):
- Supported devices: Android/iOS phones with haptics (most iPhone, Pixel, Samsung Galaxy), PlayStation and Xbox gamepads, Quest Touch controllers.
- Announced as a Studio beta on 2025-04-15, moved to client beta for published experiences on 2025-05-22 (per the DevForum thread). The class is in the live API reference. Confirm it's out of beta before relying on it **[unverified: current GA status]**.
- Not supported (as of the announcement): Android 11 and below, macOS 15+ with controllers, mobile devices with a controller attached, PC-VR. Keep fewer than 100 simultaneous effects.
- Types: `Custom` (0), `UIHover`, `UIClick`, `UINotification`, `GameplayExplosion` (high intensity, lingers), `GameplayCollision` ("a large immediate rumble that dies down quickly").
- Properties: `Type`, `Looped`, `Position`, `Radius`. Methods: `Play()`, `Stop()`, `SetWaveformKeys({FloatCurveKey...})` (time in **ms**, intensity 0–1). Event: `Ended`. Effects are parented to `workspace`. Buttons get no-code `PressHapticEffect`/`HoverHapticEffect`.

```lua
-- Pre-build one effect per tier on the client, reuse with :Play()
local function makeCustom(keys)
	local e = Instance.new("HapticEffect")
	e.Type = Enum.HapticEffectType.Custom
	e:SetWaveformKeys(keys)
	e.Parent = workspace
	return e
end

local Haptics = {
	light  = makeCustom({ FloatCurveKey.new(0, 0.25), FloatCurveKey.new(60, 0) }),
	medium = makeCustom({ FloatCurveKey.new(0, 0.5),  FloatCurveKey.new(100, 0) }),
	heavy  = makeCustom({ FloatCurveKey.new(0, 0.85), FloatCurveKey.new(60, 0.5), FloatCurveKey.new(180, 0) }),
	ko     = makeCustom({ FloatCurveKey.new(0, 1.0),  FloatCurveKey.new(80, 0.6), FloatCurveKey.new(200, 0.3), FloatCurveKey.new(300, 0) }),
}
-- FloatCurveKey.new(time, value[, interpolation]) -- check signature in Studio autocomplete
```

**Legacy fallback: `HapticService:SetMotor(UserInputType.GamepadN, VibrationMotor.Large/Small, 0..1)`** ([HapticService](https://create.roblox.com/docs/reference/engine/classes/HapticService)). It is gamepad-only and the docs mark the class **deprecated**. You must set the motor back to 0 yourself (`task.delay(duration, ...)`). Check `IsVibrationSupported` / `IsMotorSupported` first. Starting values: light Small 0.3 for 60 ms; medium Small 0.5 + Large 0.3 for 100 ms; heavy Large 0.8 for 180 ms; KO Large 1.0 for 300 ms with a step-down to 0.4 at 150 ms.

### 2.8 Mobile specifics

- Touch players already have weaker feedback (no rumble on older Android, small screen). Lean harder on sound and the damage-% UI pop, and keep shake lower on phones, where a small screen makes shake feel bigger. Default the shake scale to about 0.6 on touch devices **[our recommendation]**.
- Particle budgets: keep per-hit bursts ≤30 particles on mobile and scale them with a graphics-quality check (`UserSettings().GameSettings.SavedQualityLevel`, or our own Low/High toggle).

### 2.9 Asset sourcing and licensing

- **2022 audio privacy change:** from 22 March 2022, all newly uploaded audio is private by default and existing user audio longer than 6 s was made private. Only the owner (or experiences/creators they grant permission to) can use it ([DevForum: Upcoming Changes to Asset Privacy for Audio](https://devforum.roblox.com/t/1701697); [ProGameGuides summary](https://progameguides.com/roblox/roblox-to-private-millions-of-user-created-sounds-within-its-audio-database/)). In practice, random sound IDs found online often won't play in our game.
- **Upload rules today:** .mp3/.ogg/.wav/.flac, <20 MB, ≤7 min, ≤48 kHz. Quota: 2,000 uploads per 30 days for ID-verified accounts, 100 for unverified. New uploads are private, and permissions can be granted to specific experiences. You must hold the rights to what you upload ([Audio assets](https://create.roblox.com/docs/audio/assets)). **Upload team audio under the group that owns the game** so all collaborators can use it.
- **Free licensed library:** Roblox provides "more than 100,000 professionally-produced sound effects and music tracks" free to use, found in the Toolbox → Creator Store tab (partners include APM, Monstercat, Pro Sound Effects, per the 2022 announcement) ([Audio assets](https://create.roblox.com/docs/audio/assets)). That is a good source for impact, whoosh, crowd and explosion layers.
- **Own or CC0 sounds:** record or synthesize our own (e.g. sfxr/jsfxr-style generators, layered foley), or use CC0 packs (Kenney, Sonniss GDC bundles [unverified: license terms per bundle]). Do **not** rip Smash, anime or meme-video audio. Brainrot meme voice lines are often clipped from copyrighted videos or TikToks, so re-record original lines in that style.
- **VFX textures:** make our own spark/smoke flipbooks or use Creator Store assets (check each asset's creator and any scripts inside before inserting).

---

## Implementation checklist (suggested order)

1. `FeelConfig` module: the tier table above as data, plus the settings scales (shake, flash, rumble, slow-mo).
2. Per-fighter `timeScale` in the character controller (hitstop + slow-mo).
3. `HitFeel.play(tier, contactPos, dir, isKO, role)` on the client: spark, sound, hitstop, victim shake, flash, rumble, camera trauma, UI pop.
4. Trauma camera shake + punch/zoom in the camera module.
5. Audio buses + 3-layer hit sounds with pitch variation, plus music ducking.
6. HapticEffect tiers (with a SetMotor fallback if HapticEffect is unavailable).
7. Movement dust, squash/stretch, landing/jump sounds.
8. KO sequence (zoom, slow-mo, tint, sting, blast column) and the Finish-Zoom variant for the final KO.
9. Accessibility settings menu + competitive preset, and a flash-rate limiter.
10. Playtest: record clips at 60 fps and step through frame by frame to check hitstop length and flash counts.

---

## Sources

**Game-feel theory and talks**
- Jan Willem Nijman (Vlambeer), "The Art of Screenshake", INDIGO 2013: https://www.youtube.com/watch?v=AJdEqssNZ-U ; listed at https://kenney.nl/learn/must-see-videos-for-indie-developers
- Squirrel Eiserloh, "Math for Game Programmers: Juicing Your Cameras With Math", GDC 2016: https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math ; trauma-shake implementation example: https://bevy.org/examples/camera/2d-screen-shake/
- Martin Jonasson & Petri Purho, "Juice It or Lose It" (2012): https://www.gamedeveloper.com/design/video-is-your-game-juicy-enough-
- Steve Swink, *Game Feel* (2008): https://en.wikipedia.org/wiki/Game_feel ; review: https://lizengland.com/blog/review-game-feel-by-steve-swink/
- Masahiro Sakurai, "Eight Hit Stop Techniques": https://www.youtube.com/watch?v=tycbMSjDDLg ; summary: https://nintendowire.com/news/2022/12/12/this-week-in-sakurai-12-5-12-11-fine-tuning-hit-stop-and-cheating-the-system/ ; channel launch / "Stop for Big Moments!": https://automaton-media.com/en/news/20220824-15208/
- critpoints, "Hitstop/Hitfreeze/Hitlag/Hitpause/Hitshit": https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/

**Fighting-game data**
- SmashWiki, Hitlag: https://www.ssbwiki.com/Hitlag
- SmashWiki, Special Zoom / Finish Zoom: https://www.ssbwiki.com/Finish_Zoom
- SRK wiki, KOF XIII hitstun/blockstun: https://srk.shib.live/w/The_King_of_Fighters_XIII/Character_States/Hitstun_Blockstun_state
- SRK wiki, SF6 game data: https://srk.shib.live/w/Street_Fighter_6/Game_Data

**Accessibility**
- WCAG 2.1 SC 2.3.1, Three Flashes or Below Threshold: https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold
- Xbox Accessibility Guideline 117: https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/117

**Roblox docs and announcements**
- HapticEffect: https://create.roblox.com/docs/reference/engine/classes/HapticEffect
- HapticEffectType: https://create.roblox.com/docs/reference/engine/enums/HapticEffectType
- Haptics announcement (DevForum): https://devforum.roblox.com/t/3606858
- HapticService (deprecated): https://create.roblox.com/docs/reference/engine/classes/HapticService
- VibrationMotor: https://create.roblox.com/docs/reference/engine/enums/VibrationMotor
- Audio objects: https://create.roblox.com/docs/audio/objects
- Audio effects: https://create.roblox.com/docs/audio/effects
- Audio assets (upload limits, licensed library): https://create.roblox.com/docs/audio/assets
- Sound: https://create.roblox.com/docs/reference/engine/classes/Sound
- Audio privacy change (2022): https://devforum.roblox.com/t/1701697 ; https://progameguides.com/roblox/roblox-to-private-millions-of-user-created-sounds-within-its-audio-database/
- Highlight: https://create.roblox.com/docs/reference/engine/classes/Highlight ; limit raised to 255: https://devforum.roblox.com/t/lights-camera-more-highlights/4061534
- AnimationTrack: https://create.roblox.com/docs/reference/engine/classes/AnimationTrack
- ParticleEmitter: https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter
- RunService: https://create.roblox.com/docs/reference/engine/classes/RunService ; RenderPriority: https://create.roblox.com/docs/reference/engine/enums/RenderPriority
- UnreliableRemoteEvent: https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent
