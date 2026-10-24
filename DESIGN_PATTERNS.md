# Design Patterns & Conventions — pochero_pos_lite

This is the small sibling of `../pochero_pos`. The full app has controllers,
features folders, and heavy backend sync — **don't bring those here.** Lite keeps
the UI-first POS plus a thin sqflite store and a thin REST client for payments.

## Prime directive: small and familiar

- Optimize for the person at the counter, not for the codebase.
- Prefer boring, direct code over indirection.
- Smallest thing that works. Start with the UI; wire behavior only when asked.
- A design you can't explain in one sentence is a design you'll regret.
- If a change wants a new layer, stop and ask first.

## Folder layout (flat, intentionally)

```
lib/
├── main.dart                    # PocheroPosLiteApp + theme + desktop FFI setup
├── session_store.dart           # current user + backend URL (persisted)
├── auth_screen.dart             # login form: URL, username, password
├── models.dart                  # TransactionType, PaymentMethod, Product,
│                                #   RecipeItem, CartLine, Payment, formatters
├── payments_store.dart          # PaymentsStore (ChangeNotifier) over the repo
├── products_store.dart          # ProductsStore: list + order + recipes
├── pos_screen.dart              # POS scene: cart panel + product panel
├── cash_received_dialog.dart    # picks method, asks for cash, returns amount
├── payments_screen.dart         # the payments list
├── payment_details_screen.dart  # one payment: info box + items table
├── products_screen.dart         # product records: reorder + add
├── product_details_screen.dart  # one product: info box + recipe
├── sync_screen.dart             # manual sync: spinner + result messages
├── payments_api.dart            # PaymentsApi + REST client for the Go backend
├── payments_repository.dart     # PaymentsRepository + SqflitePaymentsRepository
├── products_repository.dart     # ProductsRepository + SqfliteProductsRepository
├── local_database.dart          # LocalDatabase (open/close/delete)
├── payments_table.dart          # `payments` table SQL
├── payment_items_table.dart     # `payment_items` table SQL
├── products_table.dart          # `products` table SQL
└── product_recipes_table.dart   # `product_recipes` table SQL
```

Keep one public class per file, file name in `snake_case`. Private helper
widgets (`_CartLineTile`, `_InfoBox`, …) stay in the file that uses them.

## Patterns in use

### 1. Immutable models (`models.dart`)
`Product`, `RecipeItem`, `CartLine`, and `Payment` have `const` constructors and
`final` fields; `Product` and `CartLine` have `copyWith`. Never mutate a model —
replace it.

- Enums carry their display text: `TransactionType.label`,
  `PaymentMethod.label`.
- Money is always rendered with `formatPeso`; timestamps with `formatDateTime`.
  Never format currency inline.

### 2. Repository pattern (`payments_repository.dart`)
`PaymentsRepository` is the interface; `SqflitePaymentsRepository` is the
on-device implementation, backed by `local_database.dart` and the two table
files. A payment and its lines are written in one transaction. Tests inject an
in-memory fake, so widget tests never touch sqflite; the repository itself is
covered by a real-sqlite test using `sqflite_common_ffi`.

### 3. In-memory stores over a repo (`payments_store.dart`, `products_store.dart`)
Both `PaymentsStore` and `ProductsStore` extend `ChangeNotifier` and hold an
optional repository:

- `load()` reads stored data at startup (used by `PosScreen.initState`). An
  empty product store is seeded with `defaultProducts`.
- Mutations update memory first, then persist (`add`, `remove`,
  `swapProductPositions`, `moveProduct`, `addRecipeItem`, `removeRecipeAt`).
- Screens read them with `ListenableBuilder` (or a listener + `setState`).
- No repository → in-memory only (keeps unit tests trivial).

`PosScreen` owns both stores and hands them to the list/detail screens when
navigating.

### 4. Ephemeral UI state stays in the widget
The cart (`List<CartLine>`), the search query, and the selected
`TransactionType` live in `_PosScreenState`. They are not shared, so they are
not a store. Use `setState`.

### 5. Views compose; widgets are small
`PosScreen` composes `_CartPanel` and `_ProductPanel`; each is a private,
single-purpose widget. No business rules in `build`. Pull data first, then
render.

### 6. Product records, order, and recipes (`products_store.dart`)
`Product` carries an `id` and a flat `List<RecipeItem>` (an ingredient name);
a fresh database is seeded with `defaultProducts`. Order is a
`position` column in `products`, rewritten by `saveProductOrder` on every
reorder. Recipes are replaced wholesale via `saveRecipe` (delete + reinsert) —
tiny lists, so no per-row ids to manage.

- **Reorder** happens only in the **Products screen**
  (`products_screen.dart`), a `ReorderableListView.builder` (use
  `onReorderItem`, which already adjusts the index). The POS grid is
  display-only and reflects the saved order. The screen also has an "Add
  product" dialog (name + price) and a search field; while a query is active it
  falls back to a plain (non-reorderable) `ListView` so the drag indices stay
  valid.
- **Recipe screen** (`product_details_screen.dart`): info box + recipe header +
  rows with a remove button; "Add ingredient" dialog. Follows the same info-box
  + table shape as the payment details screen.

### 7. Confirm flow (`cash_received_dialog.dart` → `_confirm()`)
`CashReceivedDialog` shows the total, lets the cashier pick **Cash** or
**GCash**, and pops `(PaymentMethod, amount)` (or `null` when cancelled). For
cash it takes the amount received and confirm stays disabled until it covers the
total; GCash is the exact total with no change. `_confirm()` builds the
`Payment`, awaits `store.add(...)`, clears the cart, then pushes
`PaymentDetailsScreen` for the new payment. Its AppBar has an explicit **Back**
button; the same screen is reachable by tapping a payment in the list.

