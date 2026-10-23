# pochero_pos_lite

A small POS for the family shop. Same look as the full app at `../pochero_pos`,
far less machinery. It does the counter job — products, a cart, and recorded
payments — and stops there.

## What it does today

- Product grid with search.
- Tap a product → it goes to **Current Order** (tap again to bump quantity;
  `−`/`+` adjust a line, `−` at 1 removes it).
- Choose **Walk-in** or **Delivery**.
- **Confirm** asks how the order was paid — **Cash** (with change) or **GCash**
  (exact total) — records a payment, clears the cart, and opens that payment's
  details.
- **Payments** (receipt icon in the app bar) lists recorded payments — **today**
  by default, switchable to **all** — and the total reflects the current filter;
  tap one for its details and items.
- **Products** (menu icon in the app bar) manages product records: search the
  list, add a product, drag rows to reorder, and tap a row for its **recipe** —
  add or remove ingredients there.
- Payments, products, and recipes are stored on the device with **sqflite**, so
  they survive restarts. The file lives in the platform **app-data directory**
  (e.g. `~/.local/share/pochero_pos_lite/` on Linux) — not in the project
  folder — so `flutter clean` and test runs can't wipe it.
- New payments are **synced to the Go backend** over REST (`POST /payment`).
  A payment is born `dirty`; it is marked clean only after the request succeeds,
  and dirty payments are retried the next time the app loads. With no backend
  URL configured the app runs fully offline.

## Login & backend connection

The app opens on a **login screen** asking for:

- **Backend URL** — e.g. `http://localhost:8080` (must be http/https).
- **Username** / **Password** — local only for now; the single built-in user is
  **`admin`** / **`123`**.

Login is persisted with `shared_preferences` (current user + URL), so the app
reopens signed in. Use the logout icon in the POS app bar to sign out (and change
the URL). There is no backend user table yet, so users are not synced.

`GET /payment/{id}` is also implemented (`HttpPaymentsApi.getPayment`) for
future reads.

`POST /payment` sends:

```json
{
  "id": "<uuid>",
  "transaction_type": "walkIn | delivery",
  "method": "cash | gcash",
  "paid_amount": 500.0,
  "change_amount": 315.0,
  "items": [{ "name": "Pochero", "quantity": 2, "unit_price": 185.0 }]
}
```

Adjust `paymentPayload` in `payments_api.dart` if the Go handler expects a
different shape.

## Deliberately not here yet

- No backend user sync (single built-in local user).
- No ingredient inventory or stock counts (a recipe is a flat list, not stock).
- No `provider` or extra service layers.

If a feature needs one of those, confirm the need first — do not add a layer
"for later". See `DESIGN_PATTERNS.md`.

## Layout

```
lib/
├── main.dart                    # app + theme; session gate; desktop FFI factory
├── session_store.dart           # current user + backend URL (persisted)
├── auth_screen.dart             # login form: URL, username, password
├── models.dart                  # enums, value objects, formatters
├── payments_store.dart          # payment log + REST sync (ChangeNotifier)
├── products_store.dart          # product list + order + recipes (ChangeNotifier)
├── pos_screen.dart              # the POS: cart + product grid
├── cash_received_dialog.dart    # method + amount before confirming
├── payments_screen.dart         # list of recorded payments
├── payment_details_screen.dart  # one payment's info box + items table
├── products_screen.dart         # product records: reorder + add
├── product_details_screen.dart  # one product's info box + recipe
├── payments_api.dart            # PaymentsApi + REST (Go backend) client
├── payments_repository.dart     # PaymentsRepository + sqflite implementation
├── products_repository.dart     # ProductsRepository + sqflite implementation
├── local_database.dart          # sqflite connection (open/close/delete)
├── payments_table.dart          # `payments` schema
├── payment_items_table.dart     # `payment_items` schema
├── products_table.dart          # `products` schema
└── product_recipes_table.dart   # `product_recipes` schema

test/
├── widget_test.dart             # UI, with in-memory fake repositories
├── payments_api_test.dart       # REST client against a mock http client
├── payments_repository_test.dart # real sqlite via ffi
├── products_repository_test.dart # real sqlite via ffi
└── support/test_path_provider.dart # points path_provider at a temp dir
```

## Run

Android/iOS use the sqflite plugin; Linux/Windows/macOS use the FFI factory
installed in `main.dart`. Sign in on first run with the backend URL and
`admin` / `123`; the session is remembered.

Flutter is not on `PATH` on this machine; use the absolute binary:

```bash
/home/levidev/development/flutter/bin/flutter run -d linux   # or an Android device
```

## Verify (definition of done)

```bash
/home/levidev/development/flutter/bin/flutter analyze
/home/levidev/development/flutter/bin/flutter test
```

Both must be clean/green before calling a change done. Conventions live in
`DESIGN_PATTERNS.md`.
