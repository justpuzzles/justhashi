# Just Hashi 1.1: submission runbook

State on 2026-11-06: **SUBMITTED 06:28 UTC, WAITING_FOR_REVIEW, release AFTER_APPROVAL.** Before that: 1.1 (5) built from `fix/1.1-polish`
(31fba20, not merged to `main`), 169 unit tests + 8 UI audits green; build 5
(`4c7ba370-cfe3-4ee1-88af-60b968c405a4`, VALID) attached; description, What's
New and review notes pushed and read back; review submission
`587c55e8-bd61-429b-a5ce-70d585cf6453` created with the version as its item
(Apple's readiness gate passed), then submitted.** It was:
`PATCH reviewSubmissions/587c55e8-bd61-429b-a5ce-70d585cf6453`
`{"data":{"type":"reviewSubmissions","id":"…","attributes":{"submitted":true}}}`,
or press Submit for Review in the web UI. Release type is AFTER_APPROVAL.
Gate trap met: the age rating declaration gained a required `socialMedia`
attribute (set to false on the pending appInfo `da7290d9-…`, which is also the
declaration id). Version id
`b3c34cb4-7d78-4836-ada2-d1702c3413dd`, en-US localization
`0ac3c407-e9e3-4b9f-8f00-b1004dbd0180` (copyright 2026 Kai Kunze,
`AFTER_APPROVAL`). `AppStore/SUBMISSION.md` still holds the record facts and the
traps; read it first.

Build 5 adds, on top of build 4 (the Gregorian day key):

- The save slot is written only once a board has a move, or when the board is
  the saved game itself. Play, look, back out used to replace Continue.
- Home keeps `today` in state and refreshes it at midnight
  (`NSCalendarDayChanged`) and on return to the foreground.
- A hint is dropped when the board changes under it; its Apply described a
  position that no longer existed.
- Replaying a Daily from the archive keeps its first time and is not counted
  as another solve or a best time.
- The win card scrolls and its sheet can grow to large (accessibility sizes).
- Paywall buy button text uses `Theme.onBridge` (2.0:1 in dark before).
- Settings' Unlock everything opens the paywall without a feature, so the
  headline is "The full game" rather than "The rest of the curriculum".
- Not changed: the IAP record (APPROVED) still lists five things in its
  55-character description; editing an approved IAP would send it back through
  review, so past dailies are named in the app description and review notes
  instead.

## What 1.1 is

- **Accessibility pass** (the `a11y-audit` branch, 2026-10-03, now included):
  VoiceOver island and bridge actions, spoken moves, hints and win, contrast
  tokens, 44pt targets, Dynamic Type, Reduce Motion. `docs/ACCESSIBILITY.md`
  has the findings and the Nutrition Label claims.
- **Streak fix.** Finishing an older saved Daily after a newer one used to
  reset the streak to 1. Ported from Kakuro 1.1; the test now checks the streak,
  not only `lastCompleted`.
- **Share card.** The win card of a Daily has a Share button: an image of the
  island silhouette (no clues, no bridges), date, time and streak, plus a text
  line. `Hashi/Game/DailyShare.swift`.
- **Past dailies.** A Home row lists every Daily since 2026-08-08 (capped at a
  year) with your times. Opening one is a new `PaidFeature.dailyArchive`;
  locked rows present the paywall. Today's Daily stays free. The paywall's
  feature list grows by one row automatically (`PaidFeature.allCases`).
- **More Just Puzzles.** A Settings section with plain App Store links to
  Kakuro, Shikaku, Nurikabe and Numeriqo.
- Test fix: `requestAfterWarmAwaitsTheSameGeneration` and `dailyKeyIsCacheable`
  (`PuzzleCacheTests`) raced the re-warm that `settle` starts; they now count
  generations started before the first one finished. The cache suite then
  passed 50 iterations in a row.

The daily schedule and seed are untouched (shipped API).

## Left for Kai

- [ ] Look at the share card and the Past dailies screen on a device.
- [x] Merge `release-1.1` into `main`, push to kkai/justhashi (2026-10-21).
- [x] Create the iOS 1.1 version in ASC; What's New from
      `metadata/whatsnew-1.1.txt` (set and read back 2026-10-21).
- [ ] The IAP display description and `metadata/description.txt` list what the
      unlock buys; add past dailies (the IAP description caps at 55 characters).
- [ ] Review notes: past dailies are paid, today's Daily free; the share image
      is generated on device, nothing is uploaded.
- [ ] New screenshots only if wanted: Home gained one row.
- [ ] Build 1.1 (3), upload and attach, following `SUBMISSION.md` §5.

## Not in 1.1, on purpose

- **macOS, tvOS, visionOS.** The ASC record carries prepared 1.0 versions, but
  the Hashi target builds for iOS only (`SUPPORTED_PLATFORMS = iphoneos
  iphonesimulator`). Shipping them is a port like Kakuro's, not a submission.
- **Widget** (today's Daily + streak). Needs a widget extension target and an
  App Group so the extension can read `ProgressStore`; the App Group has to be
  registered on the developer account first.
- **Harder weekend dailies.** The schedule is shipped API (`docs/ENGINEERING.md`
  § Daily & streaks); changing it changes every player's daily.

Screenshots: the 1.0 set stays. `capture_screenshots.py` was run on 2026-11-06
and produced four "Home" frames that were Gait Pro's History tab (the shared
iPhone 11 Pro Max simulator still had Gait Pro in front, and the harness does
not check what it photographs), and no game or lesson frames at all (its
coordinate taps no longer hit with the Past dailies row on Home). Before the
next capture: shut the simulator down first, and re-aim the taps.
