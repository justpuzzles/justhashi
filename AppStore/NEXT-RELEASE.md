# Next release: move the web addresses

On 2026-11-10 the code moved to **github.com/justpuzzles/justhashi**. The old
repo **kkai/justhashi** stays, only to serve the pages the live app and its App
Store listing point at. Don't delete it: that would take
kaikunze.de/justhashi/ offline.

In the next release, once the app's page exists at justpuzzles.app/hashi/
(see "Websites" in the workspace README):

- [ ] ASC version: Support URL and Marketing URL
      kaikunze.de/justhashi/ → https://justpuzzles.app/hashi/
- [ ] ASC App Information: Privacy Policy URL
      kaikunze.de/justhashi/justhashi-privacy.html → https://justpuzzles.app/hashi/privacy/
- [ ] In-app links (Settings / About) that still say kaikunze.de/justhashi/
- [ ] After that release is live: turn kkai/justhashi's gh-pages into
      redirects to the new pages (old binaries keep their links), then
      archive kkai/justhashi.

Local clones have two remotes: `origin` (justpuzzles, code) and `kaikunze`
(kkai, the old pages). Push code to `origin` only.
