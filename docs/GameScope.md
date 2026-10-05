# Game Scope (draft v0.2, 2026-10-05)

This is the working scope for the game. It pulls together the research in `docs/research/`, and each
section links to the report with the evidence and sources. Items marked **DECIDED** were open
questions the team has settled. Everything else is a recommendation to adopt unless someone objects.

## Vision

A 2.5D Smash-style platform fighter on Roblox. Hits raise the opponent's damage %, higher % means they
fly farther, and you win by knocking them past the blast zones. The roster is absurd brainrot-style
meme fighters plus public-domain legends (Dracula vs. a sneaker shark). It should be quick to pick up
on a phone and still deep enough to master on a controller.

### Pillars

1. **Hits feel incredible.** Hitstop, victim shake, camera trauma, layered sound and haptics on every
   hit, and a KO signature on every KO ([game-feel](research/game-feel.md)).
2. **Phones first, every device first-class.** About 80% of Roblox players are on mobile. Keyboard,
   controller and touch each get a native layout, not a port ([input-and-netcode](research/input-and-netcode.md)).
3. **Fighting within 30 seconds.** Bounce in the first 1–3 minutes is a top Roblox ranking signal
   ([roblox-discovery](research/roblox-discovery.md)).
4. **Fair fights, paid looks.** Every fighter is earned by playing, never bought, and money only buys cosmetics
   ([successful-games](research/successful-games.md)).
5. **A roster that keeps growing.** A new fighter, event or mode every 2–4 weeks, each one a reveal moment.

## Characters

The team writes a design for each fighter, using `docs/characters/_MovesetTemplate.md`. Claude turns
each design into `src/shared/Characters/<Name>.luau`. Claude doesn't invent movesets. Any value the
design leaves out gets an archetype default, flagged `-- TODO(design)`.

**Legal reality** (see [character-ip](research/character-ip.md), not legal advice):

- **Existing Italian-brainrot characters are High risk.** Tung Tung Tung Sahur and about 22 others are
  in an active federal case (*Spyder Games v. Mementum Lab*). "Tralalero Tralala" has trademark
  filings. The original Tralalero and Bombardiro audio breaks Roblox rules (blasphemy, and mocking a
  real war).
- **Original brainrot-style characters are Low risk.** That means our own absurd object-plus-animal
  hybrids, with our own names, human-made art and voice lines. A genre can't be owned.
- **Public domain** (US works from 1930 and earlier as of 2026): myth, folklore and 19th-century novel
  characters are Low risk. Early cartoon characters (1928 Mickey, 1929 Popeye, 1930 Betty Boop) are
  Medium, because only the earliest design is free and the names are still trademarked. Skip Tintin,
  Tarzan, Conan and Zorro.
- **Jan 1, 2027 drop:** the 1931 film *Frankenstein* and *Dracula* looks, the named Pluto, and Dick
  Tracy enter the US public domain. That's a ready-made reveal event.

**DECIDED:** The team designs its own fighters in Higgsfield and hands them over as moveset designs.
Claude checks each one against [character-ip](research/character-ip.md) and flags any that is risky to use.

### Roster structure

