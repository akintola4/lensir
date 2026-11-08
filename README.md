# Lensir

Lensir is a QR code scanner for iPhone that works with no signal. Point it at a code and it tells you what's inside before anything opens. If the code is a link, it checks the address for the tricks scam codes use. It makes codes too: your Wi-Fi for guests, a link, your number.

It comes from the same place as [Pocket](https://github.com/akintola4/pocket) and [Tape](https://github.com/akintola4/tape): small phone tools that keep working offline. Lensir has no network code at all. The camera, the checks and your history all stay on the phone.

It isn't on the App Store. You clone it, open it in Xcode and run it on your own phone.

<p align="center"><img src="docs/screenshots/splash.gif" width="280" alt="Lensir's opening: the corner brackets breathe out, snap onto the lens dot, then grow into the scanner's viewfinder"></p>

When it opens, the four brackets from the icon hunt for focus, snap in tight onto the lens dot with a light tap, then grow out into the scanner's own viewfinder while the camera fades in behind them. It takes about three quarters of a second. The brackets you end on are the scanner's brackets, not a copy, so there's no swap at the end. It plays once per cold launch and a tap skips it. With Reduce Motion on, the mark holds for a moment and the scanner fades in over it. [Slow motion](docs/screenshots/splash-slow.gif).

## Screenshots

| Looking | Found | A safe link |
|---|---|---|
| ![Four white corner brackets over the camera, waiting for a code](docs/screenshots/looking.png) | ![The brackets snapped onto a QR code, with a white pill reading paystack.com under it](docs/screenshots/found.png) | ![The drawer for paystack.com: the full address, "Secure · the real paystack.com" and an Open link button](docs/screenshots/safe-link.png) |

| A safe link, expanded | A lookalike | A lookalike, expanded |
|---|---|---|
| ![The drawer pulled up: Details with every check passed and the scanned text](docs/screenshots/safe-expanded.png) | ![Red brackets and a drawer saying the underlined "а" is a Cyrillic letter, so this is not paystack.com](docs/screenshots/lookalike.png) | ![Details for the lookalike: "The real site" and "Plain letters" crossed out in red](docs/screenshots/lookalike-expanded.png) |

| A short link over http | Wi-Fi | Wi-Fi, expanded |
|---|---|---|
| ![A bit.ly link: not secure, and a link shortener that hides where it goes](docs/screenshots/short-link.png) | ![A Wi-Fi code: network name, password, security and a Copy password button](docs/screenshots/wifi.png) | ![Details for the Wi-Fi code: the raw text and a Scan again button](docs/screenshots/wifi-expanded.png) |

| Contact | Several codes in one photo | History |
|---|---|---|
| ![A contact card code with a Save contact button](docs/screenshots/contact.png) | ![A list of three codes found in one photo](docs/screenshots/photo-codes.png) | ![History grouped by day, with the swapped letter underlined in red on the risky link](docs/screenshots/history.png) |

| Camera turned off | No camera |
|---|---|
| ![Lensir needs the camera, with an Open Settings button](docs/screenshots/camera-denied.png) | ![No camera here, with a Choose a photo button](docs/screenshots/no-camera.png) |

### Making a code

| A Wi-Fi code | A link | A lookalike link |
|---|---|---|
| ![The Make drawer over the scanner: Kola Logistics and Wi-Fi on the left with the code beside them, chips for Wi-Fi, Link, Phone, Contact and Text, then Network, Password and Security, Show code and Keep in My codes](docs/screenshots/make-wifi.png) | ![The Make drawer on Link: kolalogistics.test/track typed in, the code beside the site's name, and "Secure · nothing odd in the address"](docs/screenshots/make-link.png) | ![A link with a Cyrillic "а" typed in: paystаck.com at the top with the letter underlined in red, and two warnings under the field](docs/screenshots/make-risky.png) |

| Show code | My codes | My codes, empty |
|---|---|---|
| ![The Wi-Fi code full screen on white: "Point your camera here to join", Kola Logistics, Wi-Fi · WPA/WPA2, Share and Save to Photos](docs/screenshots/make-show.png) | ![History with My codes at the top: the Kola Logistics Wi-Fi, kolalogistics.test and a phone number, each with a small code, then today's scans](docs/screenshots/history.png) | ![My codes with nothing kept yet: "Keep the codes you show often", what it's for, and a Make a code button, above the scans](docs/screenshots/my-codes-empty.png) |

In Light:

| Scanner | A scan | Make | History |
|---|---|---|---|
| ![The scanner in Light: black brackets and a white veil over the camera, black Make button](docs/screenshots/looking-light.png) | ![The drawer for paystack.com in Light: a white sheet with a black Open link button](docs/screenshots/safe-link-light.png) | ![The Make drawer in Light: light grey fields, a black chip for Wi-Fi and a black Show code button](docs/screenshots/make-wifi-light.png) | ![History in Light: white cards on grey, with My codes at the top](docs/screenshots/history-light.png) |

Every screen above has a `-light.png` twin in `docs/screenshots/`, and there are Light versions at AX5 and with Increase Contrast for the result drawer and History.

At the largest text size (AX5):

| Make, Wi-Fi | Make, a lookalike | Show code | My codes | Nothing yet | A scanned lookalike |
|---|---|---|---|---|---|
| ![The Make drawer at AX5, scrolled to the top](docs/screenshots/ax5/make-wifi.png) | ![The lookalike warning at AX5, the code above the site name, which wraps at the dot](docs/screenshots/ax5/make-risky.png) | ![The full-screen code at AX5](docs/screenshots/ax5/make-show.png) | ![My codes at AX5, each code above its name](docs/screenshots/ax5/history.png) | ![My codes and History both empty at AX5](docs/screenshots/ax5/my-codes-empty.png) | ![A scanned lookalike at AX5: paystаck.com with the red underline, then the full address and the warnings](docs/screenshots/ax5/lookalike.png) |

The Simulator has no camera, so these use the launch arguments below. They draw a stand-in camera with a real QR code on a printed card. `scripts/screenshots.sh` takes all of them.

## What it does

- The camera fills the screen. Four white corner brackets wait in the middle with the rest dimmed. When a code turns up they snap onto it in about 200 ms with a light tap, and a white pill under the code names what it is: the site for a link, the network for Wi-Fi, the person for a contact card.
- Tap the pill and a drawer slides up from the bottom edge with the whole thing: the full address, the Wi-Fi password, the phone number. It works like the [shadcn/ui Drawer](https://ui.shadcn.com/docs/components/drawer). You can drag it from anywhere, not only the grabber. It follows your finger exactly, gives a little past the top, and when you let go a spring carries on at the speed you threw it, with a small bounce. Let go 40% of the way down, or flick it, and it closes. Catch it while it's closing and it stops under your finger. The detent tick plays the moment it lands. If Details are scrolled down, dragging down scrolls them back to the top first, then pulls the drawer down in the same movement. A quick flick down puts it away and the camera starts again. Pull it up, or tap the grabber, and a Details section shows every check as a pass or fail row, any field the compact drawer left out, the raw text with a copy button, when you scanned it, and Scan again. While it's up, the camera behind it dims and sinks back a little. Each kind of code has its own main button:

  | Code | Main button | Second button |
  |---|---|---|
  | Link | Open link | Copy link |
  | Risky link | Copy link | Open anyway (red) |
  | Wi-Fi | Copy password (Join Wi-Fi with a paid account, see below) | Copy network name |
  | Contact (MECARD or vCard) | Save contact | Copy details |
  | Phone number | Call | Copy number |
  | Text message (`sms:`, `SMSTO:`) | Send message | Copy message |
  | Email (`mailto:`, `MATMSG:`) | Write email | Copy address |
  | Place (`geo:`) | Open in Maps | Copy coordinates |
  | Text or a product barcode | Copy text | |

- Every code you open goes into History, newest first and grouped by day. Swipe a row to delete it, or clear the lot. Tapping a row opens it again.
- Make, the white button between the photo and History buttons, raises the same drawer to make a code. Pick Wi-Fi, Link, Phone, Contact or Text and fill it in. The drawer's header reads like a scan's: what you're making on the left and its code on the right, redrawing as you type. A link you make gets the same checks as one you scan, and if it looks risky, Show code and Keep both ask before going ahead. Typing `kolalogistics.test` is enough; Lensir adds `https://`.
- Show code puts the code full screen on white and turns the brightness all the way up until you close it. The phone won't lock while it's showing. Share sends the picture. Save to Photos asks only to add to your library, never to read it.
- Keep puts the code in My codes, at the top of History. Tap one to show it again, swipe it to delete or rename it. Clearing History leaves My codes alone. With none kept yet, My codes has a Make a code button; otherwise Make on the scanner is the way in.
- The photo button reads codes from a picture in your library. If there are several, you pick one from a list.
- A torch button for dark rooms, and a Haptics switch in Settings (behind History).
- Lensir follows the phone's Light or Dark setting everywhere, from the opening animation to History. In Dark it's white on black, as it always was. In Light it flips to black on white: the veil around the brackets turns white, and a thin line marks where the drawer meets the camera. A code shown full screen is black on white in both, because that's what other phones scan most reliably.
- Addresses, network names and numbers are set in SF Mono. In a monospaced face a swapped letter can't hide: l, 1 and I look different, and so do O and 0.

## Straight to the scanner

Each of these opens Lensir on the camera. If you left a result, History or the photo list open last time, it closes.

- Control Center: swipe down from the top-right corner, tap +, then Add a Control, and search for Lensir. The control is Scan with Lensir, drawn with Lensir's brackets and dot.
- The Lock Screen's two bottom buttons: the same control can take the place of the torch or the camera. Touch and hold the Lock Screen, tap Customize, then Lock Screen, remove one of the two buttons with −, tap + and pick Scan with Lensir.
- The Action Button (iPhone 15 Pro and later): in Settings › Action Button, swipe to Controls, tap Choose a Control and pick Scan with Lensir. The Shortcut option works as well; choose Lensir, then Scan a Code.
- A Lock Screen widget: while customizing the Lock Screen, tap the row under the clock and add Lensir's Scan widget. The round one is just the mark; the wide one says "Scan a code". Tap it to open the scanner.
- Siri and Spotlight: say "Scan with Lensir" or "Check a QR code with Lensir", or type "scan" in Spotlight. It's in the Shortcuts app too, already set up.

<img src="docs/screenshots/widgets/lock.png" width="300" alt="The Lock Screen with Lensir's round widget, the brackets and dot, and the wide one that says Scan a code">

If one of these starts Lensir from cold, you only see the end of the opening animation. The brackets grow from the launch mark into the viewfinder in 0.5 s and the camera fades in behind them. The hunt, the lock and its tap, and the credit are skipped. The camera starts up behind it, so it barely holds you up. If Lensir was already open, it goes straight to the camera.

The widget opens `lensir://scan`. The control, the Action Button and Siri run `OpenScannerIntent`. Both go through the same code in the app.

## Why it doesn't open links by itself

Apple's Camera app opens a link the moment you tap its banner, and plenty of scanner apps open it as soon as they read it. That's exactly what a scam code is counting on. A sticker over the real code on a parking meter or a market stall can send you to a page that looks like your bank.

Lensir stops before that. The brackets find the code and the pill tells you the site's name. Nothing opens until you've seen the whole address in the drawer and pressed Open yourself. When something about a link looks wrong, the brackets turn red, Copy link becomes the main button, and opening it is a red "Open anyway" underneath.

## The checks

All of this runs on the phone, in `Lensir/Logic/LinkSafety.swift`, without looking anything up. Each problem shows as one plain sentence in the drawer, and lookalike letters are underlined in red.

- Plain http. The drawer says anyone on the same Wi‑Fi can see what you send.
- Link shorteners: bit.ly, tinyurl.com, t.co, goo.gl, ow.ly, is.gd, buff.ly, cutt.ly, rebrand.ly, shorturl.at, rb.gy, qrco.de and about 25 more. A short link hides where it goes, and finding out would mean going online.
- A bare IP address instead of a site name, including sneaky spellings like 3232235521 and 0xC0A80001.
- `javascript:` and `data:` links, which aren't web addresses at all. Lensir won't open these.
- An `@` in the address. In `https://paystack.com@pay-now.xyz` everything before the @ is decoration, and the site is pay-now.xyz.
- Four or more subdomains in front of the real site.
- A name that looks randomly generated, like `x7k2p9q4m1z8w3.top`: digits scattered through letters, hardly any vowels, or six consonants in a row.
- Letters from another alphabet. Lensir decodes `xn--` addresses first, then underlines any Cyrillic or Greek letter mixed into a Latin name: "The underlined “а” is a Cyrillic letter, so this is not paystack.com."
- Lookalikes of sites people trust. Each name is folded to a skeleton (Cyrillic а becomes a, 0 becomes o, 1 becomes l, rn becomes m) and compared with a bundled list: Paystack, Flutterwave, OPay, PalmPay, Moniepoint, Kuda, GTBank, Access Bank, Zenith Bank, First Bank, UBA, Stanbic IBTC, Fidelity Bank, Sterling, Wema Bank and ALAT, Jumia, Konga, MTN, Airtel, Glo, DStv, GOtv, Ikeja Electric, EKEDP, JAMB, FIRS and NIMC, then PayPal, Apple, iCloud, Google, Gmail, WhatsApp, Instagram, Facebook, Microsoft, Netflix, Amazon and Binance. That catches swapped letters (paypa1.com), typos (paystak.com; long names like flutterwave get two letters of slack), a brand's name borrowed for another site (paystack-login.com), a brand tucked into a subdomain (paystack.com.pay-now.xyz), and a brand's exact name on a domain it doesn't own (paystack.vercel.app).

The real sites pass with nothing flagged, and the tests check that for every brand on the list plus sites like github.com, cloud.com, finance.yahoo.com and amazon.de. A clean link says "Secure · the real paystack.com" when it belongs to a brand on the list, or "Secure · nothing odd in the address" otherwise.

The checks only read the address. They can't tell whether a site you've never heard of is honest, and a scam on a plain new domain will get through. What they catch is an address pretending to be somewhere you already trust.

## Offline and private

- There's no networking code in the app. It never sends a code, a photo or your history anywhere. Links only leave the phone when you press Open and your browser takes over.
- Photos are read with Vision on the phone. Lensir only sees the photo you pick; it doesn't ask for your library.
- History and My codes are stored with SwiftData, in one store in the app's own container. Delete the app and they're gone.
- Codes are drawn on the phone with CoreImage. Saving one to Photos needs add-only access, so Lensir can put a picture in your library but can't see what's there.
- The camera permission is only used to read codes.

## Build and run

You need Xcode 27 and a phone or simulator on iOS 26.1 or later. There are no packages and no API keys.

```bash
git clone <this repo>
cd lensir
open Lensir.xcodeproj
```

Pick the Lensir scheme and a simulator (I use iPhone 17 Pro), then press Run. You don't need to set up signing for the Simulator. It has no camera, so Lensir opens on "No camera here"; use the photo button, or the launch arguments below.

### On your own iPhone

1. Create `Config/Local.xcconfig`. It's git-ignored, so your details stay out of the repo:

   ```
   LENSIR_BUNDLE_PREFIX = com.yourname
   DEVELOPMENT_TEAM = YOURTEAMID
   ```

   `Config/Lensir.xcconfig` includes it if it exists. You can also edit `Lensir.xcconfig` directly, or leave the team empty and choose it under Signing & Capabilities. The bundle IDs (`<prefix>.lensir`, and `<prefix>.lensir.widget` for the control and the widget) and the App Group (`group.<prefix>.lensir`) are all built from the prefix.
2. Plug in your phone, select it and press Run. The first time, go to Settings › General › VPN & Device Management on the phone and trust your developer certificate.

From the command line:

```bash
xcodebuild build -scheme Lensir -destination 'id=<your iPhone UDID>' -allowProvisioningUpdates
```

`-allowProvisioningUpdates` lets Xcode register the widget's bundle ID and the App Group for you. App Groups work with a free Apple ID, and the widget extension lives inside the app, so it doesn't count against the free account's limit of three apps.

With a free Apple ID, an app you install from Xcode stops opening after 7 days. Run it from Xcode again to get another 7. Your history survives the reinstall.

### Joining Wi-Fi

Joining a network straight from a code uses `NEHotspotConfiguration`, which needs the Hotspot Configuration capability. A free Apple account can't sign that one. Xcode says "Personal development teams do not support the Hotspot capability". So it's off by default, and a Wi-Fi code's main button is Copy password, with Copy network name under it. You paste the password in Settings › Wi-Fi.

With a paid developer account, add `LENSIR_WIFI_JOIN = YES` to `Config/Local.xcconfig`. That adds the entitlement and brings back a Join Wi-Fi button.

### Tests

```bash
xcodebuild test -scheme Lensir -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1'
```

There are 242 tests in `LensirTests` (two of them only draw the widget screenshots, and are skipped unless `scripts/widget-screenshots.sh` asks for them) and 17 in `LensirUITests`. The Swift Testing ones cover:

- every kind of code: links, Wi-Fi (escaped `;`, `:`, `\` and `"`, hidden networks, open networks, WEP, WPA3), MECARD, vCard 3 and 4 with folded lines, `tel:`, `sms:` and `SMSTO:`, `mailto:` and `MATMSG:`, `geo:`, plain text and barcodes
- every safety rule, the exact letters each lookalike underlines and the sentence it says
- real sites coming through clean, about 65 of them
- Punycode decoding, the skeleton, edit distance, and how an address is split into its parts
- which buttons each kind of code gets
- where the brackets and the pill go, including codes near the edge and near the bottom
- History grouped by day and newest first, and repeat scans merged
- the links handed to Phone, Messages, Mail and Maps
- reading three codes out of one photo with Vision, in order
- the drawer: following the finger, the rubber band above the top, which point a release snaps to (by position and by how fast it was thrown), the spring picking up the release speed, bouncing only after a drag, snapping back quickly, landing on the haptic, being caught mid-close, and the dim and background scale that follow its height frame by frame
- what the drawer lists: a pass or fail row per check, a few fields in compact, and only the rest under Details
- the opening animation: phases in order inside 0.76 s, a first frame the same size and place as the launch image, the hunt, the lock's one small overshoot, an end state exactly equal to the scanner's brackets, the credit coming and going without popping, and the Reduce Motion path
- `lensir://scan`: which links it reads and which it ignores, the URL scheme in the Info.plist, the intent and the link landing in the same inbox, what the link closes, and the 0.5 s opening it plays on a cold launch (starts on the launch mark, ends on the scanner's brackets, no credit)
- who gets a drag on the drawer: the drawer, the scroll view, or nobody for a sideways drag, including the hand-over when scrolled Details reach the top
- making codes: the text for each kind, `\ ; , : "` escaped in Wi-Fi names and passwords, links finished with `https://`, unfinished ones refused, the WPA password minimum, and the size limit
- every kind of made code parsed back by PayloadParser with the same fields, and drawn, then read off the picture by Vision
- the drawn code: a four-module quiet zone, only black and white pixels, and nearest-neighbour scaling
- a made lookalike link getting exactly the report a scanned one gets
- domains wrapping after a dot with the lookalike underline kept
- Light and Dark: every colour token's value in each, Increase Contrast's darker greys, dark mode's veil matching what it was, and the launch colour and mark having both appearances
- My codes: keeping the same code twice, renaming, the kind and date on each row, the store it shares with History, and clearing History leaving My codes alone
- the brightness going up and back once, even if you leave the app and come back
- the Make drawer's single height, VoiceOver going back to Make when it closes, and the tick on Keep

`LensirUITests` uses XCTest, because Swift Testing can't drive the screen. It drags the drawer with real touches: down from the middle of Details, down while scrolled (on a long link, so Details scroll), by the header, up from the content, a flick to close, and a drag that starts on Open link, which must move the drawer without pressing the button. Taps on buttons and the grabber still have to work. `DrawerFeelUITests` adds a fast flick, a slow drag past 40%, a short drag that snaps back, a pull past the top that rubber-bands back, and catching the drawer mid-close; `scripts/record-drawer.sh` records each of those into `~/Movies/Lensir drawer/`. Two more open `lensir://scan` while History or the result drawer is up and check that it closes. Two more make a code with the keyboard: one types a link, keeps it, finds it in My codes and opens it full screen; the other types a short link and checks that Keep asks first. Those runs take about a minute and a half. Add `-only-testing:LensirTests` to skip them.

Leave out `OS=26.1` if your iPhone 17 Pro simulator runs a newer iOS.

### Launch arguments (Debug builds)

A few are in the scheme, switched off. Turn them on under Product › Scheme › Edit Scheme › Run › Arguments, or pass them to `xcrun simctl launch`.

- `-LensirDemo found` opens on a stand-in camera with a code in view. The scenes are `looking`, `found`, `safe`, `risky`, `http`, `wifi`, `contact`, `phone`, `text` and `photos`. All of them except `looking`, `found` and `photos` open the drawer too. `safe-expanded`, `risky-expanded`, `wifi-expanded`, `contact-expanded` and `long-expanded` (a long payment link whose Details scroll) open it pulled all the way up.
- `-LensirDemo drawer-tour` plays the drawer through by itself, since you can't drag in the Simulator: the brackets snap, the drawer rises, expands, settles back and is flicked away. It's how the first recording in `~/Movies/Lensir drawer/` was made.
- `-LensirDrawerSlow` runs the drawers' springs 4× slower, so a UI test can catch one mid-flight.
- `-LensirDemo make-link` opens the Make drawer filled in. The others are `make-wifi`, `make-risky` (a lookalike link) and `make-show` (the Wi-Fi code full screen).
- `-LensirOpenHistory` opens History on launch, filled with demo scans and My codes. Add `-LensirEmptyHistory` to see it empty, or `-LensirEmptyCodes` for scans with no My codes.
- `-LensirNoSplash` skips the opening animation, for screenshots.
- `-LensirSplashSlow` plays the opening animation 4× slower, for tuning it.
- `-LensirSplashAt 0.3` holds the opening animation at that many seconds in, for stills. It never moves on to the scanner.
- `-LensirCameraDenied` acts as if camera access is turned off in Settings.
- `-LensirNoCamera` acts as if the phone has no camera.

Demo runs keep history in memory, so they never touch your real history.

### Scripts

- `scripts/screenshots.sh` builds Lensir for the Simulator and takes the screenshots in `docs/screenshots/`.
- `scripts/record-splash.sh` records the opening animation in the Simulator at normal speed and 4× slow, into `~/Movies/Lensir splash/`, and opens the normal one in QuickTime. If the Simulator keeps showing an old launch screen after the mark changes, run it on a fresh simulator with `SIM=<udid>`: iOS caches launch screens, even across reinstalls.
- `scripts/make-icon.py` draws the app icon. Run `python3 scripts/make-icon.py` to regenerate it (it needs Pillow).
- `scripts/widget-screenshots.sh` renders the Lock Screen widget's real views into `docs/screenshots/widgets/`, since the Simulator can't add a widget without tapping.
- `scripts/make-control-symbol.py` draws `lensir.viewfinder`, the custom SF Symbol on the control, in three weights.
- `scripts/make-launch-mark.py` draws the launch screen's mark from the same numbers the opening animation starts from.

## Project layout

```
Lensir/            the app
  Logic/           pure and tested: PayloadParser, LinkSafety, Confusables, Brands,
                   Punycode, LinkAddress, ResultSummary, ResultDetails, ScanGeometry,
                   DrawerLogic, HistoryLogic, ScanRouting, CodeMaker, MyCodesLogic
  Scanner/         the screen: camera (VisionKit, with an AVFoundation fallback),
                   brackets, pill, photos, demo scenes
  Result/          the drawer (DrawerSurface, shared with Make) and its state, the address
                   text, saving contacts, joining Wi-Fi
  Make/            the Make drawer, drawing codes, the full-screen code
  Splash/          the opening animation: SplashLogic (pure, tested), the dot, ring and credit
  History/         SwiftData history, My codes and Settings
  Components/      colours, type, the press style
Shared/            in the app and the widget: the brackets, lensir://scan, OpenScannerIntent,
                   the Lock Screen widget's views
LensirWidget/      the extension: the Control Center control and the Lock Screen widget
LensirTests/       Swift Testing suites
LensirUITests/     real-touch drawer gesture tests, lensir://scan and making a code (XCTest)
Config/            Lensir.xcconfig (bundle prefix, team, App Group, Wi-Fi join), Info.plists, entitlements
scripts/           screenshots, the splash recording, the icon, the launch mark and the control's symbol
```

## License

MIT. See [LICENSE](LICENSE).

Made by [DevAkintola](https://devakintola.com).
