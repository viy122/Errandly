# Errandly

A mobile-first Flutter marketplace for everyday errands, anywhere. One account can request help and run tasks. Pickup and delivery addresses are unrestricted, including trips across towns, cities, or provinces. Flutter connects to a PHP API backed by MySQL-compatible tables (the installed XAMPP service is MariaDB 10.4). The optional demo seed includes 10 errands around Batangas, Metro Manila, Cavite, Cebu, and Davao.

## MySQL setup

Start **Apache** and **MySQL** in XAMPP. From this project directory:

```powershell
C:\xampp\php\php.exe api\setup.php --seed-demo
```

This creates the **errandly** database and 12 tables without dropping existing data. The seed runs only on an empty database. Do not rerun seeding to refresh task deadlines; existing errands and balances are preserved.

The defaults match local XAMPP: host `127.0.0.1`, port `3306`, user `root`, empty password. For different credentials, copy `api/config.example.php` to ignored `api/config.local.php`, or set `ERRANDLY_DB_HOST`, `ERRANDLY_DB_PORT`, `ERRANDLY_DB_DATABASE`, `ERRANDLY_DB_USERNAME`, and `ERRANDLY_DB_PASSWORD` in the PHP server environment. Database credentials belong only on the server.

Check `http://127.0.0.1/errandly/api/index.php?action=health` for `storage: mysql`. Open the **errandly** database in XAMPP's phpMyAdmin to inspect accounts, tasks and history.

The app uses `http://127.0.0.1/errandly/api/index.php` by default. To change it:

```sh
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1/errandly/api/index.php
```

For Android emulator testing, use `10.0.2.2` instead of `127.0.0.1`. A physical phone needs your computer's LAN address. Android debug/profile builds permit the local HTTP API; release builds require an HTTPS backend. Configure the server's allowed `origins` for your Flutter web preview's exact scheme/host/port. The current release preview at port **8089** is allowed. On other ports, set the allowlist explicitly; the API does not use wildcard CORS.

Publishing saves a shared MySQL listing that other runner accounts receive in their next feed refresh. Choose **Requester** or **Runner** on the login screen; the same account can use either role in separate sessions, and a requester cannot accept their own post. Runner mode shows a separate **Your live posts** preview. **Anna/Ben** demo-account selection is also on the login screen, under **Use demo accounts** (or **Continue as Demo User** from Welcome). There are no role or account switches in the signed-in header, feed or Profile. Log out through Profile to choose another role/account. Changing accounts resets area, search and category filters. Database connections use UTC for generated posting timestamps and API deadlines.

The runner feed has **Nearby** and **All locations** choices. Nearby requires an explicitly chosen location (device GPS or a selected map pin) and filters by straight-line distance to pickup: 10 km by default, with 5/10/25 km choices. It sorts the closest pickups first. A long delivery trip can still be nearby when its pickup is close. Posts without pickup pins remain visible in All locations, along with far-away posts; switching back keeps nearest ordering when a location is available. GPS denial or dismissal keeps the existing feed available. No location is requested at launch, and browse coordinates remain session-only. Selecting a city exits Nearby; changing accounts clears browse coordinates and radius settings. The posting form explains how a pickup pin makes the request discoverable in Nearby.

**Use my location** requests a fresh high-priority device fix, preserving its timestamp, reported horizontal accuracy and mock-location indicator in memory. Fixes older than two minutes are rejected. Nearby displays a zoomed map, coordinates, accuracy and update time; the blue dot and accuracy circle represent the device reading. **View or refine my location** opens the larger map; **Use my location** recenters even when coordinates have not changed. Unknown or greater-than-100 m accuracy is labeled approximate. Persisted errand pins still contain coordinates only. An Android emulator reports its configured virtual GPS position, not the computer user's physical position: test actual whereabouts on a physical phone with precise location enabled. Accuracy depends on the device, permissions and GPS reception; the app does not guarantee an exact position.

The browser retains its login in session storage across refreshes. Other platforms retain the current login in memory. All platforms load the saved data when they log in again. The API polls every 5 seconds while the app is in the foreground and refreshes immediately after successful changes or returning to the app. If MySQL is unavailable, a retry banner appears; the app does not silently replace database records with mock data.

For an entirely disconnected fixture demo, use `--dart-define=DEMO_ONLY=true`. Tests use the in-memory store unless they explicitly construct the API-backed store.

## Backend behavior

