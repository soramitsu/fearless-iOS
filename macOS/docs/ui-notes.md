# Fearless Wallet for macOS: interface notes

The interface lives in `macOS/Packages/FearlessMacUI`. It talks to the wallet
only through `WalletCore.WalletServices` and never imports the engine.

## Package

| Target | What it is |
| --- | --- |
| `DesignSystem` | Brand colours, Figtree, brand marks, chain and token icons, reusable components, the Shikiban figures (seal, sync dial, loader) |
| `WalletUI` | Screens, view models, navigation, commands and scenes. Entry point: `FearlessScenes(services:)` |
| `WalletPreviewSupport` | In-memory implementation of every WalletCore protocol with sample data. Not linked into the app |
| `WalletUIPreviews` | Xcode canvas previews of the main screens |
| `FearlessMacDemo` | Runs the interface over the preview services, without the engine |
| `FearlessMacSnapshots` | Renders every screen to PNG in light and dark |
| `WalletUITests` | Swift Testing tests of the view models over the preview services |

```bash
cd macOS/Packages/FearlessMacUI
swift build --scratch-path .build-fable
swift test --scratch-path .build-fable
swift run --scratch-path .build-fable FearlessMacDemo [--scenario first-run|locked|empty|balance-failure|transfer-fails] [--slow] [--touch-id]
swift run --scratch-path .build-fable FearlessMacSnapshots <folder> [--only portfolio,send-review] [--sizes 1280x820] [--appearance dark] -AppleLanguages "(en)" -AppleLocale en_US
```

The demo has flags for unattended checks: `--no-activate` (do not take
focus), `--dump-menus` (build every menu and print its items and
shortcuts), `--exercise-settings` (choose View-menu items that change
preferences, then print a heartbeat), `--menu-bar-test` (turn the menu bar
extra on and off), `--main-thread-stacks` (print the main thread's stack a
few times).

The demo prints its sample app password at launch. Everything in the preview
package is public test material: Substrate's development accounts (Alice, Bob,
Charlie), the first accounts of the Hardhat test mnemonic, and BIP-39 test
vectors as "generated" phrases. None of it may hold funds.

## Screen map

```
Window "Fearless Wallet" (one window, min 900 × 600, default 1180 × 760)
├─ Launching            crest on the brand surface until the vault reports its state
├─ Onboarding           vault uninitialized, or unlocked with no wallet
│  ├─ Welcome           crest, wordmark, Create / I already have a wallet (phrase, seed, JSON, watch-only)
│  ├─ App password      strength meter, confirmation, guidance
│  ├─ Touch ID          offered only when the engine reports it available
│  ├─ New phrase        12 or 24 words, hidden until Reveal, Copy (concealed, 60 s), no save to file
│  ├─ Check backup      3 positions for 12 words, 4 for longer phrases; or Back Up Later
│  ├─ Import phrase     12–24 fields, autocomplete, paste of a whole phrase, Advanced, address preview
│  ├─ Import seed / JSON (file importer and drag and drop) / Watch-only
│  └─ Name and confirm  addresses the wallet will have, then it is stored
├─ Lock                 password, Touch ID when enabled, Forgot password → typed ERASE
└─ Main                 NavigationSplitView
   ├─ Sidebar           wallet switcher (menu), Portfolio, Assets, Activity, Networks, sync dial, Lock
   ├─ Portfolio         backup banner, total with 24 h change, allocation, top holdings, networks, recent activity
   ├─ Assets            sortable table (Asset, Network, Price, 24h, Balance, Value) + inspector
   ├─ Activity          sortable table (Date, Type, Asset, Amount, From / To, Status) + inspector
   ├─ Networks          table of networks with sync state + inspector with the node editor
   └─ Sheets            Send (form → review → progress: final, failed or "sent, confirmation pending"),
                        Receive, Add Wallet, Back Up (words, plus key type and paths when the wallet needs them)
Settings (⌘,)           General · Security · Wallets · Networks
Menu bar extra          total, copy address, Receive, Open, Lock (off by default)
Acknowledgements        Help ▸ Acknowledgements: font licence, icon credits
About                   standard About panel
```

## Keyboard shortcuts

| Shortcut | Action | Menu |
| --- | --- | --- |
| ⌘N | New Wallet | File |
| ⇧⌘N | Import Wallet | File |
| ⇧⌘S | Send | Wallet |
| ⇧⌘R | Receive | Wallet |
| ⌘R | Refresh balances and activity | Wallet |
| ⇧⌘C | Copy Address (the selected asset's network in Assets, otherwise the wallet's first network) | Wallet |
| ⌘1 … ⌘9 | Switch to wallet 1 … 9 | Wallet |
| ⌃⌘L | Lock Fearless | Wallet |
| ⇧⌘H | Hide Balances | View |
| ⌃⌘S | Show or hide the sidebar | View |
| ⌃⌘I | Show or hide the inspector | View |
| ⌥⌘1 … ⌥⌘4 | Portfolio, Assets, Activity, Networks | View |
| ⌘F | Search | Edit |
| ⌘, | Settings | App |
| ⏎ / ⎋ | Default / cancel button of a step or sheet | |
| Tab, Space, ⏎ in the phrase grid | Accept the first suggestion or move to the next word | |

