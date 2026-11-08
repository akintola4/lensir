# Lensir

Lensir is a QR code scanner for iPhone that works with no signal. Point it at a code and it tells you what's inside before anything opens. If the code is a link, it checks the address for the tricks scam codes use.

It comes from the same place as [Pocket](https://github.com/akintola4/pocket) and [Tape](https://github.com/akintola4/tape): small phone tools that keep working offline. Lensir has no network code at all. The camera, the checks and your history all stay on the phone.

It isn't on the App Store. You clone it, open it in Xcode and run it on your own phone.

## Screenshots

| Looking | Found | A safe link |
|---|---|---|
| ![Four white corner brackets over the camera, waiting for a code](docs/screenshots/looking.png) | ![The brackets snapped onto a QR code, with a white pill reading paystack.com under it](docs/screenshots/found.png) | ![The drawer for paystack.com: the full address, "Secure · the real paystack.com" and an Open in Safari button](docs/screenshots/safe-link.png) |

| A safe link, expanded | A lookalike | A lookalike, expanded |
|---|---|---|
| ![The drawer pulled up: Details with the full address and every check passed](docs/screenshots/safe-expanded.png) | ![Red brackets and a drawer saying the underlined "а" is a Cyrillic letter, so this is not paystack.com](docs/screenshots/lookalike.png) | ![Details for the lookalike: "The real site" and "Plain letters" crossed out in red](docs/screenshots/lookalike-expanded.png) |

| A short link over http | Wi-Fi | Wi-Fi, expanded |
|---|---|---|
| ![A bit.ly link: not secure, and a link shortener that hides where it goes](docs/screenshots/short-link.png) | ![A Wi-Fi code: network name, password, security and a Copy password button](docs/screenshots/wifi.png) | ![Every field of the Wi-Fi code, the raw text and a Scan again button](docs/screenshots/wifi-expanded.png) |

| Contact | Several codes in one photo | History |
|---|---|---|
| ![A contact card code with a Save contact button](docs/screenshots/contact.png) | ![A list of three codes found in one photo](docs/screenshots/photo-codes.png) | ![History grouped by day, with the swapped letter underlined in red on the risky link](docs/screenshots/history.png) |

| Camera turned off | No camera |
|---|---|
| ![Lensir needs the camera, with an Open Settings button](docs/screenshots/camera-denied.png) | ![No camera here, with a Choose a photo button](docs/screenshots/no-camera.png) |

The Simulator has no camera, so these use the launch arguments below. They draw a stand-in camera with a real QR code on a printed card. `scripts/screenshots.sh` takes all of them.

## What it does

- The camera fills the screen. Four white corner brackets wait in the middle with the rest dimmed. When a code turns up they snap onto it in about 200 ms with a light tap, and a white pill under the code names what it is: the site for a link, the network for Wi-Fi, the person for a contact card.
- Tap the pill and a drawer slides up from the bottom edge with the whole thing: the full address, the Wi-Fi password, the phone number. It works like the [shadcn/ui Drawer](https://ui.shadcn.com/docs/components/drawer). You can drag it from anywhere, not only the grabber. It follows your finger, and when you let go it settles where the throw would carry it. If Details are scrolled down, dragging down scrolls them back to the top first, then pulls the drawer down in the same movement. A quick flick down puts it away and the camera starts again. Pull it up, or tap the grabber, and a Details section shows every check as a pass or fail row, every field in the code, the raw text with a copy button, when you scanned it, and Scan again. While it's up, the camera behind it dims and sinks back a little. Each kind of code has its own main button:

  | Code | Main button | Second button |
  |---|---|---|
  | Link | Open in Safari | Copy link |
  | Risky link | Copy link | Open anyway (red) |
  | Wi-Fi | Copy password (Join Wi-Fi with a paid account, see below) | Copy network name |
  | Contact (MECARD or vCard) | Save contact | Copy details |
  | Phone number | Call | Copy number |
  | Text message (`sms:`, `SMSTO:`) | Send message | Copy message |
  | Email (`mailto:`, `MATMSG:`) | Write email | Copy address |
  | Place (`geo:`) | Open in Maps | Copy coordinates |
  | Text or a product barcode | Copy text | |

- Every code you open goes into History, newest first and grouped by day. Swipe a row to delete it, or clear the lot. Tapping a row opens it again.
- The photo button reads codes from a picture in your library. If there are several, you pick one from a list.
- A torch button for dark rooms, and a Haptics switch in Settings (behind History).
- Addresses, network names and numbers are set in SF Mono. In a monospaced face a swapped letter can't hide: l, 1 and I look different, and so do O and 0.

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

- There's no networking code in the app. It never sends a code, a photo or your history anywhere. Links only leave the phone when you press Open and Safari takes over.
- Photos are read with Vision on the phone. Lensir only sees the photo you pick; it doesn't ask for your library.
- History is stored with SwiftData in the app's own container. Delete the app and it's gone.
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

   `Config/Lensir.xcconfig` includes it if it exists. You can also edit `Lensir.xcconfig` directly, or leave the team empty and choose it under Signing & Capabilities. The bundle ID is `<prefix>.lensir`.
2. Plug in your phone, select it and press Run. The first time, go to Settings › General › VPN & Device Management on the phone and trust your developer certificate.

From the command line:

```bash
xcodebuild build -scheme Lensir -destination 'id=<your iPhone UDID>' -allowProvisioningUpdates
```

With a free Apple ID, an app you install from Xcode stops opening after 7 days. Run it from Xcode again to get another 7. Your history survives the reinstall.

### Joining Wi-Fi

Joining a network straight from a code uses `NEHotspotConfiguration`, which needs the Hotspot Configuration capability. A free Apple account can't sign that one. Xcode says "Personal development teams do not support the Hotspot capability". So it's off by default, and a Wi-Fi code's main button is Copy password, with Copy network name under it. You paste the password in Settings › Wi-Fi.

With a paid developer account, add `LENSIR_WIFI_JOIN = YES` to `Config/Local.xcconfig`. That adds the entitlement and brings back a Join Wi-Fi button.

### Tests

```bash
xcodebuild test -scheme Lensir -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1'
```

There are 120 tests in `LensirTests` and 8 in `LensirUITests`. The Swift Testing ones cover:

- every kind of code: links, Wi-Fi (escaped `;`, `:`, `\` and `"`, hidden networks, open networks, WEP, WPA3), MECARD, vCard 3 and 4 with folded lines, `tel:`, `sms:` and `SMSTO:`, `mailto:` and `MATMSG:`, `geo:`, plain text and barcodes
- every safety rule, the exact letters each lookalike underlines and the sentence it says
- real sites coming through clean, about 65 of them
- Punycode decoding, the skeleton, edit distance, and how an address is split into its parts
- which buttons each kind of code gets
- where the brackets and the pill go, including codes near the edge and near the bottom
- History grouped by day and newest first, and repeat scans merged
- the links handed to Phone, Messages, Mail and Maps
- reading three codes out of one photo with Vision, in order
- the drawer: following the finger, the rubber band above the top, which point a release snaps to (by position and by how fast it was thrown), the spring picking up the release speed, and the dim and background scale that follow its height
- what Details lists: a pass or fail row per check, and every field for each kind of code
- who gets a drag on the drawer: the drawer, the scroll view, or nobody for a sideways drag, including the hand-over when scrolled Details reach the top

`LensirUITests` uses XCTest, because Swift Testing can't drive the screen. It drags the drawer with real touches: down from the middle of Details, down while scrolled, by the header, up from the content, a flick to close, and a drag that starts on Open in Safari, which must move the drawer without pressing the button. Taps on buttons and the grabber still have to work. Those runs take about a minute and a half. Add `-only-testing:LensirTests` to skip them.

Leave out `OS=26.1` if your iPhone 17 Pro simulator runs a newer iOS.

### Launch arguments (Debug builds)

A few are in the scheme, switched off. Turn them on under Product › Scheme › Edit Scheme › Run › Arguments, or pass them to `xcrun simctl launch`.

- `-LensirDemo found` opens on a stand-in camera with a code in view. The scenes are `looking`, `found`, `safe`, `risky`, `http`, `wifi`, `contact`, `phone`, `text` and `photos`. All of them except `looking`, `found` and `photos` open the drawer too. `safe-expanded`, `risky-expanded`, `wifi-expanded` and `contact-expanded` open it pulled all the way up.
- `-LensirDemo drawer-tour` plays the drawer through by itself, since you can't drag in the Simulator: the brackets snap, the drawer rises, expands, settles back and is flicked away. It's how the recording in `~/Movies/Lensir drawer/` was made.
- `-LensirOpenHistory` opens History on launch, filled with demo scans. Add `-LensirEmptyHistory` to see it empty.
- `-LensirCameraDenied` acts as if camera access is turned off in Settings.
- `-LensirNoCamera` acts as if the phone has no camera.

Demo runs keep history in memory, so they never touch your real history.

### Scripts

- `scripts/screenshots.sh` builds Lensir for the Simulator and takes the screenshots in `docs/screenshots/`.
- `scripts/make-icon.py` draws the app icon. Run `python3 scripts/make-icon.py` to regenerate it (it needs Pillow).

## Project layout

```
Lensir/            the app
  Logic/           pure and tested: PayloadParser, LinkSafety, Confusables, Brands,
                   Punycode, LinkAddress, ResultSummary, ResultDetails, ScanGeometry,
                   DrawerLogic, HistoryLogic
  Scanner/         the screen: camera (VisionKit, with an AVFoundation fallback),
                   brackets, pill, photos, demo scenes
  Result/          the drawer and its state, the address text, saving contacts, joining Wi-Fi
  History/         SwiftData history and Settings
  Components/      colours, type, the press style
LensirTests/       Swift Testing suites
LensirUITests/     real-touch drawer gesture tests (XCTest)
Config/            Lensir.xcconfig (bundle prefix, team, Wi-Fi join), Info.plist, entitlements
scripts/           screenshots and the icon
```

## License

MIT. See [LICENSE](LICENSE).

Made by [DevAkintola](https://devakintola.com).
