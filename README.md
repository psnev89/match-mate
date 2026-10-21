# Match Mate

A small Vue 3 application for one friend group's two recurring teams. Uses Vue Router, Pinia, Tailwind CSS, Supabase and vite-plugin-pwa. No custom backend server is needed.

## Run locally

Use Node.js 22.12+ (or a newer supported LTS release).

```bash
npm install
cp .env.example .env.local
```

Fill in `.env.local` with your Supabase project URL and **publishable key**. An older project's public anon key also works. Never put a secret/service-role key in this app. Restart Vite after changing environment variables.

### New database

In the Supabase SQL editor, run `supabase/schema.sql` once. It contains all tables, policies and functions, including lineups, own goals and both player leaderboards.

### Upgrading the previous version

Do not recreate existing tables. Apply only the migrations you have not run, in order:

1. `supabase/migrations/002_lineups_and_own_goals.sql` — adds match lineups, own goals and win rates (skip if already applied).
2. `supabase/migrations/003_name_only_players_and_five_a_side.sql` — removes the unused usual-team field and requires exactly five players on each side.

3. `supabase/migrations/004_match_editing_and_profiles.sql` — adds atomic match edits, edit-conflict protection and player-profile statistics.

Each migration runs once. Migration 003 preserves players, match results, match-specific teams, goals and player statistics. It drops only `players.team_id`, the former usual-team association. Use the updated frontend after applying the migrations.

Old goals default to normal goals because their type was never recorded. Old matches keep counting toward team results and Golden Boot, but are excluded from win rates because their full attendance is unknown. The Player stats screen explains how many games are missing lineups. Do not infer attendance from goalscorers: that omits everyone who did not score.

For an older game whose full lineup you know, open the match from the dashboard and choose **Edit match**. Select the ten players, check its goals and save. Its attendance will then count toward player win rates. Inactive players already in an existing lineup remain selectable while editing; to add another inactive player to a historical game, first reactivate them from Players.

`supabase/leaderboard.sql` is an optional refresh of the two leaderboard functions after the new schema or migration; it is not a substitute for the migration.

### Member accounts

This app assumes one trusted, private group. Every authenticated account can read results, add/edit players and record matches.

1. In Supabase Authentication settings, disable **Allow new users to sign up** and leave anonymous sign-in disabled.
2. In Authentication → Users, use **Add user → Create new user** to create each friend's email/password account. Confirm the email when creating the account so they can sign in immediately.
3. Share credentials privately. Friends sign in using the app's email/password form.
4. For this small starter, the organizer handles forgotten passwords through Supabase's administrative user management. There is no self-service reset or registration screen.

Auth accounts and football players are separate: a friend who never signs in can still appear on a roster.

```bash
npm run dev
```

Open the printed URL. Without environment variables, the app displays setup instructions instead of crashing. Once signed in, add players under **Players**, then record a match under **Log match**.

## What is included

- Dashboard with season selector, Team A wins, Team B wins, draws, goal difference and ten recent matches. No points/league table.
- Five dropdowns under each team, followed by the result and goals. Ten distinct active players are required; selected players disappear from other dropdowns.
- Final scores and one goal entry per goal; own-goal checkbox selects a player from the opposite lineup.
- Atomic saving of match, lineup and goals with database validation.
- Golden Boot excluding own goals; normal goals count regardless of the player's team that day.
- Win-rate leaderboard: at least 5 appearances in the selected season; wins / games × 100, displayed to one decimal. Draws count in the denominator, not the numerator. Equal rates share rank.
- Add players by name, rename them, deactivate and reactivate them. No usual team is stored.
- Email/password sign-in, protected routes, sign-out and session persistence.
- Mobile layout, installable PWA manifest/icons, cached app shell and an update prompt.
- Match details showing lineups, scorers and own goals; edit results without deleting and recreating the match.
- Copy the most recent recorded lineups before the selected match date; inactive players leave empty slots for replacement.
- Player profiles with season appearances, goals, wins, draws, losses, goals/game and win rate.
- WhatsApp-style text summary, copy button and a WhatsApp link that opens a message for the user to send.
- Loading, empty, success and error states.

## Where the code lives

```text
src/
  views/           One file per screen
  components/      Shared season picker
  services/football.js  All football-related Supabase calls
  stores/auth.js       Signed-in user and auth actions
  stores/football.js   Selected season and shared roster
  lib/supabase.js      Supabase client configuration
  lib/stats.js         Team summary and date/score helpers
  router.js            Routes and sign-in guard
  App.vue              Shared header, navigation and update prompt
supabase/
  schema.sql           Tables, policies, save_match transaction
  leaderboard.sql      Both player leaderboard functions
```

A typical flow is: **view → service function → Supabase**. Shared roster data is loaded through the Pinia store. Match form state stays local to its view. Dashboard data reloads when you enter the screen or change seasons, so there is no cache invalidation system to learn.

### Add a player

The Players form calls `addPlayer(name)` in `src/services/football.js`. The service trims the name, inserts the row and throws any Supabase error back to the form. Editing uses `updatePlayer(id, { name, active })`.

### Save a match

`logMatch({ date, lineupA, lineupB, goalsA, goalsB })` calls PostgreSQL's `save_match` function. The lineups are arrays of player IDs. Each goal is `{ player_id, is_own_goal }`. `goalsA` always contains goals credited to Team A, including own goals scored by Team B players.

