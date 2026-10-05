# What Successful Platform Fighters & Battlegrounds Games Do Well (and What Sank the Others)

Research for our Roblox 2.5D platform fighter (damage %, knockback, blast-zone KOs) with AI "brainrot" meme characters and public-domain characters. Core mechanics math (frame data, knockback formulas, shields, ledges, DI, ranking) lives in a separate report and is not repeated here.

Research date: October 2026. Player counts for Roblox games come from third-party trackers (RoWatcher, profitable.app, earnaldo). Those sites are aggregators, so treat the exact numbers as approximate. Anything I could not confirm is marked **[unverified]**.

---

## Top takeaways for our game

1. **Make every fighter free to play. Sell cosmetics, not power.** The biggest Roblox fighters (Jujutsu Shenanigans, The Strongest Battlegrounds, Untitled Boxing Game) all keep fights fair and charge for looks. MultiVersus died partly because it made unlocking characters a grind and pushed hard on monetization. Blox Fruits' paid "permanent fruits" are the textbook pay-to-win complaint.
2. **Build fighters from shared parts so the roster can grow fast.** Brawlhalla has 70 Legends because they all share 15 weapon movesets and each one only gets unique signature moves. Its "Epic Crossovers" reuse existing hitboxes and frame data under a new skin. For us: build archetype rigs (sword, brawler, projectile) and give each brainrot or public-domain character a distinct set of specials.
3. **Most of our players will be on phones.** Roughly 72-80% of Roblox play happens on mobile, and about 73% of users are under 18. Design for 4 action buttons or fewer on touch, auto-facing, and big readable hit effects. TSB starts you with 4 abilities plus an "Awakening" swap, and that is the template that works on Roblox.
4. **Offer a casual drop-in mode from day one, not just ranked 1v1.** Rivals of Aether II peaked at about 11.8k concurrent players and lost 98%. One cause was hardcore-first design: thin tutorials, empty casual queues, and new players matched against beta veterans. Brawlhalla keeps people around with 20+ silly modes rotated through "Brawl of the Week".
5. **Cut netcode corners on purpose.** Roblox servers have authority over game state and add latency. Successful Roblox fighters detect hits on the attacker's client, then have the server check range and direction. Pair that with generous hitboxes and slower, more readable knockback than Melee. Don't promise rollback-level precision.
6. **Plan updates before launch, then ship them on schedule.** Every Roblox success here updates relentlessly. The stall in MultiVersus character releases after its beta came before its 99% player drop. Plan for a new character, event or mode every 2-4 weeks.
7. **Launch the full core experience.** MultiVersus relaunched without ranked, FFA or post-match stats. NASB1 launched with no voice acting or music from its franchises. Players never forgive a thin launch, and NASB2 was a much better game that sold far less because of NASB1's reputation.
8. **Character appeal sells, but brainrot is a trend that may fade.** Steal a Brainrot reached a record 25.8M concurrent players and then fell about 99%. Brainrot works as a label that pulls in players at launch, not as something that keeps them. Fun moment-to-moment fighting has to do that, with appeal rotated through new memes and public-domain characters.
9. **Get legal clearance on brainrot characters.** There is an active federal fight over who owns Tung Tung Tung Sahur. Steal a Brainrot received a cease-and-desist and then sued for a ruling that the AI-made characters can't be copyrighted. Prefer original brainrot-style characters or clearly unowned ones, and keep the ability to reskin any character.
10. **Design against toxicity.** Battlegrounds games have trouble with players farming newcomers, emote-spamming after kills, and outside players joining duels. Use skill-based matchmaking or segmented lobbies for new players, short post-KO invulnerability, mutable emotes, and team-locked damage in FFA arenas.
11. **Make the chaos readable.** Sakurai turned down rollback for Ultimate partly because of 4-player-with-items desyncs, and Smash still overwhelms new players. Use strong player-color outlines, off-screen indicators, limited particles on mobile, and clear "launch" visual effects at high %.
12. **Offer cheap stuff to do between fights.** World of Light, Brawlhalla's bots and Horde mode, and Smash's Spirits give players something when queues are slow or friends are offline. A simple bot practice room, a Horde mode, and daily quests will cover most of this.

---

## 1. Super Smash Bros. Ultimate & Melee

### Does well