- Registration and login use server-side password hashes and expiring bearer sessions; password hashes and passwords are never returned in profile responses.
- Errand claims, payment holds, completion, refunds, and wallet updates run in database transactions with row locks. The server checks the authenticated owner or assigned runner, preventing duplicate claims, settlement and refunds.
- The completion PIN is returned only to the requester. Chat messages, wallet details, notifications and support reports are limited to the relevant account. Phone/email visibility is enforced by the server.
- Profiles, errands, progress, wallets, wallet entries, messages, notifications, reviews, reports, relationships and saved errands persist in MySQL.
- Anna/Ben selection at login uses local demo sessions. Set `demo` to `false` or `ERRANDLY_DEMO=0` to disable demo login, simulated verification/payments, expiry controls and support resolution. Actual proof uploads remain available for authenticated participants. Demo API actions are restricted to loopback clients. Do not deploy with demo mode enabled.
- This remains a development application. Real payment reconciliation, identity verification, file storage, password-reset email, production HTTPS/session hardening and abuse controls still need their corresponding services.

## Logo and opening intro

The shared UI uses locally bundled Manrope weights 400–800 from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/manrope), with its OFL license in `assets/fonts/OFL.txt`. Main text is near black, supporting text is dark gray, and primary controls use solid emerald. Forest-green headers, lime wallet accents, charcoal selections and solid avatar/badge colors give the interface stronger contrast. Shared panels, inputs and buttons have defined borders and compact corner radii; the styles are centralized in `lib/ui/theme.dart` and `lib/ui/components.dart`.

The approved parcel/check symbol and stacked Errandly logo are in `assets/brand`. A silent 5-second H.264 intro is bundled in portrait and landscape under `assets/videos`. It plays once per device/browser, with **Skip intro** and **Continue to Errandly** available throughout. Replay it from the welcome screen or Profile. Reduced-motion settings bypass the first-launch animation; unsupported video playback uses a matching Flutter animation, and a timeout always allows entry to the app. The seen preference is stored locally, independently of account login.

Web, Android, iOS, macOS and Windows launcher icons use the new symbol. Browser tabs use the matching PNG favicon.

## Run

From this directory, run:

```sh
flutter run -d chrome
```

The Flutter SDK on this machine is at `C:\Users\Admin\flutter`. Run `flutter pub get` to install the HTTP client dependencies.

For a release web build:

```sh
flutter build web --no-web-resources-cdn
```

Serve `build/web` through an HTTP server. To serve it through this project's XAMPP path instead, build with:

```sh
flutter build web --no-web-resources-cdn --base-href /errandly/build/web/
```

With Apache running, open `http://localhost/errandly/build/web/`.

## Try the complete demo

1. Choose **Continue as Demo User** to enter as Ben Santos. Alternatively, log in with `ben@example.com` and `demo123`.
2. In Runner mode, find **Buy 1 Yellow Pad** and accept Anna's errand. It leaves the available feed and appears under **My Jobs → Accepted** and **Active Job**.
3. Open the task and select **Start Errand**, then **Arrived at Store / Pickup**.
4. Set the actual cost to **45**, attach the sample receipt and item photo, and save purchase proof. The unused **5** belongs to Anna.
5. Select **Item Purchased / Picked Up**, **Start Delivery**, then **I've Arrived**.
6. Use **View as Anna** under the task's demo controls. Only the requester sees the randomly generated six-digit completion PIN.
7. Switch back to Ben, enter the PIN, and verify the handoff. The runner fee is still locked.
8. Switch to Anna and choose **Yes, Complete Errand**. Ben earns **40 CY** plus a separate **₱45** purchase reimbursement; Anna receives a separate **₱5** refund. The service fee is **5 CY**. Duplicate confirmation cannot settle funds twice. Older errands with coin purchase budgets keep their original terms.
9. Check wallet history, notifications, completed errands, and reviews from each account. Use **Profile → Log out**, then choose Anna/Requester or Ben/Runner in the demo login. Logging in loads that account's saved errands, conversations and separate MySQL wallet balance. Each account can use either role selected at login.

Anna, Maria, and Joshua use the same `demo123` password with their corresponding first name at `example.com`.

## Included interactions