View also has Show Testnets and Hide Zero Balances as checkable items.
Context menus on asset and activity rows: Copy Address, Copy Transaction Hash,
Send, Receive, Show in Explorer, Hide Asset. Double-click opens the inspector.

## Design decisions

**Native first, brand as accent.** Sidebar, toolbar, tables, inspector,
Settings, sheets, menus and focus rings are the system's. The brand shows in
four places: the accent colour, the crest, the full-window brand surfaces
(welcome, lock, launch) and the Shikiban figures.

**Colour.** `BrandPalette` holds the kit's fixed colours for brand surfaces.
`BrandColor` holds the colours of ordinary content; each follows light, dark
and Increase Contrast. The kit's bright accents (cyan for gains, gold for
final) fail contrast on a white window, so light appearance uses darker
steps of the same hues. Pink is used for primary actions and active
navigation only. The primary button is the system's prominent button tinted
`#D6006A` (white label 5.2:1).

**Type.** Headings and brand moments use Figtree (bundled, OFL 1.1, licence
shown in Help ▸ Acknowledgements). Body text, controls and every number use
the system font, so tables align and the app reads as a Mac app. The kit's
display face Sora ships only as WOFF2 and is not bundled.

**Brand surfaces are always dark.** Welcome, lock and launch use ink with the
icon's sunrise glow and the asanoha lattice, in light appearance too; the
window's appearance is switched to dark for them so the title bar matches.
The setup steps after the welcome sit beside a dark brand panel and use the
system appearance, like a Mac setup assistant.

**Portfolio.** The total sits on a brand card (lit rim, registration marks,
lattice, gold crest). Allocation is a thin segmented bar above a list that
gives each part's share and value, not a donut: parts are compared on one
line and read as text. Colours are a fixed categorical palette checked with
a palette validator in both appearances; a colour belongs to an asset or
network (catalog order), not to its rank, and anything past the seventh slot
is drawn as "Other". Top holdings are ranked bars on one baseline in one hue.

**Send is a sheet, not a window.** A transfer belongs to one wallet. A sheet
ties it to that wallet's window, keeps the wallet from being switched or
locked-and-swapped underneath it, allows exactly one transfer in flight per
window, and is where Mac users expect a short modal task. The sheet keeps
one size through form, review and progress so nothing jumps. Receive is a
sheet for the same reason; the address is also in the asset inspector.

**The seal.** After approval the sheet shows the kit's seal on an ink plate:
rings on approval, one side of the upward triangle for each of signed, sent
and included, the full figure in gold when final, a cyan comet on the stroke
it is waiting for, ember and a fall when it fails. A stage is lit only when
`TransferProgress` reports it. The Mac has one stage more than the kit's
table (final), which draws the kit's ignite.

**Three endings, three looks.** `finalized` is the gold figure. `failed`
(the network's definite verdict) turns the figure ember and breaks it.
`outcomeUnknown` (sent, but the confirmation never came) keeps the strokes
that happened in a neutral lilac with the missing stroke as a dashed trace,
says "Sent. Confirmation pending", marks the unconfirmed stages with a
question mark, and offers Copy Hash and Open Explorer with the advice to
check before sending again. A stream that ends without any verdict is shown
the same way. The seal is never gold or ember for something the app does
not know.

**Sync dial.** Balances are fetched per network (one `balances` call per
chain, in parallel), so the dial can show real answers out of real totals
and a failing network is reported inline without delaying the others.

**Scenes are created without side effects.** SwiftUI calls
`FearlessScenes.init` every time the app's body is re-evaluated. The app
model (which reads UserDefaults) is therefore built once, lazily, by a
`SceneModelStore` kept in `@State`; settings setters do nothing when the
value is unchanged; and the one preference the scene list reads (the menu
bar extra) is observed apart from the others. Building the model in `init`
caused an endless scene-update cycle on the first settings write: the app
died seconds after a first launch. `WindowChrome` only adjusts the title
bar; light and dark are left to `preferredColorScheme`.

**Accent colour.** Sidebar selection, default buttons and focus rings use
the system accent. The app target should define `AccentColor` in its asset
catalog (light `#D6006A`, dark `#FF4FA3`); a user who picked their own
accent in System Settings keeps it. The demo and the snapshot tool have no
bundle, so they ask for the system's pink accent for their own process.

**Icons stay visible.** A chain's glyph is white on the catalog's colour;
when that colour is pale (relative luminance above 0.6) the glyph is drawn
in ink instead, and every disc keeps a hairline edge, so no catalog colour
can make an icon disappear in either appearance.

**Menu bar extra is off by default.** Menu bar space is the user's, and a
visible wallet icon tells onlookers something. Settings ▸ General turns it
on. It never shows amounts while locked and follows privacy mode.

**Secrets.** The interface never writes a secret to UserDefaults (a test
checks the stored keys). Phrases are hidden until Reveal, hide again when
the window is not key, are kept out of screenshots and screen sharing while
visible (`NSWindow.sharingType = .none`), and are copied as concealed
pasteboard items that are cleared after 60 seconds if unchanged. Recovery
words and derivation paths are typed into `SecretTextField`, an AppKit field
with a field editor of its own and AppKit's text services off (the shared
field editor of other fields is untouched): words take Roman-script input
sources only, paths take any input source and reach derivation byte for
byte. A shown raw seed is plain text beside its `SecureField`, a shown path
with a `///password` is copied only with its concealed copy button, and the
import steps ask macOS to keep their window out of screen capture (best
effort; not every recorder honours it) and tell the user to stop sharing. Locking
drops wallets, balances, history, open sheets and typed passwords at once,
before the vault confirms.