```
id         UUID v4 (uuid package)
type       walk-in | delivery (as chosen on the POS)
method     cash | gcash (as chosen in the dialog)
amount     cash received, or the exact total for GCash
change     amount - total
updatedAt  DateTime.now()
items      a snapshot copy of the cart lines
dirty      true (still needs syncing)
```

### 8. Login + manual sync (`session_store.dart`, `auth_screen.dart`, `sync_screen.dart`, `payments_api.dart`)
Login is a local gate, persisted with `shared_preferences`:

- `SessionStore` (a `ChangeNotifier`) holds the current `username` and `url`.
  `load()` restores them at startup; `login()` validates and persists;
  `logout()` clears them.
- There is **no backend user table yet**, so the only accepted credentials are
  `SessionStore.adminUsername` (`admin`) / `adminPassword` (`123`). Do not add a
  user sync layer until the backend schema exists.
- The URL is validated as http(s) and stored without a trailing slash.
- `PocheroPosLiteApp` listens to the session and shows `AuthScreen` when signed
  out, `PosScreen` when signed in. The POS app bar has a logout action.

Sync is **manual only** — nothing calls the backend on its own:

- `PaymentsStore.pendingSync` returns dirty payments; `syncPending()` POSTs them
  to `/sync` and marks each clean (`markSynced`, in-memory + DB) on success.
- `add()` only persists locally; `load()` only reads the DB. No auto-retry.
- `SyncScreen` is opened from the POS app bar. It shows a large
  `CircularProgressIndicator` while `syncPending()` runs and a message after
  ("Synced N payment(s).", "Everything is up to date.", "Sync failed: …").
- `PaymentsApi` is the remote contract (`HttpPaymentsApi` uses `package:http`).
  `POST /sync` sends `{ "payments": [ …payment columns… ] }`; more entity types
  will join the payload later. The base URL is `SessionStore.url`.
- Keep `dirty` as the outbox for manual sync; don't re-add automatic triggers.

## Database (sqflite)

- `local_database.dart` owns the connection: `open()`, `close()`, `delete()`.
  `delete()` is for tests. `_version` is **4**: v1 had the payment tables, v2
  added the product tables, v3 dropped the recipe `quantity` column (the
  `product_recipes` table is recreated in `onUpgrade`), v4 added
  `payments.dirty`. Bump `_version` and extend `onUpgrade` whenever the schema
  changes.
- The DB file is placed via `path_provider`'s `getApplicationSupportDirectory()`
  (the platform app-data dir). **Never** put it in the project/build directory —
  `flutter clean` and `flutter test` would delete it. The repository tests point
  `path_provider` at a temp dir (`test/support/test_path_provider.dart`) so they
  never touch real data.
- `payments`: `id, type, method, amount, change, updated_at, dirty`. `dirty`
  (1/0) marks a row that still needs syncing; new payments default to dirty, and
  rows loaded from the DB carry whatever was stored.
- `payment_items`: `id (auto), payment_id, product_name, unit_price, quantity`.
  Name/price are snapshots taken at sale time.
- `products`: `id, name, price, position`.
- `product_recipes`: `id (auto), product_id, ingredient, position`.
- `main.dart` installs `sqflite_common_ffi` on Linux/Windows/macOS; Android/iOS
  use the native plugin. Keep that setup in `main.dart`.

## Payment details layout convention

Mirror the full app's detail screen so the two stay visually consistent:

- **Info box** on top: a `Material` with `surfaceContainer`, radius 12, 16
  padding, holding label/value rows (`_InfoRow`: muted label left, semibold
  value right). **`Total` is always the last row** and uses the primary color.
- **Items table** below: a non-scrolling header row
  (`Item | Qty | Unit Price | Amount`) in `titleSmall`/bold/onSurfaceVariant,
  then a `ListView.separated` of rows with `Divider`s. Column widths are fixed
  (`Expanded` for the name, 48 for qty, 96 for unit price, 96 for amount) so
  the header and rows line up.

## UI conventions

- **Theme first**: colors/text styles come from `Theme.of(context)`. The seed
  color and app-bar style live in `main.dart` only.
- **Stable boxes**: cards get their size from the grid delegate, never from
  content. Clamp text with `maxLines` + `TextOverflow.ellipsis`; put flexible
  text in `Expanded`.
- **`const` where possible** so subtrees are reused.
- **Grids** use `SliverGridDelegateWithMaxCrossAxisExtent` for responsive
  columns.

## Adding a feature (checklist)

1. Can it be done with the existing models + a `setState` or the store? Do that.
2. New persisted data → a table file + `LocalDatabase` change + repository
   methods. Keep it to what the feature needs; no generic data layer.
3. Remote calls go through `PaymentsApi` (add a method) and are triggered only
   from an explicit UI action — never automatically. Keep the local store as the
   source of truth. Recipes/inventory or `provider` are still the full app's
   territory — ask first.
4. Build the screen from small private widgets; reuse `formatPeso`.
5. Add a widget test (fake repository) and, for persistence, a real-sqlite test
   under `test/`; for REST, test against `MockClient` (`package:http/testing`).
6. Run `flutter analyze` and `flutter test` (absolute binary in `README.md`).

## Verification

```bash
/home/levidev/development/flutter/bin/flutter analyze
/home/levidev/development/flutter/bin/flutter test
```

Clean analyze and green tests are required before a change is done.