- **Archetypes:** all-rounder, rushdown, heavyweight, zoner, floaty. Grappler and sword come later.
- **Shared base movesets per archetype** (Brawlhalla's model). Each fighter's identity comes from its
  specials, look and audio. This keeps new fighters cheap, and any fighter can be reskinned if it
  ever hits an IP problem.
- **Launch roster target:** 6–8 fighters.

## Core mechanics

[mechanics-design-prompt](research/mechanics-design-prompt.md) holds the full mechanics design prompt (frame data, knockback,
shields, ledges, DI, ranking). Scope decisions for our audience:

| Mechanic | Recommendation | Why |
|---|---|---|
| Damage % / knockback / blast zones | Yes, core | The genre |
| Jumps, double jump, fast-fall, short hop | Yes | Core movement |
| Tilts / smashes / aerials / 4 specials / grab + throws | Yes | Smash-style move set and character design template |
| Shield, dodge/roll, air dodge | Yes | Defense |
| Ledges with anti-stall limits | Yes | Recovery and edgeguarding |
| DI | Yes, simple and generous | Gives the defender a say, and is forgiving with latency |
| Tech | Yes, with a generous window | Defensive escape |
| L-cancel | **No.** Make landing lag lower instead | It's an execution tax, especially on touch |
| Wavedash | **No** at launch | Frame-perfect tricks don't survive Roblox latency and mobile input |
| Input buffer | About 9 frames, with jump/shield held across the buffer | Feels responsive, as in Smash Ultimate |

**DECIDED:** 1v1 and 4-player FFA at launch. 2v2 comes later as an update.

**DECIDED:** No items or stage hazards at launch. They ship later as a rotating "Party" ruleset.

## Game feel

Build hitstop first. It's the biggest single win. Hit tiers (light, medium, heavy, KO) set the
hitstop, shake, rumble, sound layers and VFX ([game-feel](research/game-feel.md) has the starting-values table).

- **Simulation:** our own kinematic 2.5D character controller with a per-fighter time scale, instead of
  Roblox physics. Roblox can't pause physics, so this is what lets us freeze for hitstop and do
  slow-mo.
- **Prediction:** the attacker's client plays spark, sound, hitstop and rumble at once. The server
  confirms damage and knockback.
- **Haptics:** the `HapticEffect` API covers gamepads and most modern phones.
- **Audio:** the new Audio API, with 3-layer impacts and ±5–10% random pitch.
- **Accessibility:** toggles for shake, flash, rumble and slow-mo, plus a competitive preset. Never
  flash more than 3 times a second.

## Controls and netcode

See [input-and-netcode](research/input-and-netcode.md) for the full mapping table.

- **Input layer:** Roblox's Input Action System. Each device adapter feeds one per-frame "intent"
  record, which gameplay code and the network both read.
- **Keyboard:** WASD, J attack, K special, L smash, Shift shield, U grab.
- **Controller:** X attack, B special, right stick for smashes, triggers to shield, bumpers to grab.
- **Mobile:** floating joystick plus Attack, Special, Jump, Shield and Grab buttons. Swipe from Attack
  for a smash, drag from Special to aim. Every button is movable and resizable.
- **Tap-jump** (jump by pushing up) is off by default.
- **Netcode:**
  - Fixed-step 60 Hz deterministic simulation.
  - The client predicts its own fighter.
  - The client sends hit claims; the server checks them against its saved position history and alone
    applies damage and knockback.
  - We replicate fighter state ourselves at about 30 Hz.
  - Later, move to Roblox Server Authority once it leaves beta.

## Modes, retention and monetization

- **Modes at launch:**
  - casual drop-in 4-player FFA (with bots filling empty slots)
  - 1v1
  - a 60–90 s interactive tutorial that ends in a bot match
  - a bot practice room
- **Ranked** unlocks after some play.
- **Retention:** Roblox now measures retention over 28 days. Plan daily quests, weekly events and a
  rotating party mode, plus a collection layer with rarity tiers.
- **Monetization:** skins, emotes, KO effects and a VIP pass. Possibly a battle pass or subscription.
  Never sell power.

**DECIDED:** The collection layer is fighters plus cosmetics. Fighters unlock by playing and are never
sold for Robux or put in random rolls. Skins, emotes and KO effects are collectible with rarity tiers.
Still to set: how many fighters new players start with (proposal: enough to pick from in the first match).

## Visibility and launch

The full checklist is in [roblox-discovery](research/roblox-discovery.md).

- **Under-16 gate:** new games are shown only to age-checked players 16+ until they get 250 engaged
  plays within 60 days. Plan a 16+ soft launch (Discord, friends, a small ad budget).
- **Creator account:** age verification, 2FA, and Premium or the publishing fee.
- **Content rating:** target **Mild**, which means cartoon violence and no realistic blood.
- **Thumbnails:** upload 5 or more so Roblox's thumbnail A/B testing can run. They must show real
  gameplay.
- **Social:** invite prompts with rewards for both players, party queue, and cheap private servers.
- **Every fighter reveal gets a TikTok/Shorts clip.** The brainrot audience lives there.

## Build order (proposed)

1. Kinematic 2.5D controller, input intent layer for all 3 devices, camera.
2. Hit pipeline: hitboxes from frame data, damage, knockback, hitstop, KO. Then game feel.
3. One stage, one all-rounder fighter from the team's first moveset design, bots.
4. Netcode hardening (prediction, hit claims, server rewind).
5. Shield, grab, ledges, and the remaining archetypes.
6. Match flow, tutorial, lobby, UI. Then soft launch.