**Snapshots use the window server's picture.** The brief asked for
`bitmapImageRepForCachingDisplay` / `cacheDisplay`. On this macOS the
sidebar, inspector and toolbar live in system material layers that
`cacheDisplay` does not draw (they come out blank), so the tool captures its
own off-screen window with `CGWindowListCreateImage` (no permission needed
for the process's own windows) and keeps `cacheDisplay` as the fallback.
Sheets are captured as panels and composited over the dimmed main window.
Windows are placed far outside every display; nothing appears on screen.

## Accessibility

- Amounts: `AmountText` and `FiatText` read the full value with its symbol,
  or "hidden" in privacy mode. Gains and losses carry an arrow and a sign,
  never colour alone. Status pills carry an icon and a word.
- Addresses are read in groups of four characters, spelled out; the tooltip
  holds the whole address. The review step shows the whole recipient address.
- Every control has a label and, where it helps, a `.help` tooltip with its
  shortcut. Decorative marks are hidden from VoiceOver; the crest is labelled
  "Fearless".
- Keyboard: every step has a default and a cancel button; the phrase grid
  moves with Tab, Space and Return; tables, sidebar and menus are the
  system's and keep their keyboard behaviour.
- Reduce Motion: the seal, the dial and the loader show their state without
  moving; the backdrop glows stand still; presses do not scale; the
  wrong-password shake is replaced by the message.
- Increase Contrast: `BrandColor` has dedicated steps; cards and pills gain
  solid borders.
- Reduce Transparency: the toast and choice cards become opaque.
- Hidden phrase words are withheld from VoiceOver until revealed.

## Known gaps

- English only. No string catalog yet.
- Sidebar selection is the system accent (blue by default) until the app
  target ships an `AccentColor`.
- The welcome and launch use the crest and the solar figure. The kit's
  video hero, launch flight and sounds are not ported.
- Touch ID is not requested automatically when the lock screen appears; the
  user presses its button.
- The About panel shows the version of the bundle that hosts it, so the
  demo (no bundle) shows none.
- Numeric table columns are right-aligned but their headers are not:
  `TableColumn.alignment` needs macOS 15.
- Passwords and phrases are Swift strings while they are on screen; they are
  cleared from the models as soon as they are used but cannot be zeroed.
- The history is loaded in one call and filtered in memory (see the
  contract request for paging).
- No hardware wallet, staking, swap, NFT or WalletConnect screens.
- VoiceOver was reviewed in code, not in a full audit with the screen
  reader running.

## Contract requests and updates

Filed in `contract-requests.md` on 2026-11-22 (lane `ui`) and answered by
the coordinator the same day:

1. **Backup state of a new wallet.** Applied as
   `WalletImportSource.created(words:options:)`: a phrase made on this Mac is
   stored with origin `.created` and `isBackedUp == false`, every other
   source as backed up. The create flow uses `.created` for the address
   preview and for `addWallet`, calls `markBackedUp` only after the backup
   check passes, and the reminder reads `wallet.isBackedUp` alone.
2. **Fee and maximum for an incomplete draft.** Guaranteed by the doc
   comment of `prepare`; "Max" calls it with the draft as it stands.
3. **History in pages.** Deferred; the UI loads everything in one call.
4. **Icon name for tokens.** Applied as `Asset.tokenIconName`. The asset
   icon uses it first, then a bundled token icon matching the ticker, then
   the chain glyph, then a monogram.

Second contract update (from the engine review), adopted:

- `TransferProgress.outcomeUnknown(reason:)` has its own seal state and
  wording (see "Three endings" above), a preview scenario
  (`PreviewScenario.transferOutcomeUnknown`) and a snapshot.
- `exportMnemonic` returns `MnemonicBackup`. The backup sheet shows the
  words as before and, when `needsDerivationDetails` is true, the key type
  and both derivation paths under the same reveal rule as the words (the
  Substrate path may end in `///password`).
- Review finding fixed: options set on an import screen no longer leak. The
  derivation is reset to `.standard` whenever a flow is chosen or left, and
  a created wallet always uses `.standard` (the create flow has no Advanced
  options). Tests cover the import → back → create sequence.
