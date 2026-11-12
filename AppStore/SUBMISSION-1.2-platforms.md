# Just Hashi 1.2 (6): Mac, Apple TV, Vision Pro — first release

Branch `multiplatform` (not merged, not pushed when this was written). Staged
2026-11-12. iOS is unaffected: iOS 1.1 (5) is live, and iOS 1.2 is a separate
step.

| Platform | Version id | Build (delivery id) | Draft review submission | Gate |
|---|---|---|---|---|
| MAC_OS | 5a32af11-ecd9-4fcf-90b0-a1fe51c64807 | 1.2 (6) 9e65b70d-33d5-4e3b-bfa6-5129f4b6ea12 | dbc749c4-61c0-4f40-815f-ac10d4f60f14 | passed |
| TV_OS | 2e7d43a7-4a55-4dc8-aa3d-3f2cc4269ead | 1.2 (6) 900d31c6-3d91-41c9-8014-bac734ff8214 | 50c6ce71-825e-4ed2-b063-61dd339660f0 | passed |
| VISION_OS | 6967d93e-8cf4-4891-be6e-2bb15286ead1 | 1.2 (6) 0699d9de-b6eb-4881-bebc-2ed2f78dccdd | 3347c724-4a00-4b32-8bb0-1874dc17876c (empty) | **blocked**: `hasHighMotionLabel` |

## Done

- The 1.0 placeholders (created with the record, 2026-08-07) renamed to 1.2,
  copyright, release after approval.
- en-US listing copied from iOS: description, keywords, promotional text,
  marketing and support URL (`AppStore/metadata/`). No What's New on a first
  version.
- Review notes per platform: the iOS notes without the 1.1 section, plus the
  shared purchase (one bundle id) and that platform's controls.
- Screenshots, four per platform, all `COMPLETE`:
  `AppStore/screenshots/{mac,tv,vision}/` (Mac 2880×1800 window on the sea,
  Apple TV 1920×1080, Vision Pro 3840×2160 cropped from the 2732×2048 sim).
  Taken with the DEBUG flags `-HashiOpen medium|lesson|drill` and
  `-HashiHalfSolved`.
- Builds archived with cloud signing (`build/archive-1.2-6.sh`, ignored),
  inspected (1.2 (6), privacy manifest, no `.storekit`, no debug flags),
  `--validate-app` clean, uploaded, `VALID`, attached.
- The IAP `de.kaikunze.hashi.full` is already APPROVED from iOS; an IAP is
  approved once per app, so it does not need to ride along (Kakuro's 2.1(b)
  was a never-submitted IAP).

## Left for Kai

1. **Vision Pro: answer the high-motion question.** The readiness gate asks for
   `hasHighMotionLabel`, which the API does not accept on the version, the app,
   the app info or the age rating. Set it on the web (Hashi has no fast
   motion: No), then add the version to submission 3347c724 (or submit from
   the version page).
2. Submit each platform (web, or `PATCH reviewSubmissions/<id>`
   `{"attributes":{"submitted":true}}`).
3. Merge `multiplatform` and push before or after review, your call.

## Not tested by hand

Mac keyboard play and Vision Pro gaze/pinch were only viewed (no input
permission from the harness). Apple TV: game, rules lesson, Full Islands
lesson, a drill and hints played by remote in the simulator.