- Mobile navigation uses Home (Find Errands for runners) / My Errands / Messages / Wallet / Profile, with no duplicate drawer. Desktop uses the sidebar instead of the bottom bar.
- Requesters post from Home or My Errands and track their own requests. Runners find available work that excludes their own posts and manage current jobs in the Active Jobs tab inside My Errands. Wallet priorities still follow the selected role.
- Profile links to Settings, Saved errands, Friends & favorites, and Safety center. Secondary pages include a return to Profile; posting returns to My Errands. Role and demo-account choices are available only at login.
- My Requests separates Posted, In Progress, Awaiting Confirmation, Completed and Cancelled; My Jobs separates Accepted, In Progress, Awaiting Payment, Completed and Cancelled. Expired posts appear in Cancelled with an expiry explanation.
- Choose Requester/Runner and the optional Anna/Ben demo account at login. Log out to change sessions. Task controls and completion PIN access follow the actual task owner and assigned runner.
- Both modes share one account wallet. Each view prioritizes its relevant transactions; All activity reveals the complete account history.

- Welcome, login, registration, simulated reset email, and identity verification.
- Requester / Runner mode, location filtering and search, all requested category and sort filters, saved errands, and task details.
- Free-form pickup/delivery addresses, listing-area filters, estimated distances in metres/km, travel methods, and multi-day or custom deadlines.
- Three-step posting, secured wallet or external simulated payment, acceptance confirmation, progress history, and purchase proof.
- Requester-only completion PIN, runner verification, requester confirmation, settlement, and reviews with five rating categories.
- Separate account wallets, top-ups, reviewed cash-outs, transaction history, pending earnings, and unused-budget refunds.
- Wallet top-ups open a dedicated page with portrait GCash/Card simulation cards that tilt during swipes, followed by an editable review. Successful credits show a dark receipt screen with paper feeding from a metallic printer slot. Print again replays the animation without another credit. The selected method is saved in wallet history. Pending submissions disable repeat taps, failed submissions stay on review, and reduced-motion settings display the receipt immediately.
- Posted, accepted, ongoing, completed, cancelled, and expired errands. Accepted cancellation holds progress and funds until mutual approval or a support decision.
- Task chats, saved-proof image viewing, quick location updates, notifications, profile editing, privacy controls, mutual friends, favorite runners, and hire-again invitations. Send is locked while saving; failed messages keep the draft. Chat scroll follows new messages when already near the end, while preserving the reader's position in older messages.
- Safety Center, blocking, evidence reports, and simulated report review states.
- Mobile bottom navigation and desktop sidebar. Layout checks cover phone, tablet, and desktop widths.

## Mobile design and private inquiries

The phone layout uses a compact green header, a category dropdown with an **All categories** reset choice, rounded errand cards, and bottom sheets for details, acceptance, notifications, and chat. The category dropdown is also used on desktop and Saved errands. Task progress stays compact, with the full timestamp history available on expansion.

Runners can privately ask a requester about an available errand before accepting it. Each requester/runner pair has its own inbox thread; accepting the job does not expose other runners' inquiries. Existing assigned-task messages retain their visibility. Run `php api/migrate.php` when updating an existing database to add the private-message recipient field.

Purchase budgets remain in pesos and runner payments in CY. Only the requester sees the handoff PIN, and verified handoff waits for requester confirmation before earnings are released.

## Receipts, onboarding, and notification preferences

Tap any wallet history entry to open its animated digital receipt. References come from the saved ledger ID; new top-ups and cash-outs also store the original peso amount. Older records show their recorded details without inventing a missing peso amount. Any current-rate equivalent is labeled as an estimate. Receipt viewing never moves funds, and purchase/service-fee allocations remain separate from additional wallet deductions.

First launches show the existing brand intro followed by a skippable three-step guide to roles, CY/PHP payments, and secure handoff. **How Errandly works** in Welcome, Profile, or Settings replays the guide. Guide completion and per-account notification choices persist on this device. Errand, chat, and wallet settings control in-app alerts and unread badges while preserving inbox history. Sound plays a bundled Errandly chime, subject to device mute and browser autoplay settings; background push delivery is not connected.

The six-digit handoff input accepts typed or pasted digits and shows validation errors inline. Verified handoff displays pending-payment feedback; only successful requester confirmation displays payment-release feedback. Login and registration show loading and prevent duplicate submissions. New transitions respect reduced-motion settings.

## Prototype boundaries

Registration uses a general email and identity verification; school enrollment is not required. Location filters come from listing areas and can be searched; custom areas appear when an errand is posted. Addresses remain freely editable. Optional map pins, foreground device location, and OSRM car-road estimates are supported; courier integration is not connected. The demo uses CY and PHP for payments.