| What | Why it works | Takeaway for us |
|---|---|---|
| **The roster is the whole sales pitch: "Everyone is here"** | Ultimate has sold 37.44M copies as of Dec 31, 2025, the best-selling fighting game ever ([Nintendo IR](https://www.nintendo.co.jp/ir/en/sales/software/switch.html), [CGMagazine](https://www.cgmagonline.com/news/super-smash-bros-ultimate-is-the-third-best-selling-game-on-switch-and-the-best-selling-fighting-game-of-all-time)). People buy it to see who fights whom. | Character reveals are our marketing. Treat each new brainrot or public-domain fighter as a trailer-worthy event with its own reveal clip for TikTok and YouTube Shorts. |
| **Casual and competitive share one engine** | Items, stage hazards, and 8-player chaos sit on top of a ruleset (no items, Battlefield-style stages) that the competitive scene uses. | Ship a "Party" ruleset (items, hazards, FFA) and a "Competitive" ruleset (no items, flat stages) as separate queues. |
| **Lots of single-player content** | World of Light and Spirits give people things to do offline. Some critics liked them, though Kotaku called the adventure mode "tacked-on" ([Kotaku](https://kotaku.com/super-smash-bros-ultimate-one-month-later-1831579538)). | A light PvE mode such as a Horde mode or "Boss Brainrot" raids, playable solo or in co-op. |
| **Melee + Slippi: community tools kept a 2001 game alive** | Slippi added rollback, matchmaking, replays, and later ranked to Melee in 2020 ([SSBWiki](https://www.ssbwiki.com/Project_Slippi), [EventHubs](https://www.eventhubs.com/news/2020/jun/22/rollback-netcode-implemented-super-smash-bros-melee-slippi-online)). | Replays and spectating build community. Roblox lets us add spectating cheaply, so do it. |

### Problems

- **Bad online play was its biggest complaint.** Ultimate's delay-based netcode led to the viral #FixUltimateOnline campaign in 2020. Leffen called online "by far, [its] biggest flaw" ([EventHubs](https://www.eventhubs.com/news/2020/apr/23/fans-want-super-smash-bros-ultimates-online-experience-fixed-and-theyre-rallying-twitter-right-now), [Inverse](https://inverse.com/gaming/smash-ultimate-rollback-netcode-vs-delay-based)). Sakurai said they tested rollback, but in 4-player matches with items the side effects were "substantial" ([EventHubs](https://eventhubs.com/news/2020/sep/02/something-similar-rollback-netcode-was-attempted-super-smash-bros-ultimate-there-were-too-many-side-effects-according-masahiro-sakurai)). The "Preferred Rules" setting often put players into matches with rules they didn't pick ([EventHubs](https://www.eventhubs.com/news/2020/apr/27/here-are-five-things-about-super-smash-bros-ultimates-online-should-be-fixed)).
  - **How we avoid it:** Use separate queues with fixed rulesets, never "preferences". Show ping and region before matching. Accept that 4-player FFA will feel loose and tune it to be forgiving.
- **New players get no real tutorial.** The tutorial is a non-interactive video hidden under Vault → Movies, and new players feel overwhelmed. Sakurai said he wanted an interactive tutorial but couldn't fit it in ([Cubed3](https://www.cubed3.com/games/reviews/nintendo-switch/super-smash-bros-ultimate), [SSBWiki How to Play](https://ssbwiki.com/How_to_Play_(SSBU))).
  - **How we avoid it:** A required 60-90 second interactive tutorial (move, jump, attack, special, recover, KO a dummy), then straight into a bot match.

## 2. Brawlhalla (the most relevant model for us)

Free to play, crossplay on PC, consoles and mobile, more than 100M lifetime players as of 2023, and live since 2017 ([Ubisoft News](https://news.ubisoft.com/en-us/article/MvVxfuQT6SZ5XnlJY8Pgp/brawlhalla-celebrates-100-million-lifetime-players-with-ingame-event), [Wikipedia](https://en.wikipedia.org/wiki/Brawlhalla)).

### Does well

| What | Why it works | Takeaway for us |
|---|---|---|
| **Shared weapon movesets** | 15 weapons shared across 70 Legends. Each Legend has 2 weapons and only 6 unique signature moves ([Wikipedia](https://en.wikipedia.org/wiki/Brawlhalla)). New characters are cheap to make and quick to learn. | Build about 6-8 archetype kits (normals and movement) and give each character 3-4 unique specials. That lets a small team release a character every few weeks. |
| **Crossovers are skins over existing kits** | "Epic Crossovers" (SpongeBob, Adventure Time, WWE, Star Wars, Shrek in 2026...) use the same hitboxes and frame data as an existing Legend, with new visuals, voice lines and signature moves ([Brawlhalla crossovers overview](https://shapes.inc/fandom/brawlhalla/crossovers), [IDC Games Shrek news](https://idcgames.com/en/brawlhalla/news/brawlhalla-x-shrek-crossover-adds-shrek,-fiona,-puss-in-boots-and-donkey-to-valhalla-2026-07-30-08-35-13560)). Almost no balance risk and a big appeal boost. | **Very relevant.** Make fresh brainrot memes "Epic skins" of existing fighters. That lets us chase trends within days without balance work, and if a meme turns out to have a legal problem we can swap the skin out. |
| **Fair free-to-play** | 9 free Legends each week, other Legends unlockable with earned Gold, or $39.99 for every current and future Legend. Cosmetics cost premium Mammoth Coins ([Wikipedia](https://en.wikipedia.org/wiki/Brawlhalla)). | A free starter set of 8-10 fighters plus a weekly free rotation, with all fighters earnable in hours rather than weeks. Cosmetics and battle pass are paid. |
| **Full crossplay including mobile** | Crossplay launched in 2019, mobile in 2020 ([Wikipedia](https://en.wikipedia.org/wiki/Brawlhalla)). | Roblox gives us crossplay automatically, but we still need input-fairness options (see section 9). |
| **Many modes on rotation** | Brawlball, Kung Foot, Bubble Tag, Snowbrawl, Horde, Dodgebomb, Volleybrawl, and others, rotated through "Brawl of the Week" ([Brawlhalla Wiki: Modes](https://brawlhalla.wiki.gg/wiki/Modes)). | One weekly featured mode keeps returning players interested and fills a single queue instead of splitting players across many. |
| **Simpler inputs than Smash** | No shield, just dodge. Light, heavy and throw buttons. | Simple controls suit touch screens. Consider dodge-only defense on mobile, or a simplified shield. |
| **Supports its community and esports** | Its 100M milestone was credited "in part" to a close relationship with the competitive community ([SI](https://www.si.com/esports/brawlhalla/esports-team-interview-david-kelsh-toastbh)). | Community tournaments with in-game cosmetic rewards. |

### Problems

- Critics found it "not quite as tightly designed" as Smash ([Wikipedia/Push Square](https://en.wikipedia.org/wiki/Brawlhalla)). Shared weapons make Legends feel samey **[community sentiment, unverified quantitatively]**. *Avoid it:* give each character a strong silhouette, voice, and at least one memorable "signature" move.

## 3. Rivals of Aether 1 & 2

### Does well
- **Rollback netcode and a modding community.** Rivals 1 added rollback in 2022, and four Steam Workshop characters made by fans became official DLC ([rivalsofaether.com](https://rivalsofaether.com/workshop-character-pack-release-date/), [Smashboards](https://smashboards.com/threads/dlc-pack-and-rollback-netcode-coming-soon-to-rivals-of-aether.516918)). *Takeaway:* run community character-design contests and turn the winners into real fighters. It costs little and builds loyalty.
- **Free gameplay content after launch.** Rivals II commits to free characters and modes, paid for by optional cosmetics ([Gematsu roadmap](https://gematsu.com/2024/10/rivals-of-aether-ii-post-launch-content-roadmap-announced)).
- **Strong competitive scene.** It reached the top 4 by entrant count at Evo 2026 ([esports.gg](https://esports.gg/news/fgc/evo-2026-reveals-announcements/)).

### Problems
- **It retained very few players.** Peak was 11,765 concurrent players in Oct 2024, and it now sits around 270, a 98% drop ([Steambase](https://steambase.io/apps/2217000)). Some argue that's comparable to Tekken 8's retention ([Steam discussions](https://steamcommunity.com/app/2217000/discussions/0/603020523905030811)).
- **Built for hardcore players first.** Players complained about thin tutorials, ranked opponents who "seemed leagues ahead", and casual queues in the EU that **never found a match**. Players said the game went "too hard on competitiveness" and "tossed aside the casual group" ([Steam discussions](https://steamcommunity.com/app/2217000/discussions/0/603020523905030811)).
  - **How we avoid it:** Put casual play first. Merge queues when the population is low, fill empty slots with bots after about 20-30 s, hide ranked until the player has finished about 10 casual matches, and use separate matchmaking for new accounts.
- **Paid entry.** It costs $26.99 on Steam. That isn't a factor for us on Roblox, but it confirms that a paid gate hurts a niche genre.

## 4. MultiVersus: the cautionary tale

### What happened
- The open beta in July 2022 reached 10M players in its first month and 20M by September. It then lost about 99%, falling to roughly 1,300 daily Steam players by Feb 2023 ([Wikipedia](https://en.wikipedia.org/wiki/MultiVersus), [esports.net](https://www.esports.net/news/fighting-games/why-did-multiversus-die)).
- It was pulled offline in June 2023 with no refunds and relaunched in May 2024 on UE5. The relaunch peaked at about 114k on Steam, but **ranked, FFA and post-match stats were missing at launch** ([Wikipedia](https://en.wikipedia.org/wiki/MultiVersus)).
- WB reported a roughly **$100M writedown** in Nov 2024. Season 5 was announced as the last, and servers shut on May 30, 2025 ([Wikipedia](https://en.wikipedia.org/wiki/MultiVersus), [GamingBolt](https://gamingbolt.com/multiversus-has-been-delisted-from-all-storefronts-servers-have-been-shut-down)).

### Why it failed (and what we do instead)

| Problem | Evidence | How we avoid it |
|---|---|---|
| **Content stalled after launch hype** | Character and event delays, and bug fixes that took "weeks and months". The game "felt abandoned" ([esports.net](https://www.esports.net/news/fighting-games/why-did-multiversus-die)) | Bank 2-3 months of finished content before launch. Only announce dates we have already hit internally. |
| **Grind to unlock characters** | At relaunch, unlocking one fighter took "several hours" and Fighter Currency earn rates were cut ([GameDesignSkills](https://gamedesignskills.com/game-development/why-did-multiversus-fail/)) | All fighters earnable quickly or free. Sell skins. |
| **Predatory-feeling currency** | Skins cost 500 Gleamium, but the cheapest $4.99 bundle didn't cover it. Battle-pass XP was tied to challenges. Toast "greetings" were paywalled. Buyable "extra lives" were called a "bug" and fans didn't believe it ([GameDesignSkills](https://gamedesignskills.com/game-development/why-did-multiversus-fail/), [GGRecon](https://www.ggrecon.com/articles/multiversus-fans-arent-buying-extra-life-excuse/), [Gameranx](https://gameranx.com/updates/id/501636/article/multiversus-players-arent-happy-with-latest-microtransaction/)) | Robux bundles should match item prices. Battle-pass XP comes from playing matches. Never sell anything that affects the outcome of a match. |
| **Changed the feel at relaunch** | The pace was slowed and "everything just felt a bit off" ([esports.net](https://www.esports.net/news/fighting-games/why-did-multiversus-die)) | Find the feel early through playtests and then protect it. Patch numbers, not the core physics. |
| **Odd roster choices from a huge IP library** | Minor characters were added while iconic ones were absent ([esports.net](https://www.esports.net/news/fighting-games/why-did-multiversus-die)) | Prioritize the characters the audience already knows: top-trending brainrot plus famous public-domain figures. Poll players. |
| **Built around 2v2** | The core design was 2v2 co-op ([Game Informer](https://www.gameinformer.com/interview/2022/05/30/an-interview-with-multiversus-director-tony-huynh)), and FFA was missing at relaunch | 1v1 and 4-player FFA are the main modes, with 2v2 as a supporting mode. Kids drop in solo. |
| **Lag and teleporting** | Players reported teleporting and unfair deaths ([GameDesignSkills](https://gamedesignskills.com/game-development/why-did-multiversus-fail/)) | See section 9. |

## 5. Nickelodeon All-Star Brawl 1 & 2

### Does well
- NASB1 had **rollback, wavedashing, a hitbox viewer and frame-advance training** ([EventHubs](https://eventhubs.com/news/2021/jul/13/nicelodeon-brawl-reportedly-rollback-wavedashing), [ONE Esports](https://www.oneesports.gg/gaming/nickelodeon-all-star-brawl-rollback/)). IGN gave it 7/10 for "fast-paced and fun gameplay" ([SVG](https://www.svg.com/628015/what-the-critics-are-saying-about-nickelodeon-all-star-brawl/)).
- NASB2 was widely considered **better in every way**: voice acting, single-player content, and reworked mechanics. Joining Game Pass brought a +34,744% player bump ([Windows Central](https://windowscentral.com/gaming/xbox/report-thanks-to-xbox-game-pass-this-2023-fighting-game-just-got-a-34744-player-count-boost)). *Takeaway:* putting the game in front of a big audience is a huge growth lever. On Roblox, that means sponsored placements, the Discover sort, and YouTuber and TikTok seeding.

### Problems
- **NASB1 had no character voices or show music.** It was the top critical complaint, and Push Square said it "miss[ed] so much of the cartoon's personality". The developers blamed budget and licensing limits. Voice lines were patched in later ([SVG](https://www.svg.com/628015/what-the-critics-are-saying-about-nickelodeon-all-star-brawl/), [Inven Global](https://invenglobal.com/articles/17368/nickelodeon-all-star-brawl-gets-most-important-update-yet-voice-lines)).
  - **How we avoid it:** For brainrot characters, **the audio is the character** ("Tralalero Tralala", "Tung Tung Tung Sahur"). Every fighter needs signature voice lines and SFX at launch. Public-domain characters need recognizable visuals and sound cues.
- **The roster was built for fans of the cartoons, but the gameplay was built for Melee players.** The Smash audience didn't embrace NASB1, and the series' reputation then hurt NASB2. NASB2 sold an estimated ~109k copies, less than NASB1 ([vpesports](https://vpesports.com/new-xbox-game-pass-title-sees-massive-player-surge), [SteamPulse](https://steampulse.org/game/2017080); estimates).
  - **How we avoid it:** Our audience is kids who love memes. Keep the basic controls simple (Brawlhalla or TSB level), put the depth in higher-level techniques, and never make launch quality depend on a later patch.

## 6. Indie: Stick Fight: The Game

- An estimated ~7.4M units sold and 93% positive reviews ([Raijin](https://raijin.gg/app/674940/Stick_Fight_The_Game), [vaporlens](https://vaporlens.app/app/674940/stick_fight_the_game/stats/details); third-party estimates).
- **Why it works:** physics-driven funny moments, nearly nothing to learn, 100 interactive levels with weapon drops, fast rounds, and play with friends.
- **Takeaway:** Matches that produce clippable moments sell themselves on TikTok. Brainrot characters flying off screen with a meme sound at the KO is our version of this. Keep rounds short (about 2-3 min) and get players back into the next match fast.

## 7. Roblox fighters & battlegrounds

### The Strongest Battlegrounds (Yielding Arts): the benchmark
- Launched Aug 2022. About 17-18B visits, with recent concurrent players ranging from about 80k to over 300k depending on update cycles ([RoWatcher](https://rowatcher.com/games/3808081382), [profitable.app](https://profitable.app/roblox/games/the-strongest-battlegrounds); aggregator estimates). It won **Best Fighting Experience** at the Roblox Innovation Awards 2024 ([RoWatcher](https://rowatcher.com/games/3808081382)).
- **Why it works:** 9 free main characters. Each has **4 abilities usable from spawn**, plus an Awakening meter that swaps in 4 ultimate moves. Combos are easy for beginners. There's no stat progression, and money goes to cosmetics like kill-sound gamepasses ([allthings.how](https://allthings.how/the-strongest-battlegrounds-character-roster-movesets-and-access-rules/), [earnaldo](https://earnaldo.com/blog/the-strongest-battlegrounds-vs-jujutsu-shenanigans)). Its hit detection is cited on the DevForum as one that "has achieved a good system with no significant latency issues" ([DevForum](https://devforum.roblox.com/t/2672420)).
- **Takeaway:** A good mobile control template is 1 basic-attack button, 4 skill buttons, and 1 "ultimate" when the meter is full. Our percent-and-knockback system can sit on top. The ultimate could be a brainrot "Final Smash" that draws attention.

### Jujutsu Shenanigans (Tze's Shenanigans)
- About 4.4B+ visits. It peaked around 338k concurrent players after a March 2026 update ([RoWatcher](https://rowatcher.com/news/jujutsu-shenanigans-surges-past-338k-peak-players-after-disaster-plants-update)).
- **Why it works:** Nearly every character is free with no gacha, it's skill-based, it has destructible arenas, and it gets regular character drops that follow the anime's story ([earnaldo](https://earnaldo.com/blog/jujutsu-shenanigans); aggregator).
- **Takeaway:** Destructible or changing stages create good moments. Release characters in step with what's trending, and for us that means meme cycles.

### Untitled Boxing Game (solo dev drowningsome)
- About 1.2B visits and about 10k concurrent players ([RoWatcher](https://rowatcher.com/games/4730278139/untitled-boxing-game)). It has many "styles", and rarer styles are claimed to be mostly cosmetic or sidegrades rather than strictly better **[balance claim from aggregator, unverified]**.
- **Takeaway:** Only one fighting style (boxing) and still huge. Depth and fairness matter more than spectacle. Gacha-style rerolls for *styles* are its main source of money, and that sits on the edge of pay-to-win, so we should only sell rerolls for cosmetics.

### Blox Fruits PvP: what to avoid
- Paid "permanent fruits" (about 3,000 Robux) and PvP bonuses from bounty and honor are a well-known pay-to-win complaint ([RoWatcher review](https://rowatcher.com/news/is-blox-fruits-worth-playing-in-2026-an-honest-review), [Blox Fruits Wiki](https://blox-fruits.fandom.com/wiki/Bounty_and_Honor_System)). Bounty hunters farm weaker players.
- **Takeaway:** Leaderboards should never grant power. Make PvP opt-in or match it by skill.

### Roblox Smash-likes
- Several Smash-like projects have been pitched on the DevForum (Super Fighting Friends, Super Brawl Blox, Brickbattle Grand Arena), but I found **no evidence that any reached a large audience** ([DevForum thread](https://devforum.roblox.com/t/could-a-super-smash-bros-type-game-succeed-on-the-roblox-platform/824442), [Brickbattle Grand Arena](https://devforum.roblox.com/t/thoughts-on-brickbattle-grand-arena-ssb-type-game-devlog/2051347), [Super Brawl Blox](https://devforum.roblox.com/t/super-brawl-blox/937940)). DevForum advice: Smash is "super hard to replicate because if it is done wrong they can be really REALLY boring", and marketing is essential.
- PHIGHTING! is a well-loved stylized class-based fighter/shooter with 13.8M+ visits and little monetization ([PHIGHTING wiki](https://phighting.wiki/PHIGHTING!)). Even so, it is far smaller than the battlegrounds games.
- **What this tells us:** The space is **open but unproven** on Roblox. The genre that clearly wins on Roblox is the 3D "battlegrounds" game, so we should borrow its controls, free roster, and fast update pace while offering the Smash structure (blast zones, %) as the twist. **[inference]**
- Why Roblox fighters decline in general: a lack of updates, a better clone appearing, and developer burnout ([general article](https://grandavehousing.calpoly.edu/news/roblox-games-that-died-a); low-quality source, so this is **[unverified]** as a source, though it matches the patterns above).

### Brainrot games and character appeal
- **Steal a Brainrot** reached 25.8M concurrent players in Oct 2025, the all-time Roblox record ([PocketGamer.biz](https://www.pocketgamer.biz/robloxs-steal-a-brainrot-becomes-first-game-to-surpass-25m-concurrent-players), [Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot)), and earned an estimated $64M+ in real-money purchases. It later fell about 99% to around 215k concurrent players ([RoWatcher](https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals)). It also signed toy licensing deals ([Licensing Magazine](https://www.licensingmagazine.com/2026/02/06/phatmojo-signs-global-toy-rights-to-steal-a-brainrot/)) and hosted a Bruno Mars concert ([Guinness](https://www.guinnessworldrecords.com/news/commercial/2026/2/bruno-mars-hosts-largest-concert-in-a-videogame-during-steal-a-brainrot-on-roblox)).
- RoWatcher's conclusion: brainrot is "normalizing" into an established genre, and "brainrot" in a title is still a reliable magnet for new players. The survivors are the games with a "relentless update cadence".
- **Why it worked:** Collecting rare brainrots and showing them off (rarity tiers), plus fear of losing them to theft, plus weekly events.
- **Takeaway:** Add a collection layer outside the fights: rarity-tiered skins and variants, a "brainrot dex", and showcase poses in the lobby. That is where character appeal turns into money, and it never touches combat balance.
- **Legal risk:** Mementum Lab sent Steal a Brainrot a cease-and-desist claiming Tung Tung Tung Sahur. The developers sued for a ruling that AI-generated brainrots can't be copyrighted, and the case is pending ([Dexerto](https://www.dexerto.com/roblox/tung-tung-sahur-is-at-the-center-of-a-bizarre-federal-custody-battle-over-brainrot-characters-3381733), [Wikipedia: Tung Tung Tung Sahur](https://en.wikipedia.org/wiki/Tung_Tung_Tung_Sahur)). There is also a separate lawsuit over game clones ([Aftermath](https://aftermath.site/brainrot-roblox-court/)). **Not legal advice.** Prefer original characters in brainrot style, and keep any trending meme character reskinnable.

## 8. Cross-cutting themes

### Onboarding
- Failure pattern: hidden or no tutorial (Smash), hardcore-first queues (Rivals II), a slower and confusing feel at relaunch (MultiVersus).
- What to do: an interactive tutorial under 90 s, then a bot match, then casual FFA with new players matched together and backfilled by bots. Unlock ranked after about 10 matches. Show contextual tips on the first KO, the first time a player is launched, and the first recovery.

### Roster size & appeal
- Launch with roughly 8-12 fighters, all highly recognizable, rather than 20 obscure ones. Grow by about 1 a month, and cheaply through archetype kits and Epic-skin-style variants (Brawlhalla).

### Monetization (Roblox)
- Free fighters (or quick to earn), paid cosmetics, a battle pass earned by playing, rarity collectibles, emotes and kill sounds (as TSB does), and private servers. **Never:** stat boosts, paid lives, "permanent" power, or bundle math that leaves players short (MultiVersus).

### Netcode / online feel (see section 9)

### Matchmaking & queues
- Have few queues. Merge regions and modes when the population is low. Add bots after a timeout. Rotate one featured mode a week (Brawlhalla) instead of keeping a dozen permanent queues.

### Game modes
- Core modes: 4-player FFA (stock), 1v1, and 2v2. Also a rotating party mode (Brawlball-style, a brainrot "hot potato"), Horde/PvE, and private custom lobbies.

### Content cadence & live ops
- Successful Roblox fighters get character or system drops every few weeks plus seasonal events. Big updates bring big concurrent-player spikes (JJS peaked at 338k after an update). Stalled content killed MultiVersus.

### Balance patching
- Patch numbers frequently and in small steps, and never the core movement and physics feel (the MultiVersus relaunch lesson). Publish patch notes in the game.

### Toxicity
- Known problems in battlegrounds games: farming newcomers, emote-spamming after kills, outside players joining fights ([Sportskeeda](https://sportskeeda.com/roblox-news/5-things-know-playing-roblox-the-strongest-battlegrounds)). Countermeasures: matched lobbies instead of open-world brawling, a "mute emotes" setting, rate-limited emotes, no damage from outside players in duels, and spawn protection.

### Retention
- Daily and weekly quests, a battle pass, collections, a featured mode, and community events. Brawlhalla's 9-year run shows that fair free-to-play plus constant cosmetics and crossovers lasts.

### Casual vs competitive split
- Keep casual and competitive in one game with separate queues and rulesets (Smash). Lean casual at launch. Rivals II shows what happens when the hardcore audience is the only target.

### Readability in 4-player chaos
- Color outlines per player and team, name and % tags, off-screen bubbles with arrows, camera zoom limits, hit-pause on strong hits, and a lower-particle setting for mobile. Strong KO moments (screen shake, a launch trail, a meme sound sting) make the fights easy to clip and share. **[design recommendation]**

## 9. Netcode on Roblox: how fighters handle hit registration

- Roblox servers have authority over game state, and by default your character's position on the server lags behind the client. Developers report about 2 studs of lag when walking and **7-8 studs when dashing** ([DevForum](https://devforum.roblox.com/t/2672420)). Rollback in the GGPO sense isn't natively available. Some developers build server-side "rewind" from position buffers ([DevForum: Combat System with Rollback](https://devforum.roblox.com/t/combat-system-with-rollback/3685525)).
- **The common pattern:** the attacker's client detects the hit (with modules such as ClientCast or raycast or shape queries) and tells the server. The server **validates** distance (for example, within about 3 studs), facing direction, cooldowns and timing, then applies damage and knockback with authority ([DevForum fair hitboxes](https://devforum.roblox.com/t/whats-the-best-way-to-handle-fair-hitboxes-in-a-multiplayer-scenario/3971560)). Checking hits only on the server punishes high-ping players, who "always have to be closer to someone and predict their moves".
- **Recommendations for us:**
  1. Detect hits on the client with favor-the-attacker validation on the server, including a position-history rewind of roughly 100-200 ms **[suggested values, tune in testing]**.
  2. Make the **victim's** knockback trajectory deterministic from the server's hit event. Simulate it on all clients from the same launch vector and %, then correct gently to reduce teleporting. MultiVersus' "teleport off platforms" complaint is the failure to avoid here.
  3. Use slightly larger hitboxes and moves with longer startup and recovery than Melee or Rivals. Avoid frame-perfect techniques like wavedash timing that latency breaks.
  4. Check every hit for exploits: rate limits and range checks, because exploiters spoof hit reports.
  5. Show ping in the lobby and match players by region when the population allows.

---

## Sources

**Smash**
- Nintendo IR top-selling titles: https://www.nintendo.co.jp/ir/en/sales/software/switch.html
- CGMagazine, best-selling fighting game: https://www.cgmagonline.com/news/super-smash-bros-ultimate-is-the-third-best-selling-game-on-switch-and-the-best-selling-fighting-game-of-all-time
- Inverse, Sakurai on rollback: https://inverse.com/gaming/smash-ultimate-rollback-netcode-vs-delay-based
- EventHubs, rollback side effects: https://eventhubs.com/news/2020/sep/02/something-similar-rollback-netcode-was-attempted-super-smash-bros-ultimate-there-were-too-many-side-effects-according-masahiro-sakurai
- EventHubs, #FixUltimateOnline: https://www.eventhubs.com/news/2020/apr/23/fans-want-super-smash-bros-ultimates-online-experience-fixed-and-theyre-rallying-twitter-right-now
- EventHubs, five online fixes: https://www.eventhubs.com/news/2020/apr/27/here-are-five-things-about-super-smash-bros-ultimates-online-should-be-fixed
- Cubed3 review: https://www.cubed3.com/games/reviews/nintendo-switch/super-smash-bros-ultimate
- SSBWiki How to Play: https://ssbwiki.com/How_to_Play_(SSBU)
- Kotaku, one month later: https://kotaku.com/super-smash-bros-ultimate-one-month-later-1831579538
- SSBWiki Project Slippi: https://www.ssbwiki.com/Project_Slippi
- EventHubs, Slippi rollback: https://www.eventhubs.com/news/2020/jun/22/rollback-netcode-implemented-super-smash-bros-melee-slippi-online

**Brawlhalla**
- Wikipedia: https://en.wikipedia.org/wiki/Brawlhalla
- Ubisoft 100M players: https://news.ubisoft.com/en-us/article/MvVxfuQT6SZ5XnlJY8Pgp/brawlhalla-celebrates-100-million-lifetime-players-with-ingame-event
- SI esports interview: https://www.si.com/esports/brawlhalla/esports-team-interview-david-kelsh-toastbh
- Brawlhalla Wiki, Modes: https://brawlhalla.wiki.gg/wiki/Modes
- Epic Crossovers overview: https://shapes.inc/fandom/brawlhalla/crossovers
- Shrek crossover: https://idcgames.com/en/brawlhalla/news/brawlhalla-x-shrek-crossover-adds-shrek,-fiona,-puss-in-boots-and-donkey-to-valhalla-2026-07-30-08-35-13560

**Rivals of Aether**
- Steambase Rivals II: https://steambase.io/apps/2217000
- Steam discussions: https://steamcommunity.com/app/2217000/discussions/0/603020523905030811
- Gematsu roadmap: https://gematsu.com/2024/10/rivals-of-aether-ii-post-launch-content-roadmap-announced
- esports.gg Evo 2026: https://esports.gg/news/fgc/evo-2026-reveals-announcements/
- Workshop character pack: https://rivalsofaether.com/workshop-character-pack-release-date/
- Smashboards, rollback + DLC: https://smashboards.com/threads/dlc-pack-and-rollback-netcode-coming-soon-to-rivals-of-aether.516918

**MultiVersus**
- Wikipedia: https://en.wikipedia.org/wiki/MultiVersus
- esports.net, Why did MultiVersus die: https://www.esports.net/news/fighting-games/why-did-multiversus-die
- GameDesignSkills, Why MultiVersus failed: https://gamedesignskills.com/game-development/why-did-multiversus-fail/
- GGRecon, extra lives: https://www.ggrecon.com/articles/multiversus-fans-arent-buying-extra-life-excuse/
- Gameranx, toast: https://gameranx.com/updates/id/501636/article/multiversus-players-arent-happy-with-latest-microtransaction/
- Game Informer, Tony Huynh interview: https://www.gameinformer.com/interview/2022/05/30/an-interview-with-multiversus-director-tony-huynh
- GamingBolt, servers shut down: https://gamingbolt.com/multiversus-has-been-delisted-from-all-storefronts-servers-have-been-shut-down

**Nickelodeon All-Star Brawl**
- SVG, critics' roundup: https://www.svg.com/628015/what-the-critics-are-saying-about-nickelodeon-all-star-brawl/
- Inven Global, voice lines update: https://invenglobal.com/articles/17368/nickelodeon-all-star-brawl-gets-most-important-update-yet-voice-lines
- EventHubs, rollback/wavedash: https://eventhubs.com/news/2021/jul/13/nicelodeon-brawl-reportedly-rollback-wavedashing
- ONE Esports, rollback: https://www.oneesports.gg/gaming/nickelodeon-all-star-brawl-rollback/
- Windows Central, Game Pass surge: https://windowscentral.com/gaming/xbox/report-thanks-to-xbox-game-pass-this-2023-fighting-game-just-got-a-34744-player-count-boost
- vpesports, NASB2 sales/context: https://vpesports.com/new-xbox-game-pass-title-sees-massive-player-surge
- SteamPulse NASB2: https://steampulse.org/game/2017080

**Indie**
- Raijin, Stick Fight: https://raijin.gg/app/674940/Stick_Fight_The_Game
- Vaporlens, Stick Fight: https://vaporlens.app/app/674940/stick_fight_the_game/stats/details

**Roblox**
- RoWatcher TSB: https://rowatcher.com/games/3808081382
- profitable.app TSB: https://profitable.app/roblox/games/the-strongest-battlegrounds
- allthings.how TSB roster: https://allthings.how/the-strongest-battlegrounds-character-roster-movesets-and-access-rules/
- earnaldo TSB vs JJS: https://earnaldo.com/blog/the-strongest-battlegrounds-vs-jujutsu-shenanigans
- earnaldo JJS: https://earnaldo.com/blog/jujutsu-shenanigans
- RoWatcher JJS 338K: https://rowatcher.com/news/jujutsu-shenanigans-surges-past-338k-peak-players-after-disaster-plants-update
- RoWatcher Untitled Boxing Game: https://rowatcher.com/games/4730278139/untitled-boxing-game
- RoWatcher Blox Fruits review: https://rowatcher.com/news/is-blox-fruits-worth-playing-in-2026-an-honest-review
- Blox Fruits Wiki bounty/honor: https://blox-fruits.fandom.com/wiki/Bounty_and_Honor_System
- PHIGHTING! wiki: https://phighting.wiki/PHIGHTING!
- DevForum, Smash-type on Roblox: https://devforum.roblox.com/t/could-a-super-smash-bros-type-game-succeed-on-the-roblox-platform/824442
- DevForum, Brickbattle Grand Arena: https://devforum.roblox.com/t/thoughts-on-brickbattle-grand-arena-ssb-type-game-devlog/2051347
- DevForum, Super Brawl Blox: https://devforum.roblox.com/t/super-brawl-blox/937940
- DevForum, client-side hitbox: https://devforum.roblox.com/t/2672420
- DevForum, combat with rollback: https://devforum.roblox.com/t/combat-system-with-rollback/3685525
- DevForum, fair hitboxes: https://devforum.roblox.com/t/whats-the-best-way-to-handle-fair-hitboxes-in-a-multiplayer-scenario/3971560
- Sportskeeda, TSB tips/toxicity: https://sportskeeda.com/roblox-news/5-things-know-playing-roblox-the-strongest-battlegrounds
- Roblox demographics (mobile share, ages): https://explodingtopics.com/blog/roblox-stats , https://www.statista.com/statistics/1190309/daily-active-users-worldwide-roblox
- Games that died (low-quality source): https://grandavehousing.calpoly.edu/news/roblox-games-that-died-a

**Brainrot**
- PocketGamer.biz, 25M CCU: https://www.pocketgamer.biz/robloxs-steal-a-brainrot-becomes-first-game-to-surpass-25m-concurrent-players
- Wikipedia, Steal a Brainrot: https://en.wikipedia.org/wiki/Steal_a_Brainrot
- RoWatcher, Is the brainrot trend dying: https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals
- Dexerto, Tung Tung Sahur legal fight: https://www.dexerto.com/roblox/tung-tung-sahur-is-at-the-center-of-a-bizarre-federal-custody-battle-over-brainrot-characters-3381733
- Wikipedia, Tung Tung Tung Sahur: https://en.wikipedia.org/wiki/Tung_Tung_Tung_Sahur
- Aftermath, Steal a Brainrot clone lawsuit: https://aftermath.site/brainrot-roblox-court/
- Licensing Magazine, toy rights: https://www.licensingmagazine.com/2026/02/06/phatmojo-signs-global-toy-rights-to-steal-a-brainrot/
- Guinness, Bruno Mars concert: https://www.guinnessworldrecords.com/news/commercial/2026/2/bruno-mars-hosts-largest-concert-in-a-videogame-during-steal-a-brainrot-on-roblox
