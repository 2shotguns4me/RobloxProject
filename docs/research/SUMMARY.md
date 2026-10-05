# Research report abstracts

One-paragraph summaries of each report in this folder. Read the full report for sources and details.
`../GameScope.md` turns these findings into decisions.

## 1. What successful fighting games did well, and what sank the others

[successful-games.md](successful-games.md)

This report looks at Super Smash Bros. Ultimate and Melee, Brawlhalla, Rivals of Aether 1 and 2, MultiVersus, Nickelodeon All-Star Brawl, and the big Roblox fighting games (The Strongest Battlegrounds, Jujutsu Shenanigans, Untitled Boxing Game). The games that succeeded keep every fighter free and sell only cosmetics. They update every few weeks, and they offer casual modes and things to do between matches alongside competitive play. The ones that failed had grindy character unlocks, launched thin, stalled on updates, or were too hardcore for new players: Rivals of Aether II lost 98% of its players and MultiVersus shut down. Brawlhalla's shared movesets let its roster grow cheaply and make any character easy to reskin. About 72–80% of Roblox play is on phones, so mobile controls matter most. Brainrot appeal pulls players in at launch but doesn't keep them: Steal a Brainrot fell about 99% from its peak. The report recommends a short interactive tutorial, separate casual and ranked queues, protection for new players from toxic veterans, and keeping 4-player fights readable.

## 2. Game feel: making hits and movement feel great

[game-feel.md](game-feel.md)

This report covers how fighting games make impacts feel powerful, and how to build that on Roblox. The biggest single effect is hitstop: a brief freeze on impact that gets longer for bigger hits. It works best paired with the victim shaking, camera shake, a white flash on hit, layered impact sounds with slight pitch variation, and controller and phone vibration. The report sorts hits into light, medium, heavy and KO, with starting values for each, and gives KO hits their own slow-motion and zoom. Roblox can't pause its physics, so the main recommendation is to write our own character movement code so we can freeze and slow time. The attacker's device should play hit effects immediately and let the server confirm the damage, which hides lag. On the Roblox side, the newer vibration API covers controllers and most modern phones, and the newer audio system replaces the old one. Accessibility toggles and a no-more-than-3-flashes-per-second limit should ship on day one.

## 3. Controls and online responsiveness

[input-and-netcode.md](input-and-netcode.md)

This report designs controls for keyboard, controller and touch, and an online setup that works within Roblox's limits. Each device gets its own native layout:

- **Keyboard:** a dedicated smash-attack key.
- **Controller:** the right stick does smash attacks.
- **Mobile:** a floating joystick plus five big, movable buttons. Swiping from Attack gives a smash attack, and dragging from Special aims the special.

All devices feed the same per-frame record of what the player is doing, so gameplay code never reads raw keys. Telling a light stick tap from a smash flick uses Smash Ultimate's thresholds, inputs pressed slightly early are buffered for about 9 frames, and jumping by pushing up is off by default. For online play, each player's game runs their own fighter instantly and reports its own hits. The server checks those hits against recent positions and alone applies damage. We send fighter positions ourselves, because Roblox's default syncing is too slow. Later we can move to Roblox's new Server Authority mode once it leaves beta. The report recommends building our own hitboxes from frame data instead of using an existing library.

## 4. How Roblox decides which games to show

[roblox-discovery.md](roblox-discovery.md)

This report explains how Roblox's home page ranks games, and what it means for our launch. The top signals are:

- how often people click in after seeing the game
- how many leave in the first 1–3 minutes
- how many days they come back
- playtime per player

Playing with friends and spending come next. Since June 2026, return visits are measured over 28 days instead of 7. New games are shown only to age-checked players 16+ until they get 250 engaged plays and pass a safety review. That makes a 16+ soft launch necessary, along with creator account verification. A "Mild" content rating keeps younger players in the audience. The report recommends uploading several thumbnails so Roblox's built-in thumbnail test runs, adding friend invites with rewards, shipping weekly updates, and adding a collection layer. Ads help early tests but don't count toward ranking. A launch checklist is included.

## 5. Which characters are legally safe

[character-ip.md](character-ip.md)

This report rates about 40 possible roster characters as low, medium or high risk. Existing Italian brainrot characters are high risk:

- A federal lawsuit over Tung Tung Tung Sahur and about 22 others is still undecided.
- Trademark applications have been filed for Tralalero Tralala.
- Some original audio breaks Roblox's content rules.

AI-generated images may not be protected by copyright, but trademarks don't depend on copyright. Original brainrot-style characters with our own names, art and voices are low risk. Most public-domain characters from myths, folklore and old novels are low risk too, but two traps apply:

- Only a character's earliest published design is free.
- Many names are still trademarked.

Characters that are public domain only in the US are risky because Roblox is worldwide. More classic characters become free on January 1, 2027, including Frankenstein and Dracula as the 1931 films show them. Roblox removes games on copyright or trademark complaints, and its licensing program is the legitimate route for licensed characters later. This is not legal advice.

## 6. Smash mechanics and a prompt for writing the full spec

[mechanics-design-prompt.md](mechanics-design-prompt.md)

This report surveys how Smash and other platform fighters handle the core systems:

- damage and knockback
- hitstun, the time a hit player can't act
- shields
- ledges and recovering back to the stage
- DI, letting a launched player steer their launch a little
- input buffering
- ranking

It shows the series has solved the same problems in different ways, so no single game's rules should be copied. It gives a table of suggested starting numbers to tune together. It treats advanced tricks like wavedashing and L-canceling as design choices to weigh up, not features to include by default. Most of the report is a prompt to paste into Claude that produces a full mechanics spec, with options, formulas, worked examples, a test plan and a decision log. It reads like a game-design document, but it's mainly a tool for producing one.