The database checks that players are active, nobody is selected twice, and each goal matches the actual lineup and goal type. It derives scores from goal array lengths and saves the result, appearances and goals in one transaction. A repeated goalscorer is allowed; a repeated appearance is not. Both sides need exactly five players, including in a 0–0 game. Players not selected are absent. You need at least ten active players in your roster.

### Example: an own goal

Select Alex in one of Team B's five lineup slots. If Alex scores into his own net, add that goal under **Team A**, tick **Own goal by Team B**, and choose Alex. The goal increases A's final score and goal difference but does not add a Golden Boot goal to Alex or anyone else. His win/loss comes from Team B's final result.

Each player dropdown offers active players who have not been picked elsewhere, plus its current selection. Clear a slot to release a player before swapping sides. If a lineup change invalidates a goal's scorer, that scorer selection clears automatically.

### Data model and season rules

- `players`: ID, name and active flag only; there is no team association on a player profile.
- `match_players`: one appearance per match/player, including the team actually played for.
- `goals.team_id`: team credited with the goal. With `is_own_goal = true`, the scorer played for the opposite team.
- `matches.lineup_recorded`: false for legacy games with unknown attendance; true for all games created by the new form.
- Match date determines the calendar season.
- One match per date prevents duplicate entries. After a dropped connection, check the dashboard before retrying.
- Scores are integers from 0 to 50.
- Players cannot switch sides during a single match in this version: choose one side per player per game.
- Both win rate and Golden Boot keep historical records when a player plays for a different side or is deactivated.
- Win-rate eligibility resets each year. A player with 4 games is excluded even at 100%; a player with 3 wins from 5 games has 60.0%. Non-scorers count equally.
- Win-rate ordering uses the unrounded fraction, with no artificial tie-breaker. Names only stabilize the display order of true ties.
- No attendance or wins are inferred from the current roster.
- Team names can be changed in Supabase's teams table; keep the A/B slots unchanged.
- Edit matches from their detail page. The server locks the match, checks its version, and replaces goals/appearances in the same transaction as the score. Any failure rolls back the entire change. An outdated editor is asked to reload rather than overwriting someone else's changes.
- Deleting matches is not included in the app. Organizers can still delete mistaken matches in Supabase; goals and appearances cascade-delete.

## PWA and hosting

```bash
npm test
npm run build
npm run preview
```

Deploy `dist/` to an HTTPS static host. Configure an SPA fallback so unknown paths serve `index.html` (for example `/roster`). The included `public/_redirects` supports Netlify-style hosting. Deploy at the domain root for the supplied manifest configuration.

The app shell is cached after a successful online visit. Supabase reads and writes still need an internet connection. There is no offline match queue or cached private match database. Errors preserve match entries for retry; closing or reloading a tab discards an unsaved form. The update prompt lets you finish a form before reloading.

On iOS, open the deployed HTTPS app in Safari and use Share → Add to Home Screen. On Android, use the browser's install/add-to-home-screen option. Icons are included at 192, 512 and 180 pixels. Production PWA behavior is tested from a build, not the development server.

## Quick manual check with your database

1. Sign in and add at least ten players by name.
2. In a new match, fill the five slots under Team A and five under Team B. Check that each selection disappears from other dropdowns. Leave non-attendees unselected.
3. Log 3–1. Select a normal scorer twice and an opposing player once with the own-goal checkbox. The credited team should have 3 goals; that normal scorer should have only 2 Golden Boot goals.
4. Log 0–0 on another date with both lineups. Draws increase; players' game counts increase without wins.
5. Verify no win-rate entries appear before 5 appearances, and that the fifth appearance makes a player eligible. Use a mix of wins, losses and draws.
6. Try selecting the same date twice: the second save must fail without duplicating any records.
7. Change a goal's own-goal flag or remove its scorer from the lineup: the selection clears and saving stays disabled until corrected.
8. Deactivate a player: historical goals, appearances and win rates should not change.
9. Select a different season and verify isolation; sign out and verify protected routes return to sign-in.

`npm test` covers the dashboard summary, 5v5 validation, dropdown filtering, own-goal scorer-side selection and score validation. Live Supabase credentials are required for full authentication and end-to-end verification.

## Match details, copying and profiles

Click a recent match's date on the dashboard to see its full details. **Edit match** reuses the match-entry form. The save includes the match ID and version; the database checks that version before applying changes. Editing a date also moves that match's stats to the appropriate season.

On a new match, **Copy previous lineups** finds the latest game with a recorded lineup strictly before the chosen date, across seasons. It asks before replacing selections, copies only active players, and leaves empty slots when someone is inactive. Always review the ten names. Scores and goals are not copied.

Player names on Players, Player stats and match lineups link to a profile. Its season selector shows appearances, goals, wins/draws/losses, goals per game and win percentage. Fewer than five games does not hide a profile's rate; it only prevents qualification for the ranked win-rate leaderboard. Total goals include legacy games; goals/game uses only goals from games with that player's recorded appearance, to avoid dividing legacy goals by incomplete attendance.

The match detail page offers **Copy text** and **Open WhatsApp**. The text includes date, score, both lineups and scorers, with repeated goals grouped and own goals labelled. The app never sends a message automatically. If clipboard access is unavailable, select/copy the displayed text manually. The WhatsApp action requires internet access and the user's own WhatsApp account.

Additional checks: edit a result and confirm standings and profiles update; edit an already-open match from a second tab and check the first tab cannot overwrite it; copy a lineup containing an inactive player; preview the share text for an own goal and a hat-trick.
