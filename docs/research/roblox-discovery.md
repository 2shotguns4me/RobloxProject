# Roblox Discovery and Growth Research (as of October 2026)

How Roblox's discovery and recommendation systems work in 2025-2026, and what that means for our 2.5D brainrot/public-domain platform fighter.

**Source labels:** **[Official]** = Roblox docs, DevForum staff posts, Roblox newsroom, SEC filings. **[Press]** = journalism. **[Creator]** = third-party creator or analytics-site analysis, i.e. informed opinion. **[unverified]** = could not confirm from a primary source.

---

## Top takeaways for our game

1. **Organic Home traffic is the main way games get found, and it ranks games mainly on what players do after they click from Home.** The top four signals in "Recommended for You" are play-through rate, first-play bounce rate (under 60s and 61-180s), play days per user (D1, D2-7, D8-28) and playtime per user (capped at 60 min/day). Social co-play days, qualified sessions, spend days and Robux spent come next. All of these are measured only on players who arrived organically from that Home sort. [Official] (https://create.roblox.com/docs/en-us/discovery.md)
2. **Since mid-2026, retention is measured over 28 days instead of 7.** Day 8-28 return visits now count directly, so a launch spike without a reason to return will fade. [Official] (https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)
3. **The first 3 minutes decide a lot.** The under-60s and 61-180s bounce buckets are top signals. Players need to be in a fight within about 15-30 seconds: no long menus, no forced tutorial wall, and a mobile-friendly first match. Bots fill empty lobbies.
4. **New games start out invisible to under-16s.** A new game is shown only to age-checked users 16+ until it gets 250 unique plays from "highly engaged age-checked users" within 60 days and passes a safety review. Only then does it open to Roblox Kids (5-8) and Roblox Select (9-15). The creator also needs facial or ID age verification, 2FA, and either 2 months of Premium/Plus or a refundable publishing fee. Seeding real 16+ players at launch is a hard prerequisite for reaching the core brainrot audience. [Official] (https://create.roblox.com/docs/production/publishing/kids-and-select)
5. **Keep the content-maturity label at "Mild" (Minimal if we can).** Kids accounts only see Minimal/Mild games, and Moderate excludes ages 5-8. Cartoon fighting with no realistic blood fits Mild ("repeated mild violence, heavy unrealistic blood ... mild crude humor"). Unrated games became unplayable on 30 Sep 2025. [Official] (https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)
6. **Upload 3-10 thumbnails from day one** so thumbnail personalization (Roblox's built-in thumbnail A/B test) can run. In Roblox's testing it raised qualified play-through rate by an average of 8.5%, and by up to 50% for some games. Thumbnails have to show real gameplay. [Official] (https://create.roblox.com/docs/en-us/production/publishing/thumbnails.md)
7. **Build social features into the core loop.** "Intentional co-play days" (joining friends, invites, private servers) is a ranking signal. Use `SocialService:PromptGameInvite` with `ExperienceInviteOptions` and LaunchData to reward both the inviter and the invited friend, and add party queues and cheap or free private servers. [Official] (https://create.roblox.com/docs/production/promotion/invite-prompts)
8. **Borrow the brainrot meta-loop: collect characters, rarity tiers, timed rotating shops and weekly limited events.** Steal a Brainrot and Grow a Garden grew on collection, rarity chase, regular (often Saturday) updates, live "admin abuse" events, and TikTok/YouTube clips. We should add a character collection layer with rarity tiers on top of the fighting. [Press/Creator] (https://en.wikipedia.org/wiki/Steal_a_Brainrot)
9. **Legal warning: do not use existing Italian-brainrot characters (Tung Tung Tung Sahur, etc.).** Mementum Lab claims copyright and trademark rights to several of them, says it has licensed them to other games, and is in active federal litigation with Steal a Brainrot's owners. Make original "brainrot-style" characters, and use public-domain characters only from verified public-domain sources. [Press] (https://www.npr.org/2026/08/19/nx-s1-5867638/artificial-intelligence-brainrot-memes-copyright-spyder-tung-tung-sahur, https://www.dexerto.com/roblox/tung-tung-sahur-is-at-the-center-of-a-bizarre-federal-custody-battle-over-brainrot-characters-3381733/)
10. **Monetize with cosmetics, game passes and an optional subscription, and avoid pay-to-win.** Robux spent and spend days are ranking signals. Creator Rewards (which replaced Premium Payouts in July 2025) also pays 5 Robux per Active Spender who plays 10+ minutes a day, so longer engaged play earns money even without purchases. [Official] (https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628)
11. **Ads are a tool for starting out, not a replacement for organic traffic.** Ads Manager runs on auto-bidding and reports cost-per-play. Roblox says "Running ads should not harm your organic distribution", but players who arrive from ads do not count toward the Home ranking signals. Use a small "Engagement" campaign to reach the Kids/Select threshold and to test the core loop. [Official] (https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157)
12. **Design for phones first.** About 80% of users access Roblox on mobile [Press, citing Roblox data] (https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue). That means touch controls with at most 3-4 ability buttons, readable 2.5D framing on small screens, and stable performance on low-end Android.

---

## Launch checklist

**Before publishing**
- [ ] Creator account: age verification (face scan or ID), 2FA, Premium/Plus for 2 months or the publishing fee paid. This is required for Kids/Select eligibility.
- [ ] Complete the Experience Guidelines / content-maturity questionnaire honestly and target **Mild**: cartoon hit effects, no realistic blood, crude humor at fart-cloud level at most.
- [ ] Use original character designs and names. Check every public-domain character for a trademarked modern version (e.g. avoid Disney-specific Winnie-the-Pooh traits).
- [ ] Time to first fight under 30 seconds on mobile. Lobby bots fill matches when CCU is low.
- [ ] Mobile touch UI, console gamepad and keyboard all tested. Run performance passes on a low-end Android device.
- [ ] Analytics: custom events for the funnel (join, first match start, first match end, first unlock, second session). Set up the Experiments/Configs tools.
- [ ] Social: invite prompt with LaunchData rewards, party join, a friends-online indicator, and free or cheap private servers.
- [ ] Monetization: cosmetic skins, emotes, KO effects, a VIP/2x-currency pass, an optional battle-pass-style subscription. Nothing sold that wins fights directly.

**Store page**
- [ ] Icon: one large, high-contrast character face that reads at thumbnail size.
- [ ] 5+ thumbnails (1920x1080, 16:9, real gameplay, no key elements in the bottom strip) plus 1-3 video thumbnails (no voiceover or lyrics). Turn on personalization.
- [ ] Clear title with the genre in it, e.g. "Brainrot Battlegrounds" style naming. Name the characters and modes in the description. Never imply giveaways or free Robux.
- [ ] Set the correct genre/subgenre so the game shows up in the right Charts filters.

**Launch week**
- [ ] Soft launch to 16+ players (Discord, friends, small ad budget) to reach 250 engaged age-checked plays quickly.
- [ ] Publish the update on Friday afternoon or Saturday (US time), right before the weekend peak. Prepare TikTok/Shorts clips 24-48 hours in advance.
- [ ] Contact 5-10 small and mid-size Roblox YouTubers/TikTokers with early access and exclusive skin codes.
- [ ] Each day, check D1 retention, sub-3-minute bounce, and retention by acquisition source.

**Ongoing**
- [ ] Weekly content drop (new fighter, skin rotation or stage) on a fixed day. Run a monthly limited-time event.
- [ ] Hold regular live dev "admin" events, announced ahead of time.
- [ ] Run A/B tests on onboarding, unlock pacing and prices with Experiments and Price Optimization.

---

## 1. How the recommendation system ranks games

### 1.1 Home "Recommended for You" [Official]
Roblox's discovery doc (https://create.roblox.com/docs/en-us/discovery.md) says the sort "personalizes content and connects users with games that foster deep engagement, social interaction, and repeat play." The system first retrieves candidate games using engagement, retention and monetization signals, then ranks them for each viewer.

**Signals and their relative importance (official list):**

| Tier | Signal | Roblox definition (quoted/paraphrased) |
|---|---|---|
| Most important | Play-through rate | "The rate at which users play your game after seeing it in the Recommended for You sort." |
| Most important | First play bounce rate | "The rate at which users leave your game after a short play session". Two buckets: under 60s and 61-180s. A negative signal. |
| Most important | Play days per user | Average unique days played, split into D1, D2-D7 and D8-D28 |
| Most important | Playtime per user | "There is a maximum of 60 minutes per user, per game, per day." |
| Important | Intentional co-play days per user | "unique days that users come back to play your game with friends, including co-play days through join, invites, or private servers" |
| Important | Qualified play sessions per user | "A 'qualified play' refers to a user's meaningful play session" (filters out accidental clicks and quick bounces) |
| Important | Spend days per user | Unique days users spend Robux in the game |
| Important | Robux spent per user | Average Robux spent |

- **Only organic Home users count.** All of these signals are "based on users who organically joined from the Recommended for You sort on Home." Traffic from ads, curation, search or friends is left out.
- **"Explore and expand" phases** (quoted): "you might see a spike in new users from recommendations (explore) after a content update. If that new user cohort has good engagement and monetization, Roblox is more likely to continue to recommend your game to more such user cohorts (expand)." In practice, every update earns a fresh test audience, and that group's behavior decides whether the game keeps growing.
- **Things that reduce visibility:** metadata that suggests giveaways, metadata that doesn't match the content, and "Games with metadata and place files that closely resemble existing games on Roblox are no longer prioritized for recommendations." Reskinned clones are therefore penalized. Our game needs real mechanical differences from the existing battlegrounds games.

### 1.2 Changes in 2025-2026
- **June 2026, 7-day to 28-day window** [Official]. Chief Growth Officer John Ciancutti wrote: "Long-term retention was always an important signal in our algorithm, but we previously used 7-day proxies to get an early signal of retention." Roblox reports that the new version "did a significantly better job surfacing games that retain players over time." The old combined qualified play-through rate (qPTR) was split into separate play-through, session-quality and spend signals. Creators can now see the signal list and its weights in Creator Analytics. (https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)
- **RDC 2026 (11 Sep 2026)** [Press]: rankings will use data from beyond the first 28 days, and Roblox is testing a per-game "new user acquisition" measure. Ranking is becoming **age-aware**: younger players are shown shorter, quicker games, while older players are shown games built for return visits. Moments (short gameplay clips you can tap to join) is fully available in the US, and clips are coming to experience detail pages. (https://www.invenglobal.com/articles/25918/roblox-unveils-expansions-to-play-creation-and-monetization-at-rdc, https://www.panstag.com/2026/09/rdc-solo-creator-guide.html [Creator])
  - *Implication:* a fighter with 2-4 minute matches suits younger players' short sessions, and character collection and progression provide the depth older players come back for. That is a good fit for both groups.
- **RDC 2025 (Sep 2025)** [Official]: Moments launched in beta (30-second clips with music, and viewers can "instantly join the highlighted game with a tap"; users 13+ at launch). DevEx rate raised 8.5%. (https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery, https://about.roblox.com/newsroom/2025/09/roblox-rdc-2025)
- **Kids/Select accounts (announced 13 Apr 2026, global June 2026)** [Official/Press]: see section 7. (https://create.roblox.com/docs/production/publishing/kids-and-select)

### 1.3 Charts / Discover page
- **"Top Playing Now"** launched globally on 29 Apr 2025 and ranks games by real-time CCU. Roblox also said it was adding genre filters, console/VR support and event sorts. [Official] (https://devforum.roblox.com/t/introducing-top-playing-now-on-charts/3529809)
- Other sorts: Most Popular, Top Trending/Hot Right Now, Up-and-Coming, Top Rated, Top Revisited, plus genre filters. Charts genre placement uses the genre/subgenre you set. [Official] (https://create.roblox.com/docs/en-us/production/publishing/experience-genres)
- Up-and-Coming is described as growth-rate based and updated hourly [Creator] (https://pinkcrow.net/roblox-charts-a-complete-guide/). DevForum users say it in practice shows games at about 10K-200K CCU [Creator, unverified]. A brand-new game will not chart. Charts follow from organic success; they do not cause it.
- **"Today's Picks"** as an official program is curation for the **Marketplace** (avatar items) and is being cut back in favor of personalized recommendations [Official] (https://create.roblox.com/docs/en-us/creator-programs/todays-picks-marketplace). Curated game sorts on Home exist, but there is no public application process for games [unverified].

### 1.4 Search
Search supports semantic matching across official languages [Official] (discovery doc). Search Ads in Ads Manager can target keywords [Official] (https://create.roblox.com/docs/en-us/monetize-experiences.md). Put the genre words players actually search for ("battlegrounds", "brainrot", "fighting", "smash") in the title and description, but never in a misleading way.

---

## 2. Analytics and benchmarks

- **Dashboard areas:** Retention (D1/D7/D30), Engagement (session time, playtime), Monetization (payer conversion, ARPPU, ARPDAU), Acquisition (sources), funnels, custom events, and player segments (`AnalyticsService:GetPlayerSegmentsAsync()`). [Official] (https://create.roblox.com/docs/en-us/production/analytics.md)
- **What to watch first** (quote): "D1 (day 1) retention and average session time are key metrics to focus on first ... D7 (day 7) and D30 (day 30) retention measure if users are making progress in your experience and returning long-term." [Official]
- **Benchmarks:** these unlock at **100+ DAU** and show the 50th-90th percentile range of similar games, drawn from the top 1000 games by playtime (games over 30 days old), with Top 200/500/1000 tiers. Roblox's docs give an example D1 band of **12.4%-24.1%** (50th to 90th percentile). Roblox states that benchmarks "don't impact your home recommendation distribution." (https://create.roblox.com/docs/en-us/production/analytics.md)
- **Oct 2025 additions:** retention broken down by acquisition source, and a choice between genre and similar-game benchmarks. [Official] (https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157)
- **Experiments and Configs (updated Aug 2026):** in-game and matchmaking A/B tests, segment targeting, automatic alerts when playtime, ARPU or conversion drop, and live config changes without server restarts. [Official] (https://about.roblox.com/newsroom/2026/08/optimize-testing-live-updates-roblox-analytics-experimentation-platform, https://create.roblox.com/docs/en-us/production/experiments)

**Practical targets** (third-party estimates, not official): action/shooter games D1 22-30% and D7 12-16% [Creator] (https://rowatcher.com/news/retention-benchmarks-by-roblox-genre-what-good-actually-looks-like). Our working goals: **D1 at least 25%, D7 at least 10%, D30 at least 4%, average session at least 15 minutes**, and fewer than 30% of new players leaving within 3 minutes [our own targets, unverified as platform norms]. Always compare against the Roblox benchmark scorecard once we pass 100 DAU.

---

## 3. Thumbnails, icons, titles, descriptions

- **Specs:** 16:9, 1920x1080, up to 10 thumbnails, max 3 MB. Video thumbnails: 3 uploads per month, real gameplay only, no spoken audio or lyrics, and not supported on Xbox/PlayStation/VR. Don't put essential elements in the bottom area, where metadata overlays them. No "misrepresented gameplay" or misleading claims. [Official] (https://create.roblox.com/docs/en-us/production/publishing/thumbnails.md)
- **Thumbnail personalization (built-in A/B testing):** it turns on with 2+ thumbnails. Each thumbnail is shown to random groups of players, the winner gets most impressions, and some exploration continues. Average +8.5% qPTR, up to +50% for some games. Since mid-2025 it keeps your existing winners when you add new thumbnails to test. [Official] (https://devforum.roblox.com/t/thumbnail-personalization-now-remembers-your-existing-winning-thumbnails/3793665)
- **Icons:** there is no official icon A/B test; developers are asking for one [Official DevForum feature request] (https://devforum.roblox.com/t/icon-ab-testing/3274267). Swap icons manually and compare play-through rate week over week.
- **Title tags like [UPDATE] or emojis:** I found **no official documentation saying they help ranking**. Ranking is based on behavior (play-through and retention), not keywords. They may raise click-through from returning players, but Roblox penalizes metadata that doesn't match the content or suggests giveaways, and some emojis (e.g. the dollar sign) have caused title moderation [Official DevForum report] (https://devforum.roblox.com/t/we-need-more-information-on-why-place-name-or-description-is-inappropriate/353001). Treat them as an optional test, not a growth lever [unverified].
- Creator advice: treat the thumbnail "as a conversion ad", with one clear focal character, strong contrast and a clear action [Creator] (https://rowatcher.com/news/the-roblox-thumbnail-is-a-conversion-ad-stop-designing-it-like-art).

---

## 4. Paid promotion

- **Ads Manager** [Official] (https://create.roblox.com/docs/en-us/production/promotion/ads-manager.md):
  - Objectives: **Plays**, **Earnings** (limited availability), and **Engagement**. Engagement targets "age-checked highly engaged players" to help a game meet the Kids and Select thresholds, which is exactly our launch problem.
  - Formats: sponsored thumbnails on Home and in search, plus in-game portal ads. Up to 10 thumbnails per campaign. Auto-bidding with daily or lifetime budgets. Pay by card (18+) or with ad credit converted from Robux, which is irreversible. Attribution window up to 30 days. Reports cost-per-play (CPP) and, for Earnings campaigns, ROAS.
  - In May 2025 Roblox reported a 44% drop in cost per play and an 89% improvement in qPTR on the new Ads Manager flow [Official] (https://devforum.roblox.com/t/more-ads-manager-upgrades/3659656).
  - No minimum budget is documented. Real cost per play varies; small campaigns are commonly reported in the cents-per-play range [unverified].
- **Ads don't hurt organic traffic, and they don't help it directly either.** Players from ads are left out of the Home ranking signals, and Roblox says "Running ads should not harm your organic distribution." [Official] (https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157)
- **Rewarded video ads (income for us, not promotion):** self-serve for games with **100K+ average DAU over 28 days**, a Minimal or Mild maturity label, and good standing. Not relevant at launch [Press/Creator] (https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678, https://ppc.land/roblox-expands-google-advertising-partnership-with-rewarded-video-launch/). Reported CPMs of $5-15 are [Creator, unverified] (https://rolearn.dev/insights/rewarded-video-ads-new-revenue-stream).

---

## 5. Social and virality

- **Invite prompts** [Official] (https://create.roblox.com/docs/production/promotion/invite-prompts): `SocialService:PromptGameInvite(player, ExperienceInviteOptions)`, checked first with `CanSendGameInviteAsync` inside a pcall. Options: `PromptMessage`, `InviteUser` (a specific friend), `InviteMessageId` (custom notification text, which must include `{experienceName}`), and `LaunchData` (up to 200 characters, read with `Player:GetJoinData()`, which can take a few seconds to arrive). Use it to reward both sides and to drop the invited friend straight into the inviter's party.
- **Why this matters for ranking:** co-play through join, invites or private servers is an official "important" signal. Good ideas: a "Play with a friend" bonus, 2v2 team modes, and free private servers for small groups.
- **Moments (on-platform short video):** clips players can tap to join; US-wide as of RDC 2026. Add an in-game clip or replay button for big KOs once the Moments APIs are available. [Official/Press]
- **TikTok and YouTube Shorts:** Steal a Brainrot's spread was driven by "tens of millions of views" of tips and reaction videos (kids upset about losing their characters) [Press] (https://en.wikipedia.org/wiki/Steal_a_Brainrot). A fighter gets clips naturally: huge KO launches, funny character voice lines, rare-character pulls. Make the camera framing and KO effects look good in a vertical crop.
- **Influencers:** the Roblox Video Stars program requires 100K+ followers, with long-form creators also needing 25K+ average views over 6 months; it covers EN/ES/PT/DE/FR/JA/KO creators [Official] (https://influencers.roblox.com/requirements). Video Stars members are a sensible list to contact, but small and mid-size creators are cheaper and more likely to cover a new game [Creator opinion]. Creator Rewards' Audience Expansion pays **35% of the first $100 of Robux purchases by new or returning users** you bring in during their first two months, so sharing a link with influencers is directly rewarded [Official] (https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628).
- **Groups:** the group owns the game, and group members get notifications and community perks. Use group-only skins to grow membership [general practice, unverified as a ranking factor].

---

## 6. Update cadence and live events

- **Explore and expand** (official, section 1.1): each update can earn a new test audience from recommendations. More frequent quality updates mean more chances to grow.
- **Weekly peak timing** [Creator]: Roblox CCU follows a weekly cycle, with the weekend-evening peak (about 4-8 PM EST) roughly double the weekday-morning low. Friday 3-5 PM EST or Saturday are recommended release times (https://rowatcher.com/news/when-is-roblox-busiest-we-mapped-every-hour-of-the-week, https://rowatcher.com/news/how-to-launch-a-roblox-game-in-2026-the-pre-launch-playbook).
- **Grow a Garden** updated weekly on Saturdays (new seeds, pets, items), and players came to expect it as an appointment [Press/Creator] (https://www.digitalcitizen.life/grow-a-garden-admin-abuse-schedule/).
- **Live dev events ("admin abuse"):** limited-time events the developer triggers by hand, handing out boosts and exclusives. The staged "Admin Abuse War" between Grow a Garden and Steal a Brainrot on 23 Aug 2025 pushed both games past 20M+ CCU [Press] (https://en.wikipedia.org/wiki/Steal_a_Brainrot). For us: weekly "Brainrot Boss Raid" or "double-XP chaos hour" events announced in advance.
- **Battlegrounds games:** The Strongest Battlegrounds (Yielding Arts, launched Aug 2022 as "Saitama Battlegrounds") has kept its numbers through years of big character updates with new modes such as 3v3 and regional matchmaking [Creator/Press] (https://rowatcher.com/games/3808081382/the-strongest-battlegrounds, https://sportskeeda.com/roblox-news/5-things-know-playing-roblox-the-strongest-battlegrounds). Jujutsu Shenanigans peaked at about 338K CCU two days after its 20 Mar 2026 "Disaster Plants" update [Creator] (https://rowatcher.com/news/jujutsu-shenanigans-surges-past-338k-peak-players-after-disaster-plants-update). **Pattern:** each new character or move-set update brings a CCU spike and a wave of YouTube "new character showcase" videos.

---

## 7. Age ratings and the new Kids/Select gate

- **Labels** [Official] (https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md):
  - Minimal: "occasional mild violence and/or light unrealistic blood"
  - Mild: "repeated mild violence, heavy unrealistic blood, mild fear-based content, and/or mild crude humor" (fart clouds count as Mild)
  - Moderate: "moderate violence, light realistic blood ... moderate crude humor, and/or unplayable gambling content"
  - Restricted: 18+ age-verified players only
- **Who can play what:** Minimal/Mild is open to Kids (5-8) and Select (9-15). Moderate is open to Select and 16+. Restricted is 18+ only. Restricted games are also unplayable in some regions (e.g. Korea, Saudi Arabia, Turkey).
- **Kids/Select evaluation** [Official] (https://create.roblox.com/docs/production/publishing/kids-and-select): the game is first shown "only to age-checked users 16 and older". Engagement is checked for bots, the game's real-time moderation reports and gameplay are reviewed, and once it hits "250 unique plays by highly engaged age-checked users within a 60-day window" it becomes eligible for Kids/Select. Note: press coverage from April 2026 said 500 plays; the current doc says 250 [discrepancy noted].
- **Also from the Kids/Select doc:** the creator must be age-verified, have 2FA on, and have either 2 months of Premium/Plus or have paid the refundable publishing fee.
- **Unrated games** became unplayable on 30 Sep 2025 [Official/Press] (https://create.roblox.com/docs/en-us/production/promotion/experience-guidelines).
- **Monetization link:** rewarded video ads also require a Minimal or Mild label.

### Moderation and other pitfalls
- **IP:** see takeaway 9. Brainrot characters are now actively contested (cease-and-desist sent Sep 2025, with federal litigation and trademark counterclaims under way in 2026). Unlicensed use is a takedown risk. Steal a Brainrot also faced an unlicensed Fortnite clone lawsuit and criticism for pay-to-win [Press].
- **Clones:** games whose metadata and place files closely resemble existing games are deprioritized [Official].
- **Giveaway or "free Robux" metadata** gets reduced visibility [Official].
- **Fake engagement:** bots are filtered out of the Kids/Select evaluation by design [Official]. Botting visits or favorites breaks the Terms of Use, and its detection is described in third-party sources [Creator/Press] (https://arkoselabs.com/resource/roblox-protects-meaningful-game-engagement-with-enforcement). Since signals use only organic Home users, botting can't help ranking anyway.
- **Looking low-quality:** high bounce in the first 60s and 61-180s is directly penalized. Unclear onboarding, lag on mobile and empty servers all feed into this.
- **Gambling-like mechanics:** paid random character pulls need care. "Unplayable gambling content" is a Moderate descriptor, and Roblox has separate paid random item policies [general knowledge; verify current paid-random-items policy before shipping, unverified]. A safer design: earn characters through play, buy cosmetics directly, and show rarity odds.

---

## 8. Why brainrot games blew up in 2025, and what a fighter can borrow

| Driver | Steal a Brainrot / Grow a Garden | Our fighter's version |
|---|---|---|
| Collection and rarity chase | Conveyor-belt brainrots in rising rarity tiers, mutations | Unlockable fighters and skins with rarity tiers and "mutated" variants (e.g. golden or rainbow skins) |
| Passive and short sessions | Idle income, come back to collect | Daily login chest, 3-minute matches, daily quests |
| Social conflict | Stealing from other players' bases (capture-the-flag style) | Bounty system: KO the top player for bonus rewards. 2v2 with friends. |
| Live events | "Admin abuse" sessions, the staged admin war | Weekly dev-hosted chaos events and boss raids |
| Scheduled updates | Weekly Saturday drops | Weekly new fighter or skin rotation on a fixed day |
| Clip-friendly moments | Kids reacting to losing their brainrots | Big KO launches, character voice lines, rare unlock reveals |
| Meme recognition | Italian brainrot memes | Original brainrot-style characters (because of IP risk) plus public-domain characters |

Sources: (https://en.wikipedia.org/wiki/Steal_a_Brainrot) [Press], (https://www.rpgstash.com/blog/steal-a-brainrot-ccu-record-25-million-players) [Creator]. Records: Steal a Brainrot reached about 25.4M CCU (Oct 2025) and Grow a Garden about 22-23M; the Roblox platform record was 47.4M concurrent. Roblox DAU peaked at about 152M (Q3 2025) and fell to about 123M by Q2 2026 [Press] (https://interspacemusic.com/blog/roblox-daily-active-users-fall-to-123-million-in-q2-2026/), so competition for attention is getting tougher.

---

## 9. Monetization that helps ranking without being pay-to-win

- **What the algorithm counts:** spend days per user and Robux spent per user (both "important" tier). Spending regularly on many days counts, not just big one-off purchases. That favors daily shops, rotating skins, and subscriptions.
- **Available tools** [Official] (https://create.roblox.com/docs/en-us/monetize-experiences.md): Passes (creator keeps 70% on direct sales), Developer Products, Subscriptions, Private Servers, Paid Access, Price Optimization, selling avatar items, Avatar Creation Tokens, Immersive Ads, Search Ads, and Creator Rewards.
- **Creator Rewards** (from 24 Jul 2025, replaced Premium Payouts / Engagement-Based Payouts) [Official] (https://devforum.roblox.com/t/creator-rewards-is-live/3838257):
  - Daily Engagement: 5 Robux per Active Spender (spent at least $9.99 in the last 60 days) who plays 10+ minutes in a day, if ours is one of the first 3 games they open that day.
  - Audience Expansion: 35% of the first $100 of purchases by new or returning users we bring in.
  - No cap, but a 60-day hold before payout.
- **Suggested setup:** cosmetic skins, emotes, KO effects and victory poses; a VIP pass (chat tag, 1.25x currency, free private server); a monthly "Brainrot Club" subscription (daily currency, an exclusive skin each month); and Price Optimization tests. Fighters are earned through play, and every fighter is balanced the same whether earned or bought.

---

## 10. Mobile first

- About **80% of users are on mobile**, and mobile was **46% of Robux revenue in 2024** (App Store 30%, Google Play 16%) [Press, citing Roblox filings] (https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue). Other estimates: mobile is about 72% of activity [Creator, unverified] (https://gamedevreports.substack.com/p/newzoo-roblox-as-a-platform-in-2025).
- **What this means for us:**
  - Thumb-reachable controls: joystick, jump, attack, special, shield/dodge.
  - Auto-targeting assists.
  - Camera zoom that keeps all fighters on screen in landscape.
  - A low-graphics mode and a particle budget.
  - Large UI text.
  - Short matches that fit commute or bedtime sessions.
- RDC 2026's "Roblox Everywhere" (standalone apps, playing in Chrome from the game's page by the end of 2026) will make the web link a lower-friction entry point for external traffic [Press] (https://www.invenglobal.com/articles/25918/roblox-unveils-expansions-to-play-creation-and-monetization-at-rdc).

---

## Sources

**Official (Roblox)**
- Discovery doc: https://create.roblox.com/docs/en-us/discovery.md
- Optimizing discovery (Jun 2026): https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
- Kids and Select: https://create.roblox.com/docs/production/publishing/kids-and-select
- Content maturity: https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md
- Experience guidelines: https://create.roblox.com/docs/en-us/production/promotion/experience-guidelines
- Thumbnails: https://create.roblox.com/docs/en-us/production/publishing/thumbnails.md
- Thumbnail personalization update: https://devforum.roblox.com/t/thumbnail-personalization-now-remembers-your-existing-winning-thumbnails/3793665
- Icon A/B request: https://devforum.roblox.com/t/icon-ab-testing/3274267
- Analytics: https://create.roblox.com/docs/en-us/production/analytics.md
- Retention by acquisition source (Oct 2025): https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157
- Experiments: https://create.roblox.com/docs/en-us/production/experiments
- Analytics/experimentation (Aug 2026): https://about.roblox.com/newsroom/2026/08/optimize-testing-live-updates-roblox-analytics-experimentation-platform
- Ads Manager: https://create.roblox.com/docs/en-us/production/promotion/ads-manager.md
- More Ads Manager upgrades: https://devforum.roblox.com/t/more-ads-manager-upgrades/3659656
- Rewarded video: https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678
- Top Playing Now: https://devforum.roblox.com/t/introducing-top-playing-now-on-charts/3529809
- Experience genres: https://create.roblox.com/docs/en-us/production/publishing/experience-genres
- Today's Picks (Marketplace): https://create.roblox.com/docs/en-us/creator-programs/todays-picks-marketplace
- Invite prompts: https://create.roblox.com/docs/production/promotion/invite-prompts
- Monetize experiences: https://create.roblox.com/docs/en-us/monetize-experiences.md
- Creator Rewards: https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628 , https://devforum.roblox.com/t/creator-rewards-is-live/3838257
- RDC 2025: https://about.roblox.com/newsroom/2025/09/roblox-rdc-2025 , Moments: https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery
- Video Stars: https://influencers.roblox.com/requirements

**Press**
- Steal a Brainrot (Wikipedia): https://en.wikipedia.org/wiki/Steal_a_Brainrot
- NPR on the brainrot IP case: https://www.npr.org/2026/08/19/nx-s1-5867638/artificial-intelligence-brainrot-memes-copyright-spyder-tung-tung-sahur
- Dexerto on the Tung Tung Sahur case: https://www.dexerto.com/roblox/tung-tung-sahur-is-at-the-center-of-a-bizarre-federal-custody-battle-over-brainrot-characters-3381733/
- RDC 2026 (Inven Global): https://www.invenglobal.com/articles/25918/roblox-unveils-expansions-to-play-creation-and-monetization-at-rdc
- Mobile share (PocketGamer.biz): https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue
- DAU trend: https://interspacemusic.com/blog/roblox-daily-active-users-fall-to-123-million-in-q2-2026/
- Rewarded video (PPC Land): https://ppc.land/roblox-expands-google-advertising-partnership-with-rewarded-video-launch/

**Creator / third-party analysis**
- RDC 2026 solo-creator guide: https://www.panstag.com/2026/09/rdc-solo-creator-guide.html
- Retention benchmarks by genre: https://rowatcher.com/news/retention-benchmarks-by-roblox-genre-what-good-actually-looks-like
- Peak hours: https://rowatcher.com/news/when-is-roblox-busiest-we-mapped-every-hour-of-the-week
- Launch playbook: https://rowatcher.com/news/how-to-launch-a-roblox-game-in-2026-the-pre-launch-playbook
- Thumbnails as ads: https://rowatcher.com/news/the-roblox-thumbnail-is-a-conversion-ad-stop-designing-it-like-art
- Jujutsu Shenanigans surge: https://rowatcher.com/news/jujutsu-shenanigans-surges-past-338k-peak-players-after-disaster-plants-update
- TSB stats: https://rowatcher.com/games/3808081382/the-strongest-battlegrounds
- Grow a Garden admin abuse: https://www.digitalcitizen.life/grow-a-garden-admin-abuse-schedule/
- Steal a Brainrot CCU: https://www.rpgstash.com/blog/steal-a-brainrot-ccu-record-25-million-players
- Charts guide: https://pinkcrow.net/roblox-charts-a-complete-guide/
- Rewarded video estimates: https://rolearn.dev/insights/rewarded-video-ads-new-revenue-stream
- Newzoo platform report summary: https://gamedevreports.substack.com/p/newzoo-roblox-as-a-platform-in-2025
- Bot enforcement case study: https://arkoselabs.com/resource/roblox-protects-meaningful-game-engagement-with-enforcement