The default app persists data in MySQL and restores the browser session after refresh. The disconnected fixture demo resets on refresh. Authentication, actual proof images, saved map pins and route metadata use the PHP API. Payments, identity verification, email, SMS and general report resolution remain simulations. Report evidence still uses sample markers. Password reset simulates sending an email; it does not change an account password. Email features are deferred. Use sample account information during development.

The top-up rate is **₱100 → 110 CY**; cash-out is **110 CY → ₱80**. Runner payments are denominated in CY and the cash-out preview shows the peso payout, rounded to two decimal places. The app and server use separate top-up and cash-out rates. Purchase/service-fee history rows allocate previously secured funds rather than charging a wallet again.

New requests secure **runner payment + 5 CY service fee** from the coin wallet. Their **purchase budget is funded separately in pesos** via a simulated GCash/card payment. On confirmed completion, the runner receives the actual purchase cost as a separate simulated peso reimbursement, with no coin conversion deduction; unused pesos are refunded separately. Cancellation or expiry returns both the secured coins and the full peso budget once. History labels each amount as PHP or CY. These are simulations, not real transfers.

Run `C:\xampp\php\php.exe api\migrate.php` once for an existing database (new installations run it through `api\setup.php`). It adds currency, receipt, and private-conversation fields: existing balances, history and older coin-funded errands retain their original settlement/refund terms. New demo databases use the separate peso purchase flow.

Unaccepted deadlines expire automatically while the application is open. **Simulate deadline expiry** in your posted task lets you test the refund immediately. Accepted cancellation requests remain under review with funds secured. Simulated report resolution changes report status only.

## Organization

Cancellation and PIN recovery are persisted in MySQL. Run `php api/migrate.php` when updating an existing installation; it adds recovery fields and attaches old unresolved cancellation reports to their active errands without changing balances.

Either participant can request accepted-task cancellation. The other participant can agree to a full refund before recorded purchase proof or delivery work. Disagreement keeps the task under review; the initiating participant can withdraw to resume. Recorded purchases/delivery require support review. Approval reimburses the recorded purchase cost, pays the selected runner compensation within the secured fee, and refunds the remaining coins/pesos once. Reviews never convert purchase pesos into coins. Closed tasks reject repeated decisions. In local demo accounts, **Simulate support decision** lets you test approve/reject; it remains a development simulation.

For actual support access, set server-side `ERRANDLY_SUPPORT_USERS` to a comma-separated list of existing account IDs, or set `support_users` in the ignored local API configuration. Only those reviewers see the pending cancellation queue in Safety Center. Registration/profile data cannot grant support access. Non-demo participants cannot review their own disputes.

After five incorrect handoff attempts, the runner's PIN entry locks. The requester can select **Replace handoff PIN** before verified handoff. The old PIN immediately stops working; attempts reset, the new PIN remains requester-only, and replacement has a one-minute cooldown. Replacement cannot bypass requester confirmation or release payment.

Posting autosaves an account-specific draft on this device, including form step, addresses, category, deadline and amounts. Reopening after navigation/refresh restores it; expired deadlines must be changed before publishing. **Discard draft** clears the form with confirmation. Successful posting clears the draft. A saved draft reference makes network retries idempotent, preventing another hold of funds for the same post. Role choices are remembered per account on this device. Drafts do not sync between devices; unavailable device storage displays a save warning.

Run `flutter test test/recovery_test.dart` and `php test/recovery_php_test.php` for cancellation permission, reimbursement, PIN recovery, draft persistence and retry regression checks. The PHP test rolls back all records; it also runs with `ERRANDLY_DEMO=0`.

- `lib/models/entities.dart`: user profiles, errands, wallets, history entries, messages, reviews, reports, and notifications.
- `lib/state/errand_store.dart`: account state and API integration, plus in-memory fixtures for isolated tests.
- `lib/data/`: HTTP client, session storage and entity serialization.
- `api/schema.sql`: relational database schema.
- `api/index.php`, `api/commands.php`, `api/bootstrap.php`: authenticated PHP API, server-side lifecycle rules, atomic settlement and account-scoped reads.
- `api/setup.php`, `api/seed.php`: non-destructive CLI setup and optional sample data.
- `lib/ui/`: responsive shell, reusable components, authentication, marketplace, posting, tracker/chat, and account/community screens.

Database writes enforce the lifecycle on the server. Wallet top-ups, external payments, cash-outs, verification and report resolution are still explicit development simulations.

## Actual proof images

