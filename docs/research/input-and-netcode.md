# Input & Online Feel: Cross-Platform Controls and Netcode for Our Roblox Platform Fighter

Research date: 2026-10-05. Scope: controls on keyboard/mouse, gamepad (Xbox, PlayStation, Roblox on console) and mobile touch, the Roblox input APIs, and how to make a server-authoritative Roblox game feel responsive. The physics/mechanics math is covered in a separate report.

Claims marked **[unverified]** come from community sources or memory and were not confirmed against official docs. Roblox APIs change often, so recheck the linked doc pages before relying on details.

---

## Top takeaways for our game

1. **Build the input layer on Roblox's Input Action System (IAS).** It is released (only the *InputActionLabel* and *Input Action Manager* Studio tools are still beta), and Roblox's input docs now point to it first ([IAS docs](https://create.roblox.com/docs/input/input-action-system), [Input overview](https://create.roblox.com/docs/input)). Roblox's Server Authority mode *requires* `Workspace.PlayerScriptsUseInputActionSystem`, so IAS keeps that option open for later ([Server authority](https://create.roblox.com/docs/projects/server-authority)).
2. **Don't read keys in gameplay code. Turn raw input into a per-frame "intent" record:** move vector, buttons pressed/held/released, and derived flags such as `isSmash`, `attackDir`, `specialDir`. The fighter state machine reads only that record. Each device gets its own small adapter, and the same record is what goes over the network.
3. **Use the Smash numbers for tilt vs smash on controller.** In Ultimate, a tilt needs stick ≥ ~20/80 (≈0.25), a smash needs stick ≥ ~56/80 (≈0.70), and attack must be pressed within about 4-6 frames of the flick ([SmashBoards stick sensitivity](https://smashboards.com/threads/all-about-stick-sensitivity.466696/), [SSBWiki Controls](https://www.ssbwiki.com/Controls)). Map the right stick to "smash stick" by default and make it switchable to tilt, special or off, like Smash and Rivals do.
4. **On keyboard, give players a dedicated Strong/Smash key** (Rivals of Aether's "Strong" button; [Rivals controls](https://wiki.gbl.gg/w/Rivals_Of_Aether/Controls)). Add an optional "double-tap direction + Attack = smash" rule for players who want it. Holding the Smash key charges the attack.
5. **Mobile layout: floating joystick on the left, five big buttons on the right (Attack, Special, Jump, Shield, Grab).** Attack and Special take their direction from the joystick. Smashes come from a **swipe or drag starting on the Attack button**, like Brawl Stars' "tap = auto, drag = aim" ([Brawl Stars controls guide](https://ar-pay.com/blog/en/articles/brawl-stars/)). Holding charges the smash. Let players move and resize every button; Brawlhalla Mobile's default layout was criticized as badly positioned, and reviewers say the touch buttons felt unresponsive ([TapTap review](https://www.taptap.io/th/post/1763892), [PocketGamer review](https://ee.pocketgamer.com/articles/084083/brawlhalla-review-a-mobile-port-done-right/)).
6. **Turn off all default Roblox character control.** Use `DevTouchMovementMode = Scriptable` (and the computer equivalent) and/or `PlayerModule:GetControls():Disable()`, hide the default touch UI and the backpack, and drive the character with our own 2.5D controller ([DevTouchMovementMode](https://create.roblox.com/docs/reference/engine/enums/DevTouchMovementMode), [devforum](https://devforum.roblox.com/t/disabling-playercontrols-only-disables-jumping/3677657)). **Never bind** Esc/Start (Roblox menu), ButtonSelect or `\` (UI selection toggle), F9, F11, F12 or PrintScreen ([reserved controls](https://create.roblox.com/docs/input)).
7. **Use `UserInputService.PreferredInput` to switch UI and prompts.** It returns Touch, Gamepad or KeyboardAndMouse and fires a change signal when the player switches device ([Input overview](https://create.roblox.com/docs/input)). Get the right glyphs from `InputActionLabel` or `UserInputService:GetImageForKeyCode()` ([Console guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines)).
8. **Buffer inputs for about 9 frames (150 ms at 60 Hz), matching Smash Ultimate** ([SSBWiki Buffer](https://www.ssbwiki.com/Buffer)). Add hold-buffering for jump and shield. Mobile can use a slightly longer window (10-12 frames) to cover touch latency.
9. **Netcode, near term:** the owning client predicts its own movement and attacks; the server is authoritative for damage, knockback and stocks. Clients detect hits for their *own* attacks and send hit claims; the server validates them against a **position history (rewind buffer)**. Use reliable `RemoteEvent` for game events and `UnreliableRemoteEvent` only for high-frequency cosmetic or state streams (no delivery or order guarantee; payloads over ~900-1000 bytes are dropped) ([Remote events docs](https://create.roblox.com/docs/scripting/events/remote)). Most popular Roblox combat games use client hit detection with server checks ([devforum](https://devforum.roblox.com/t/hitbox-in-client-or-server/3249804)).
10. **Netcode, longer term:** Roblox **Server Authority** (fixed-step 60 Hz simulation, client prediction plus rollback/resimulation, inputs sent through IAS) has been in **Client Beta** since April-May 2026. Desktop works; mobile clients lagged behind at launch, and Roblox says to publish privately or as an Experience Beta until it leaves beta ([announcement](https://devforum.roblox.com/t/client-beta-publish-test-your-server-authoritative-experiences/4606949)). This is the best long-term fit for a platform fighter. Write the core sim as **deterministic, fixed-step, input-driven code** now (`RunService:BindToSimulation`, which is fully released) so we can move to it later.
11. **Roblox's default replication of other players is slow and smoothed:** physics is reportedly replicated at about 15-20 Hz, behind an interpolation delay we can't configure [unverified, community measurements] ([devforum](https://devforum.roblox.com/t/allow-game-developers-to-configure-the-physics-replication-rate-for-their-games/4005498), [Chrono](https://github.com/Parihsz/Chrono)). For a fighter, replicate fighter state ourselves (position, velocity, action ID, action frame) at 30-60 Hz and interpolate with a small buffer that we tune.
12. **Libraries:** ShapecastHitbox or RaycastHitbox (MIT) are melee *sweep* tools. Smash-style games are better served by **our own frame-data hitboxes** (capsules/spheres per active frame, tested with `GetPartBoundsInBox` or plain math). Chickynoid (MIT) shows the full server-authoritative approach but replaces Humanoids entirely and takes a lot of engineering ([Chickynoid](https://github.com/easy-games/chickynoid)).

---

## Recommended default control mapping

Design rules:

- **Tap-jump (jump by pushing up) is OFF by default on every device and can be toggled.** Up-specials and up-tilts must never cause accidental jumps. Smash Ultimate exposes this as "Stick Jump" ([SSBWiki Controls](https://www.ssbwiki.com/Controls)), and MultiVersus shipped without it on controller and players asked for it ([Dot Esports](https://dotesports.com/fgc/news/multiversus-controls-guide-for-playstation-xbox-and-pc)).
- **Disable the Roblox backpack/tool system** so L1/R1/R2 and the 0-9 keys are no longer reserved ([Input overview](https://create.roblox.com/docs/input)).

| Action | Keyboard (+ mouse) | Controller (Xbox / PlayStation) | Mobile touch |
|---|---|---|---|
| Move left/right | A / D (alt: Arrow keys) | Left stick (D-pad also works) | Floating virtual joystick, left half of screen |
| Up / down direction (aim, crouch, fast-fall, drop through platform) | W / S | Left stick up/down | Joystick up/down (fast-fall = flick down while airborne) |
| Jump / double jump | Space (alt: W only if tap-jump is on) | A / Cross **and** Y / Triangle | Jump button (large, right cluster). Short hop = quick tap (<~4 frames) |
| Attack (jab / tilts / aerials by direction) | J (alt: Left mouse) | X / Square | Attack button: tap uses the joystick direction |
| Smash attack (charge by holding) | L ("Strong" key) + direction; optional double-tap direction + J | Right stick flick (default "smash stick"), or left-stick flick + Attack (≥0.70 within ~5 frames) | **Swipe or drag from the Attack button** in a direction; hold at the end of the swipe to charge. Alt: joystick flick + Attack |
| Special (neutral / side / up / down) | K (alt: Right mouse) + direction | B / Circle + left stick | Special button: tap uses the joystick direction; **drag from the button** to pick a direction (Brawl-Stars style) |
| Shield (hold) | Left Shift or I (alt: Mouse 4) | RT/R2 **and** LT/L2 (hold) | Shield button (hold); "toggle shield" option |
| Dodge / roll / air dodge | Shield + direction (alt: dedicated dodge key O) | Shield + left stick (alt: right stick set to "dodge") | Shield + joystick, or **swipe from the Shield button** |
| Grab | U (alt: Middle mouse / E) | RB/R1 **and** LB/L1 | Grab button (smaller), or Shield + Attack |
| Taunt / emote | 1-4 | D-pad | Hidden by default (accessible from pause) |
| Pause / settings | **Esc is Roblox's own menu.** Use P or Tab-free key for our in-game menu | **Start is reserved** for the Roblox menu. Our menu: hold D-pad down or a pause icon | Pause icon (top corner, inside safe area) |

Notes on the table:

- Two buttons for jump, shield and grab on controller follows Smash's default (X and Y jump; ZL/ZR shield; L/R grab). Players can jump without letting go of the attack button. Roblox's gamepad docs treat ButtonA as "jump" and ButtonB as secondary or cancel, so we stay close to that ([Gamepad input](https://create.roblox.com/docs/input/gamepad)).
- MultiVersus's defaults (X Attack, Y Special, A Jump, B/RT Dodge, with RB/LB as dedicated neutral attack and neutral special) are a good reference for a "Brawlhalla-like" preset we could also offer ([Dot Esports](https://dotesports.com/fgc/news/multiversus-controls-guide-for-playstation-xbox-and-pc)).
- **Keyboard presets** to ship:
  - (a) **"Keyboard only"** (table above, WASD + JKL;UI).
  - (b) **"Keyboard + mouse"**: WASD, LMB Attack, RMB Special, MMB Grab, Shift Shield. This matches Brawlhalla's default (LMB light, RMB heavy, MMB throw, Shift dodge; [Steam discussion](https://steamcommunity.com/app/291550/discussions/0/3393916911752811349)).
  - (c) **"Arrows"**: Arrow keys + Z/X/C/A/S, for left-handed players and laptop users.

---

## Part 1 - Control schemes in existing games

### Super Smash Bros. Ultimate (controller)

- **Buttons:** one Attack button and one Special button, with direction coming from the left stick, so the whole moveset fits on two buttons. Jump has two buttons, shield is on the triggers, grab on the shoulders, and the right stick is the "C-stick", which does smash attacks on the ground and aerials in the air ([SSBWiki Controls](https://www.ssbwiki.com/Controls)).
- **Tilt vs smash:**
  - A tilt starts at stick value ~20 (of ~80).
  - A smash needs ~56, *and* attack must be pressed within a short "stick flick" window after the stick crosses the threshold.
  - The "Stick Sensitivity" option shifts that window by ±1 frame. Forward smash gets 5/6/7 frames (low/normal/high) and up/down smash get 3/4/5 frames.
  - Press too late after a forward tap and you get a dash attack instead.
  - Sources: [SmashBoards](https://smashboards.com/threads/all-about-stick-sensitivity.466696/), [SSBWiki Controls](https://www.ssbwiki.com/Controls).
- **Options:** Stick Jump (tap jump) on/off, A+B smash on/off, rumble, stick sensitivity, and full per-button remapping ([iMore](https://www.imore.com/here-are-all-controller-options-super-smash-bros-ultimate)).
- **Buffer:** 9-frame press buffer, plus hold-buffering (keep holding and the action comes out on the first frame it's allowed) ([SSBWiki Buffer](https://www.ssbwiki.com/Buffer)).

### Rivals of Aether (keyboard + controller)

- **Buttons:** Attack, **Strong**, Special, Jump, Dodge (parry/roll/airdodge). Strong attacks (Rivals' smash attacks) have their own button, which is ideal for keyboard.
- **Right stick:** can be set to Tilt stick (tilts on ground, aerials in air), Strong stick, or Special. On keyboard the right stick becomes four "C-stick buttons" (up/down/left/right).
- Source: [Rivals controls](https://wiki.gbl.gg/w/Rivals_Of_Aether/Controls).
- **Takeaway:** offer "smash stick / tilt stick / special stick" as a right-stick option, and offer four optional "C-keys" on keyboard.

### Brawlhalla (keyboard, controller, mobile)

- **Model:** Light attack, Heavy attack (signature), Throw/pickup, Dodge. Direction comes from movement keys, and there is no smash/tilt split, which keeps the scheme simple. Keyboard defaults are WASD + LMB light, RMB heavy, MMB throw, Shift dodge, with keyboard-only presets such as J/K/H/L ([Steam](https://steamcommunity.com/app/291550/discussions/0/3393916911752811349)).
- **Mobile:**
  - On-screen virtual buttons, fully repositionable by dragging, plus controller support ([Ubisoft](https://news.ubisoft.com/en-us/article/1kyM6xMlvLXtYa0un5XpKN/brawlhalla-now-available-on-mobile)).
  - Reviewers called the default touch layout "horrendously positioned" ([TapTap](https://www.taptap.io/th/post/1763892)) and reported "misclicks, poorly timed attacks" and "less-than-responsive virtual buttons". They also noted that with a controller "the gameplay is indistinguishable from consoles" ([PocketGamer](https://ee.pocketgamer.com/articles/084083/brawlhalla-review-a-mobile-port-done-right/)).
  - **Takeaway:** spend design time on the default touch layout itself, not only on customization, and fully support Bluetooth controllers on mobile (Roblox handles this; `PreferredInput` switches to Gamepad).

### MultiVersus

- **Defaults:**
  - Controller: X Attack, Y Special, A Jump, B/RT Dodge, RB Neutral Attack, LB Neutral Special.
  - Keyboard: WASD, J/LMB Attack, K/RMB Special, L/MMB Dodge, Space Jump, U/I/O neutral attack, special and evade.
- **Notable:** dedicated "neutral attack/special" buttons, so players don't have to let go of the stick to get the neutral move. That's useful on keyboard and mobile, where players are often still holding a direction.
- **Lesson:** tap-jump was missing on controller at launch while keyboard had it, and players noticed the mismatch ([Dot Esports](https://dotesports.com/fgc/news/multiversus-controls-guide-for-playstation-xbox-and-pc)).
- **Takeaway:** consider a **"Neutral" modifier** (or dedicated neutral-attack/neutral-special bindings) as an optional binding.

### Mobile fighters and touch patterns

| Game / pattern | How attacks and specials map to touch | What works / complaints |
|---|---|---|
| Marvel Contest of Champions | Tap right side = light, swipe right = medium, hold right = heavy (charge), hold left = block, swipe left side = dash back, tap power bar = special ([fandom wiki](https://marvel-contestofchampions.fandom.com/wiki/Terminology), [Law of Game Design](https://lawofgamedesign.com/tag/contest-of-champions/)) | Gesture-only, no buttons: very approachable, but it only works for a 1-plane, 1v1 game with no platforming. |
| Mortal Kombat X mobile | Tap/swipe gestures | Critics complained it was **oversimplified** ([Carleton paper](https://www.csit.carleton.ca/~rteather/pdfs/ec2017.pdf)). |
| Brawl Stars | Move stick + Attack button + Super button. **Tap = auto-aim at nearest target, drag = manual aim** ([guide](https://ar-pay.com/blog/en/articles/brawl-stars/)) | Widely praised. The "tap auto / drag aim" split is the best model for adding direction to a button on touch. |
| The Strongest Battlegrounds (Roblox) | Joystick + attack button + skill buttons (1-4) + block, dash, ultimate; PC uses M1, 1-4, F block, Q dash ([PC Invasion](https://pcinvasion.com/all-controls-in-roblox-the-strongest-battlegrounds-listed)) | Battlegrounds games avoid directional inputs and use **one button per move**. Easy on touch, but not Smash-like. |
| Street Fighter 6 "Modern" | One Special button + direction, plus an Assist button that auto-combos; modern specials do less damage ([Red Bull](https://www.redbull.com/us-en/street-fighter-6-modern-vs-classic-controls)) | Shows the "simple mode with a small trade-off" approach. We don't need it, because Smash-style controls are already Special + direction. |

General touch problems (academic and dev sources):

- No tactile feedback.
- Thumbs slide off the virtual stick.
- Can't use face buttons while steering.
- Controls cover part of the screen.

Mitigations:

- **Floating joystick** whose origin is wherever the thumb first lands, limited to a zone.
- Large hit areas.
- Haptics on press.

Sources: [Carleton paper](https://www.csit.carleton.ca/~rteather/pdfs/ec2017.pdf), [Phaser joystick article](https://phaser.io/news/2025/12/i-built-the-best-virtual-joystick-for-phaserjs).

### Recommended per-device design details

#### Controller

- **Left stick processing:**
  - Radial deadzone ~0.20-0.25, rescaled so 0.25→0 and 1.0→1.0.
  - Classify direction into 8 sectors, with **cardinal priority**: up/down/side wedges of about ±35-40° around each axis, so diagonals map to the intended tilt.
  - Treat magnitude ≥0.25 as "tilt range" and ≥0.70 as "smash range". Expose these thresholds in an advanced settings menu. Community scripts often use 0.2 as the deadzone ([devforum](https://devforum.roblox.com/t/detecting-when-a-controllers-thumbstick-is-held-not-just-pressed/4030987)).
- **Smash flick detection:**
  - Store the frame when the stick last went from < 0.25 to ≥ 0.70.
  - If Attack is pressed within **N = 5 frames** (setting: 4/5/6), it's a smash; otherwise it's a tilt.
  - If the stick was already past 0.70 for longer than N frames when Attack is pressed, it's a tilt (or a dash attack while running).
- **Right stick:** default = smash stick (instant smash in that direction; aerial in the air). Options: Tilt stick / Special stick / Dodge stick / Off.
- **Stick drift:** at least one devforum thread reports drift showing up in `GetGamepadState` ([devforum](https://devforum.roblox.com/t/roblox-stick-drift-bug/4450291)). Apply our own deadzone regardless.
- **Haptics:** a light rumble on hit/shield-break via `HapticEffect`. Don't overuse it; the console guidelines warn about this explicitly ([Console guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines)).

#### Keyboard

- **Problem:** digital directions, so analog tilt vs smash doesn't exist.
- **Solution:** a dedicated Strong/Smash key (default L), as in Rivals. Optional "double-tap direction then Attack within 6 frames = smash" (off by default, because it collides with dash-on-double-tap).
- **Neutral and diagonals:**
  - A held direction plus Attack gives a tilt; no direction gives a jab.
  - Up+side together gives up-tilt (up priority), matching common platform-fighter keyboard conventions [unverified].
  - Use SOCD "last input wins" for left+right, which keyboard and hitbox players expect [unverified convention].
- **Mouse:** optional "aim specials toward cursor". Leave this off for parity, since it would give mouse users 360° aim that gamepad and touch players don't have.

#### Mobile

- **Left half: floating joystick.**
  - Origin is wherever the thumb first lands. The knob follows the finger and the base drags along once the finger passes the radius.
  - Deadzone about 15% of the radius, smash threshold about 80%.
  - **Joystick-flick smash:** the same N-frame rule as controller, with N = 6.
- **Right cluster:** Attack (largest, at the thumb's resting spot), Jump (large, below/right), Special (large, above/left of Attack), Shield (medium), Grab (small). Minimum hit target of about 44 pt / ~9 mm, from general mobile HIG guidance (Apple HIG 44 pt) [unverified for Roblox specifically]. Scale with `GuiService.ViewportDisplaySize`.
- **Swipe-on-button for smash and special direction:**
  - The press starts on the Attack button. If the finger travels more than ~30 px within ~150 ms, it's a smash in that direction; if it's held, the smash charges.
  - A plain tap is a jab or tilt, with direction from the joystick.
  - Special uses the same rule (drag = choose a direction), so players can do up-special without moving the joystick, which matters when recovering.
  - This mirrors Brawl Stars' drag-to-aim, which mobile players already know.
- **Optional "Assist" layout:**
  - Attack auto-faces the nearest opponent when the joystick is neutral.
  - Separate one-tap Up-Special "recover" button.
  - Show it as a choice on first launch, never forced.
- **Customization (required):** drag to reposition, resize, change opacity, per-button haptics on/off, swap left/right handedness, reset to default. Save these with the player's settings in DataStore.
- **Multi-touch:** track each touch by its `InputObject` identity. Joystick ownership locks to the first touch that started in the left zone; buttons track their own touches. Never use the "last touch" as the joystick.

#### Accessibility and remapping (all devices)

- Full rebinding per device. Store a device → action → binding table in player settings. IAS bindings can be rewritten at runtime by changing an `InputBinding`'s `KeyCode` [unverified that runtime changes take effect immediately; test].
- Toggles:
  - Tap-jump on/off.
  - Shield hold vs toggle.
  - Smash stick mode.
  - A+B smash (Attack+Special together = smash).
  - Flick sensitivity (N frames).
  - Short-hop macro (Jump+Attack together = short-hop aerial).
  - Auto-charge off.
  - Larger touch buttons.
  - Reduce screen shake/flash.
- Show bindings in UI with the right glyph per device (see Part 2).

#### Input buffering per device

- **Universal:** a 9-frame (150 ms) press buffer for attack, special, jump, shield and grab. Hold-buffering for shield and jump.
- **Direction lookback:** at the moment Attack/Special is pressed, use the stick direction from **up to 2-3 frames later** if the stick was still moving toward a direction ("late direction" leniency). This is common in platform fighters [unverified as a specific Smash mechanic]. It helps with the timing gap between the stick and the button.
- **Mobile:** extend the buffer to about 11 frames and the flick window to about 6 frames. Touch screens commonly add 30-80 ms of input latency [unverified general figure].
- **Online:** the buffer runs on the client in the prediction loop. Inputs are already resolved into intents (e.g. "fsmash pressed this frame") before they are sent.

---

## Part 2 - Roblox implementation

### Which input API?

| API | Status | Use for our game |
|---|---|---|
| **Input Action System** (`InputContext` → `InputAction` → `InputBinding`) | Released; *InputActionLabel* and *Input Action Manager* plugin are Beta ([docs](https://create.roblox.com/docs/input/input-action-system)) | **Primary.** Separate contexts for `Gameplay`, `Menu` and `Rebind`, using `Priority` and `Sink` so menus swallow gameplay input. Action types: `Bool` (Attack, Special, Jump, Shield, Grab, Smash), `Direction2D` (Move, SmashStick). `InputBinding` exposes `KeyCode`, `UIButton` (touch GuiButton), `Up/Down/Left/Right` composite keys, `PressedThreshold`/`ReleasedThreshold`, `Scale`, `ResponseCurve`, `Vector2Scale`, `ClampMagnitudeToOne`, `PrimaryModifier`/`SecondaryModifier`, `PointerIndex` ([InputBinding](https://create.roblox.com/docs/reference/engine/classes/InputBinding)). `InputAction` exposes `Pressed`, `Released`, `StateChanged`, `GetState()`, `PreferredBinding`. **`InputAction:Fire()` is Deprecated** ([InputAction](https://create.roblox.com/docs/reference/engine/classes/InputAction)), so plan how a custom-drawn joystick feeds the Move action [unverified: check whether a `UIButton`/`PointerIndex` binding can drive a Direction2D, otherwise read touch via UIS for the joystick]. |
| **UserInputService** | Stable | Device detection (`PreferredInput`), raw touch tracking for the floating joystick and swipe gestures (`TouchStarted/Moved/Ended`, `InputBegan/Changed/Ended`), `GetImageForKeyCode`/`GetStringForKeyCode` for glyphs. |
| **ContextActionService** | Stable, older | `BindAction(name, fn, createTouchButton, ...)` auto-creates touch buttons, which can be customized with `SetPosition/SetImage/SetTitle/GetButton` ([CAS](https://create.roblox.com/docs/reference/engine/classes/ContextActionService)). The default buttons are small and cluster in a fixed area [unverified]. **Not recommended:** draw our own ScreenGui buttons instead (full control over size, layout and multi-touch). CAS priority/sink is now covered by IAS contexts. |

Do the timing-sensitive classification (flick windows, buffers) **in our own fixed-step loop**, reading action states each step, not in event callbacks. That makes it frame-exact and later replayable under Server Authority. Use `RunService:BindToSimulation` / `UseFixedSimulation`, which are fully released as of April 2026 ([creation.dev summary](https://www.creation.dev/learn/roblox-adaptive-animation-bindsimulation-server-authority-april-2026)).

### Detecting the active device

- **`UserInputService.PreferredInput`** returns `Enum.PreferredInput.Touch | Gamepad | KeyboardAndMouse`. It updates from the hardware present and the player's most recent gamepad/KBM interaction. Listen with `GetPropertyChangedSignal("PreferredInput")` ([Input overview](https://create.roblox.com/docs/input)). This is the recommended replacement for combining `TouchEnabled`, `GamepadEnabled`, `KeyboardEnabled` and `GetLastInputType()` by hand.
- When the value changes:
  - Show or hide the touch HUD.
  - Swap prompt glyphs.
  - Switch menus between gamepad selection mode and mouse mode.
- Touch users with a Bluetooth pad automatically become `Gamepad`, so hide the touch buttons for them.

### Per-device UI prompts

- `InputActionLabel` (beta) shows the current binding's glyph automatically. Alternatively use `UserInputService:GetImageForKeyCode(keyCode)` (Xbox vs PlayStation art) and `GetStringForKeyCode` (keyboard layout aware, e.g. AZERTY) ([Console guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines)).
- Never hard-code "Press X". Read the glyph from the binding.

### Custom mobile buttons and disabling default controls

1. **Movement and jump:**
   - Set `StarterPlayer.DevTouchMovementMode = Scriptable` and `DevComputerMovementMode = Scriptable`.
   - Call `require(PlayerScripts.PlayerModule):GetControls():Disable()` ([DevTouchMovementMode](https://create.roblox.com/docs/reference/engine/enums/DevTouchMovementMode), [devforum](https://devforum.roblox.com/t/disabling-playercontrols-only-disables-jumping/3677657)).
   - Note: `ControlModule:Disable()` also stops `GetMoveVector()`, which is fine because we read IAS/UIS ourselves.
   - Alternatively, fork the PlayerModule into `StarterPlayerScripts`.
   - **Caveat:** Server Authority's default-character flow expects the stock IAS-based PlayerScripts ([Server authority](https://create.roblox.com/docs/projects/server-authority)). A full custom controller there means writing our own `BindToSimulation` movement, which we want anyway.
2. **Touch UI:** `GuiService.TouchControlsEnabled` controls the default touch controls ([GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)). Setting it false from a LocalScript hides the default thumbstick and jump button [unverified: confirm it is writable at runtime in current builds].
3. **Core GUI:** `StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)` frees 0-9, L1/R1 and R2. Consider also disabling PlayerList (Tab) during matches ([Disable default UI](https://create.roblox.com/docs/players/disable-ui)).
4. **Camera:** scriptable camera (`CameraType = Scriptable`) tracking both fighters on a fixed 2.5D plane. Thumbstick2 isn't needed for camera, so it's free to be the smash stick.
5. **Humanoid:** most custom 2.5D fighters either keep a Humanoid but set `PlatformStand`/state control and drive velocity themselves, or drop the Humanoid and use an `AnimationController`. The mechanics report covers this choice. For input it only matters that nothing in default Roblox moves the character.
6. **Orientation:** lock to landscape (`StarterGui.ScreenOrientation = LandscapeSensor`) ([Mobile input](https://create.roblox.com/docs/input/mobile)).

### Console requirements and guidelines

From [Console guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines):

- **Navigation:**
  - Every UI element must be reachable with 4 directions + select + back.
  - Use Roblox's built-in directional selection (`GuiService.SelectedObject`, `GuiService:Select(parent)`, `AutoSelectGuiEnabled`, `GuiNavigationEnabled`, `NextSelectionUp/Down/Left/Right`) or a bespoke scheme.
  - When a menu opens on gamepad, set `GuiService.SelectedObject` to its first button. Clear it (`nil`) when returning to gameplay, otherwise the A button gets eaten by UI selection.
- **Layout:** design for the 10-foot view. Use relative sizes, keep UI in the **TV-safe area**, and scale with `GuiService.ViewportDisplaySize` (Large = TV).
- **Prompts and chat:** show Xbox/PlayStation-correct glyphs. **Disable the chat window on console.**
- **Haptics:** use them for big moments, not constantly.
- **Release requirements:** fill in content maturity information or risk removal from consoles. Keep the number of steps to key actions low (e.g. rematch should be one button).
- **No keyboard-only UI:** no text-entry-only flows, no hover-only tooltips, no "Press Esc" text. Start and ButtonSelect are reserved ([Input overview](https://create.roblox.com/docs/input)).

---

## Part 3 - Online responsiveness on Roblox

### Platform facts

- **Default model:** the server is authoritative for the data model, but each player's character is network-owned by that player's client. Movement is client-simulated and replicated, which is why movement exploits are possible.
- **Replication of physics/characters to others:** reportedly about 15-20 Hz (`DFIntS2PhysicsSenderRate` default 15), with a significant interpolation delay we can't configure [unverified, community measurements] ([devforum](https://devforum.roblox.com/t/allow-game-developers-to-configure-the-physics-replication-rate-for-their-games/4005498), [Chrono](https://github.com/Parihsz/Chrono)). Result: opponents appear roughly 100-250 ms behind real time on top of ping [unverified estimate].
- **RemoteEvent:** reliable and ordered, with a shared per-remote-type client→server rate limit.
- **UnreliableRemoteEvent:**
  - No delivery or order guarantee.
  - Payloads over ~1000 bytes are dropped (the class page says 900).
  - Excess client fires are **dropped, not queued**.
  - Messages with no connected handler are discarded.
  - Use it for "data that changes continuously or isn't critical" ([Remote events](https://create.roblox.com/docs/scripting/events/remote), [class ref](https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent)).
- **Time sync:** `workspace:GetServerTimeNow()` provides a shared clock for timestamps.
- **Server Authority (Client Beta, 2026):**
  - Enabled with `Workspace.AuthorityMode = Server`, which turns on NextGenerationReplication, `PlayerScriptsUseInputActionSystem`, Deferred signals, `UseFixedSimulation` and StreamingEnabled.
  - Clients predict, the server is authoritative, and mispredictions trigger rollback and resimulation.
  - Game logic runs in `RunService:BindToSimulation` and reads `InputAction` state for all players on both client and server.
  - Custom state goes in attributes (64/instance, short strings), and mismatches trigger a resim.
  - `RunService:SetPredictionMode()` controls which instances are predicted.
  - Limitations at Client Beta: up to 8 animation tracks per Animator, no animation graphs, mobile clients lagging at launch.
  - Roblox advises a private or Experience Beta publish until full release.
  - Sources: [docs](https://create.roblox.com/docs/projects/server-authority), [announcement](https://devforum.roblox.com/t/client-beta-publish-test-your-server-authoritative-experiences/4606949).
  - A later summary says it is "now available for all creators" ([creation.dev](https://www.creation.dev/learn/roblox-platform-updates-may-3-2026-devex-adaptive-animation-server-authority)) [unverified whether it has left beta as of Oct 2026; check the docs status banner].

### How Roblox combat games do it today

- **Client hitboxes + server validation** is the norm. Experienced devs say "almost every popular game has client hit detection" because server hitboxes make players "hit in front of the character you see" ([devforum](https://devforum.roblox.com/t/hitbox-in-client-or-server/3249804), [devforum](https://devforum.roblox.com/t/should-hitboxes-be-handled-on-the-client-or-server-in-my-pvppve-game/3055838)).
- **Proper validation is more than a distance check.** The client sends an attack timestamp; the server keeps a short **position history** per character, rewinds to that time, and checks the hit, plus cooldown, state, range and timestamp-age caps ([devforum](https://devforum.roblox.com/t/server-sided-hit-detection-with-lag-compensation/3322386), [devforum](https://devforum.roblox.com/t/melee-client-lag-compensation/1211822)). A rough memory estimate from that thread: 1 s of history for 50 players × 6 limbs is about 200 KB, which is trivial for our 2-8 players.
- **Caveat raised there:** Roblox's own replication buffer means the server's record of "where the victim was on the attacker's screen" is approximate. Our own fighter-state replication (below) fixes this because we control exactly what each client renders.
- **ShapecastHitbox's author** recommends client-side detection for player weapons, lag compensation or bigger hitboxes for server-side NPC hitboxes, and server validation of every client claim ([ShapecastHitbox thread](https://devforum.roblox.com/t/shapecasthitbox-for-all-your-melee-needs-v025/3624241)).

### Libraries

| Library | What it is | License | Pros | Cons for us |
|---|---|---|---|---|
| [RaycastHitbox V4](https://github.com/Swordphin/raycastHitboxRbxl) ([devforum](https://devforum.roblox.com/t/raycast-hitbox-401-for-all-your-melee-needs/374482)) | Raycasts from attachment points on a weapon each frame | MIT | Battle-tested, simple | Built for swinging weapons in 3D. Can't detect stationary hitboxes. Doesn't match the frame-data style. |
| [ShapecastHitbox](https://devforum.roblox.com/t/shapecasthitbox-for-all-your-melee-needs-v025/3624241) (successor, v0.2.5) | Ray/Block/Spherecast sweeps; bones and mesh deformation; companion Shapecast Editor plugin | Open source on GitHub/Wally (license not confirmed) [unverified] | Swept detection, so no tunnelling. Adjustable resolution. | Same as above: fails when the cast starts inside a part, and stationary boxes aren't supported. |
| MuchachoHitbox (by SushiManster) | Spatial-query box hitboxes (`GetPartBoundsInBox`-style) with offsets | [unverified] | Simple, stationary-friendly | Little documentation found. Spatial queries are cheap to write ourselves anyway. |
| [Chickynoid](https://github.com/easy-games/chickynoid) | Full server-authoritative character controller: client prediction + rollback, custom collision, lag-compensated weapons, compressed replication, bots | MIT | Exactly the netcode model a fighter wants. Anti-movement-exploit. | Replaces Humanoids with a fixed box. No physics interaction. "Significant engineering." Roblox's native Server Authority now overlaps with it. |
| [Chrono](https://github.com/Parihsz/Chrono) | Custom CFrame replication with configurable interpolation buffer | MIT | Removes Roblox's fixed interpolation delay; lower bandwidth | Another networking layer to maintain. |

**Recommendation:** write our own hitbox system. Per move, list active frames → set of circles/capsules relative to the fighter, in the 2D plane. Overlap testing is plain math against hurtbox circles/capsules, with no physics queries. It's deterministic, cheap, testable on client and server, and works with rewind and Server Authority later. Use the libraries only as references.

### Recommended architecture for our game

**Phase 1 (ship first, works on all platforms today):**

1. **Fixed-step sim at 60 Hz** on each client (`BindToSimulation`/`UseFixedSimulation`). One function, `simulateFighter(state, intent, dt)`, is shared between client and server in ReplicatedStorage.
2. **Local player:** fully predicted with zero input delay for movement and attack startup. The client sends **input intents** (not positions), sequence-numbered and batched, about 3 frames per packet, with the last 2-3 frames repeated for redundancy. They go over an `UnreliableRemoteEvent` at 20-30 Hz, small enough to fit under 900 bytes, using `buffer`. Discrete edges (e.g. "fsmash released at frame N") are also sent on a reliable RemoteEvent so they're never lost.
3. **Server:** runs the same sim for every fighter from received inputs (server-authoritative movement). If inputs are late, it repeats the last input and corrects later. It keeps a **1-second ring buffer** of each fighter's state (position, action, frame, hurtboxes).
4. **Hits:** the attacker's client detects the hit against the *rendered* (interpolated) victim, plays local hit-stop and spark right away, and sends `HitClaim{attackId, frame, victimId, clientTime}`. The server:
   - Rewinds the victim to `clientTime − interpDelay`.
   - Re-tests the hitbox from its own copy of the attacker's state.
   - Checks: the move is in its active frames, cooldown, the attacker isn't in hitstun, the claim is less than ~250 ms old, a per-move hit limit.
   - If valid, applies damage and knockback and broadcasts reliably.
   - **The server never accepts client damage, knockback or positions.**
5. **Victim side:** when a confirmed hit arrives, the victim's client snaps into hitstun at the server's knockback state and blends position over 2-4 frames. Because knockback is deterministic from (percent, move, angle), the client can resimulate forward to "now" for a smooth correction.
6. **Remote fighters:** replicate a compact state (`x, y, vx, vy, facing, actionId, actionFrame, percent`) at 30 Hz over UnreliableRemoteEvent. Interpolate with an adaptive buffer of about 2 snapshots (~66 ms + jitter), and extrapolate up to ~100 ms on packet loss. Animations play from `actionId/actionFrame`, not from replicated Motor6Ds. Disable or bypass default character physics replication for fighters (anchored visual rigs driven by our state) so the delay is under our control.
7. **Shields and grabs** use the same claim/validate flow. When two players' claims conflict (both hit each other), the server's rewound check decides, and trades are allowed.
8. **Anti-exploit:**
   - Server-side sim means speed/teleport hacks don't work.
   - Rate-limit and validate every remote: types, ranges, sequence numbers.
   - Cap the hit-claim rate per move.
   - Clamp client timestamps to within (ping + 100 ms).
   - Log and kick on repeated invalid claims.
   - No client-authoritative damage, ever.
9. **Feel tricks for latency:**
   - Show the attack immediately and play local hit-stop on claimed hits. If the server rejects a hit, quietly cancel the spark and damage popup.
   - Make hurtboxes a little generous on the victim's side.
   - Matchmake by region/ping; Roblox server region selection is limited [unverified for current APIs].

**Phase 2 (when Roblox Server Authority is out of beta and supports our platforms):** move the same `simulateFighter` into `BindToSimulation` with Server Authority on, read intents from `InputAction` state on both client and server, and let Roblox handle prediction and rollback. Our deterministic, input-driven sim makes this mostly a transport swap. Test mobile and console client support before committing.

---

## Sources

**Roblox official**

- Input Action System: https://create.roblox.com/docs/input/input-action-system
- Input overview (PreferredInput, reserved controls): https://create.roblox.com/docs/input
- InputAction reference: https://create.roblox.com/docs/reference/engine/classes/InputAction
- InputBinding reference: https://create.roblox.com/docs/reference/engine/classes/InputBinding
- Gamepad input: https://create.roblox.com/docs/input/gamepad
- Mobile input: https://create.roblox.com/docs/input/mobile
- Mouse and keyboard: https://create.roblox.com/docs/input/mouse-and-keyboard
- ContextActionService: https://create.roblox.com/docs/reference/engine/classes/ContextActionService
- GuiService: https://create.roblox.com/docs/reference/engine/classes/GuiService
- DevTouchMovementMode: https://create.roblox.com/docs/reference/engine/enums/DevTouchMovementMode
- Disable default UI: https://create.roblox.com/docs/players/disable-ui
- Console guidelines: https://create.roblox.com/docs/production/publishing/console-guidelines
- Remote events and callbacks: https://create.roblox.com/docs/scripting/events/remote
- UnreliableRemoteEvent: https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent
- Server authority model: https://create.roblox.com/docs/projects/server-authority
- PredictionMode enum: https://create.roblox.com/docs/reference/engine/enums/PredictionMode
- Server Authority Client Beta announcement: https://devforum.roblox.com/t/client-beta-publish-test-your-server-authoritative-experiences/4606949

**Roblox community**

- Hitbox client vs server: https://devforum.roblox.com/t/hitbox-in-client-or-server/3249804
- Should hitboxes be client or server: https://devforum.roblox.com/t/should-hitboxes-be-handled-on-the-client-or-server-in-my-pvppve-game/3055838
- Server-side hit detection with lag compensation: https://devforum.roblox.com/t/server-sided-hit-detection-with-lag-compensation/3322386
- Melee client lag compensation: https://devforum.roblox.com/t/melee-client-lag-compensation/1211822
- Physics replication rate request: https://devforum.roblox.com/t/allow-game-developers-to-configure-the-physics-replication-rate-for-their-games/4005498
- Chrono: https://github.com/Parihsz/Chrono
- Chickynoid: https://github.com/easy-games/chickynoid
- RaycastHitbox: https://github.com/Swordphin/raycastHitboxRbxl and https://devforum.roblox.com/t/raycast-hitbox-401-for-all-your-melee-needs/374482
- ShapecastHitbox: https://devforum.roblox.com/t/shapecasthitbox-for-all-your-melee-needs-v025/3624241
- Disabling PlayerControls: https://devforum.roblox.com/t/disabling-playercontrols-only-disables-jumping/3677657
- Thumbstick held detection / deadzone: https://devforum.roblox.com/t/detecting-when-a-controllers-thumbstick-is-held-not-just-pressed/4030987
- Stick drift report: https://devforum.roblox.com/t/roblox-stick-drift-bug/4450291
- creation.dev April 2026 summary: https://www.creation.dev/learn/roblox-adaptive-animation-bindsimulation-server-authority-april-2026
- creation.dev May 2026 summary: https://www.creation.dev/learn/roblox-platform-updates-may-3-2026-devex-adaptive-animation-server-authority

**Other games**

- SSBWiki Controls: https://www.ssbwiki.com/Controls
- SSBWiki Buffer: https://www.ssbwiki.com/Buffer
- SmashBoards, stick sensitivity: https://smashboards.com/threads/all-about-stick-sensitivity.466696/
- iMore, Ultimate controller options: https://www.imore.com/here-are-all-controller-options-super-smash-bros-ultimate
- Rivals of Aether controls: https://wiki.gbl.gg/w/Rivals_Of_Aether/Controls
- Brawlhalla keyboard defaults: https://steamcommunity.com/app/291550/discussions/0/3393916911752811349
- Brawlhalla mobile (Ubisoft): https://news.ubisoft.com/en-us/article/1kyM6xMlvLXtYa0un5XpKN/brawlhalla-now-available-on-mobile
- Brawlhalla mobile review (PocketGamer): https://ee.pocketgamer.com/articles/084083/brawlhalla-review-a-mobile-port-done-right/
- Brawlhalla review (TapTap): https://www.taptap.io/th/post/1763892
- MultiVersus controls: https://dotesports.com/fgc/news/multiversus-controls-guide-for-playstation-xbox-and-pc
- Marvel Contest of Champions terminology: https://marvel-contestofchampions.fandom.com/wiki/Terminology
- Law of Game Design on MCoC: https://lawofgamedesign.com/tag/contest-of-champions/
- Brawl Stars controls: https://ar-pay.com/blog/en/articles/brawl-stars/
- The Strongest Battlegrounds controls: https://pcinvasion.com/all-controls-in-roblox-the-strongest-battlegrounds-listed
- SF6 Modern controls: https://www.redbull.com/us-en/street-fighter-6-modern-vs-classic-controls
- Virtual controls research (Carleton): https://www.csit.carleton.ca/~rteather/pdfs/ec2017.pdf
- Phaser virtual joystick article: https://phaser.io/news/2025/12/i-built-the-best-virtual-joystick-for-phaserjs
