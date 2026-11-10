# Billing Adapter Contract (Google Play Billing / StoreKit)

> Status 2026-11-10: the game talks to purchases only through the `Store` contract in `game/shell/store/store.gd`. Today only `MockStore` exists (debug/editor builds). This document is the brief for writing the two platform adapters once the official billing plugins are added and store accounts with test users exist — none of that is possible on the current dev machine.

## Contract (what the game expects)

`Store` (`extends RefCounted`):

| Member | Behavior |
|---|---|
| `is_available() -> bool` | `true` once the platform billing service is connected and products are queried |
| `store_name() -> String` | e.g. `"google_play"`, `"app_store"` |
| `purchase(product_id)` | Starts the platform purchase sheet. When finished, emit `purchase_finished(product_id, ok, receipt_id, error)` exactly once: `ok=true` only after the purchase is **paid and acknowledged/finished**; `error="cancel"` when the user backs out (the game shows nothing); any other error string is shown to the player |
| `restore()` | Queries owned non-consumables and emits `restore_finished(owned_product_ids)` |
| signal `revoked(product_id)` | Emit when the platform reports a refund/chargeback for an owned product |

The app layer (`main.gd`) maps `product_id` → entitlement via `ops_config.json` `shop.<key>.product_id`, then calls `Entitlements.shop_purchase` / `restore_grant` / `refund`. Adapters never touch the Board.

Register adapters in `Store.create()`:

```gdscript
static func create() -> Store:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		return GooglePlayStore.new()
	if Engine.has_singleton("InAppStore"):
		return AppStoreStore.new()
	if MockStore.allowed():
		return MockStore.new()
	return Store.new() # release build without an adapter: unavailable, never unlocks for free
```

## Google Play adapter

- Use the official Godot Google Play Billing plugin matching Godot 4.7 (Android, gradle build — already enabled in the Android preset). Add the `com.android.vending.BILLING` permission (the plugin's manifest does this).
- On start: connect, then query product details for all `product_id`s in `ops_config.json` (type `INAPP`). Use the returned **localized price** strings to replace `price_text` at runtime.
- `purchase`: launch the billing flow; on `PURCHASED`, **acknowledge** the purchase (non-consumables must be acknowledged within 3 days or Google refunds them), then emit success with the purchase token as `receipt_id`. `PENDING` purchases must not unlock until they become `PURCHASED`.
- `restore`: query purchases (`INAPP`) and emit the owned product ids.
- Refunds: Google only reports them via the Voided Purchases API (server-side) — without a server, re-query purchases on launch and emit `revoked` for entitlements the store no longer reports. Note that this re-check is the client's only refund signal.

## App Store adapter

- Use the Godot iOS StoreKit plugin (`InAppStore` singleton) built for Godot 4.7.
- On start: request product info for all product ids; use localized prices.
- `purchase`: on a completed transaction, **finish** the transaction, emit success with the transaction id. Handle `deferred` (Ask to Buy) as not-yet-owned.
- `restore`: call restore purchases (required by App Review to be user-triggered — the Home help page and the locked-chapter screen have the button) and emit the restored ids.
- Refunds: StoreKit 2 reports revocations on the transaction (`revocationDate`); emit `revoked` when seen.

## Test plan (per platform, with sandbox/license testers)

1. Fresh install, English market (`game/market = "global"`): the Prologue and Act I play; entering Act II shows the locked-chapter screen with the store's localized price.
2. Cancel the purchase sheet → still locked, no message.
3. Purchase → unlocks immediately, no restart; the purchase is acknowledged/finished.
4. Kill the app mid-purchase, relaunch → the purchase is delivered on next launch (adapters must process pending transactions at start).
5. Second device / reinstall → Restore Purchases unlocks.
6. Refund in the console → on next launch the entitlement is cleared; a run in progress can still finish, new games are locked (06 §5).
7. Airplane mode → the store is unavailable; buttons show the unavailable message; nothing unlocks.