Run `C:\xampp\php\php.exe api\setup.php` for an existing installation to add `proof_files` without resetting records or balances. Receipt and item images are required at the purchase step; the actual cost must be entered within the secured purchase budget. Non-purchase tasks can also include an optional delivery photo after arrival and before handoff. Native file selection supports web, Android, iOS, Windows, Linux and macOS; native builds need their usual platform toolchains. macOS includes read-only access to user-selected files.

Choose JPG, PNG or WebP images, up to 2 MB each and 20 megapixels. Preview and change/remove a selected file before saving. The API validates actual image bytes, size, ownership and the task stage. Both purchase images and the cost commit together; failures retain the selections for retry. Replacing one image preserves the other, and retries of identical uploads do not duplicate notices. Pending cancellation and closed/handoff-verified jobs freeze updates.

Image bytes are stored in MySQL `MEDIUMBLOB` records; the normal state response includes only metadata. An authenticated binary endpoint serves each image to the owner, assigned runner or configured support accounts, with no public file directory or token in the URL. The requester can open and zoom saved proof after refreshing or signing in again. Older sample flags are labeled as legacy samples and do not stand in for new file uploads. The in-memory test fixture stores actual selected bytes only for its current session.

## Verify

```sh
flutter analyze
flutter test
C:\xampp\php\php.exe api\tests.php
C:\xampp\php\php.exe api\proof_tests.php
C:\xampp\php\php.exe api\map_tests.php
C:\xampp\php\php.exe test\purchase_currency_php_test.php
C:\xampp\php\php.exe test\wallet_rates_php_test.php --database
C:\xampp\php\php.exe test\transaction_receipts_php_test.php
C:\xampp\php\php.exe test\private_chat_php_test.php
flutter build web --no-web-resources-cdn
```

Flutter tests cover handoff gating, payment/refund amounts, duplicate settlement, cancellation, expiry, wallet validation, verification, role views, responsive layouts and API failure/account-switch behavior. PHP integration checks use the running MySQL database and roll back their test mutations, preserving existing records.

## Maps and clearer choices

Run `C:\xampp\php\php.exe api\migrate.php` on an existing installation to add optional pickup/drop-off coordinates, trip source, car-route duration and `map_cache`. Existing trips remain manual estimates; old addresses are never silently geocoded. Pins and route metadata persist in MySQL and in the per-account posting draft. Editing an address clears its pin and any calculated route; changing travel method also discards the road estimate. A late response from a previous route request is ignored.

Choose pickup/drop-off on the map, search a place or address and explicitly press Search, or use the device location button. Confirm the selected result/pin before returning to the form. Address search uses server-proxied [Nominatim](https://operations.osmfoundation.org/policies/nominatim/) with an identifying user agent, one-day cache and a global limit of one outbound search per 1.1 seconds. It never searches on each keystroke. Maps use standard OpenStreetMap tiles with visible linked attribution and the map package's tile caching; no prefetch/offline bulk download is enabled. Search results still work if tiles cannot load.

`Calculate road route` uses [OSRM's driving profile](https://project-osrm.org/docs/v5.24.0/api/) for Car/Motorcycle selections and shows an explicitly labeled car-road estimate, meters converted to kilometres, route geometry and approximate duration. It does not include live traffic or motorcycle-specific restrictions. Walking, cycling, transit and shipping retain manual estimates. Unavailable/no-route responses keep manual entry available. The public services are for this development preview; configure `geocoding_url`, `routing_url` and `maps_user_agent` in the ignored local server config for managed/self-hosted deployment. Follow the [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/) for production.

The single mobile Sort button opens a choice sheet; desktop retains its dropdown. `Nearest to me` requests device location only when selected and sorts straight-line distance from that position to each pickup pin. It never sorts by trip length, invents locations for unpinned posts, or sends browsing GPS to the API. Unknown pickup pins appear last. `Shortest trip` sorts pickup-to-drop-off estimates separately. Browsing location stays in memory, can be refreshed explicitly, and clears on account switch/logout. Location denial/offline/timeout does not block ordinary browsing or posting. Android requests foreground coarse/fine location; iOS/macOS have usage descriptions. Web location needs a secure context (HTTPS or localhost). Native runtime permissions and iOS/macOS toolchains need device/platform testing.

Listing-area selection is searchable on both phone and desktop, without restricting free-text posting addresses/cities. Purchase funding uses mutually exclusive GCash/card cards displaying the exact peso budget. The runner/service fee still uses the coin wallet; the payment methods remain explicitly labeled simulations.
