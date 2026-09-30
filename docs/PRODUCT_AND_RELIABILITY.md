# ShopHisab 1.6: product and reliability review

## What changed

| Area | Change |
| --- | --- |
| Calculator | Shop-style sequential arithmetic, contextual %, reliable ±, repeat equals, error recovery, copy result, bounded session history, haptics, scrollable tax sheet |
| Inventory | Atomic stock adjustments, no new negative stock, add/remove stock dialog, low-stock filter |
| Invoices | Validation at repository boundary, rounded two-decimal amounts, invoice sequence inside the same transaction as stock/items/ledger, partial status derived from actual amount |
| Payments | Customer payments settle oldest outstanding invoices first; excess stays in customer credit. Invoice-linked ledger rows cannot be deleted independently |
| Collections | Invoices paid through the ledger are not counted a second time as cash sales |
| Customers | Credit limit and blocked-customer checks; deletion cannot orphan existing financial history |
| Backup | Consistent SQLite VACUUM snapshot; versioned authenticated AES-256-GCM; random salt and nonce; PBKDF2-HMAC-SHA256; separate 10+ character passphrase |
| Restore | Authenticate, stage, integrity-check, migrate and decode before live writes; live record replacement is one SQLite transaction; no raw overwrite of an open database |
| Drive | Timeouts, bounded exponential backoff with jitter, paginated listing, legacy backup names, resumable upload chunks, download size cap |
| Security | Salted PIN derivation, legacy PIN migration, persistent cooldown after 5 failures, relock after 30 seconds in background, Android automatic backup disabled |
| Global usability | Seven business currencies; currency is fixed for existing books; clear English labels and tax calculator supporting custom percentages |
| Build | ShopHisab launcher and APK name; meaningful analyzer/test gates; stable test signing and an explicit private release-key path |

## Backup/restore behavior

Every export represents one committed database snapshot, including WAL content.
A new backup is authenticated before decryption is accepted. Wrong passwords,
modified files, missing tables, unsupported versions and failed SQLite integrity
checks do not overwrite the live database. Restore imports supported tables in
one transaction so failure rolls back the whole change. Existing subscriptions
remain attached to the open live database. A successful restore returns through
the normal startup/PIN flow. Backups replace records; they do not merge records.

The encrypted file cap is 64 MiB. Encryption and key derivation run in a worker
isolate. This is a bounded mobile implementation, not an unlimited backup engine.
Database staging and typed rows still consume memory; profile larger real stores
on low-memory phones before expanding the cap. Interrupted cloud transfers can
resume within the current attempt, but session state is not persisted after app
termination. The previous cloud backup is never deleted automatically.

A local share-sheet cancellation is not counted as a confirmed backup. Even a
successful share result is only an OS hand-off; users should ensure the file
exists at the chosen destination. A backup file and its passphrase are both
required when moving phones. PIN/biometric settings remain device-local.

The app's local SQLite file uses Android app-sandbox protection, not SQLCipher
whole-database encryption. The encrypted exports do not change this distinction.
Legacy CBC backups cannot be cryptographically authenticated retrospectively;
SQLite checks reduce accidental-corruption risk. Re-export a legacy restore into
the new authenticated format.

## One million users: what this architecture does and does not establish

Daily record entry, calculator, inventory and invoices run on each user's phone.
There is no shared ShopHisab database or central login service taking a request
for every transaction. One million installations therefore do not translate into
one million concurrent writes to a single app server.

Google authentication and Drive backups are shared external dependencies with
project/user quotas. Client retries improve resilience; they cannot create quota
or prove production capacity. A million backups per day is about 11.6 backup
starts per second on average, with much higher peak demand and multiple API
requests per backup. A million simultaneous uploads is a very different load.
No one-million-user load test is claimed for this deliverable.

Before mass rollout:

1. Establish the actual workload: active shops, backup frequency, median and p95
   database size, peak upload concurrency, geography and device memory.
2. Confirm production OAuth setup, applicable Drive project/user quotas and
   quota-increase needs with Google.
3. Run controlled tests against a staging project with approved test accounts;
   ramp gradually and monitor latency, 401/403/429/5xx, completion rate and costs.
4. Test interruptions at each upload chunk and each restore stage; test low disk,
   process death, migrations from prior releases and concurrent stock changes.
5. Beta-test on low-end Android devices, then use staged Play rollouts and
   privacy-conscious crash reporting. Establish backup success and restore-success
   targets before expanding deployment.

## Remaining scope and product choices

The existing app remains a single-business, single-device book with manual backups.
It does not add staff collaboration, automatic background backups, server accounts,
exchange-rate conversion, tax filing or jurisdiction-specific compliance. English
and Hindi remain the existing app languages; new copy is currently English.

Very large individual stores still require paginated customer/product/invoice
screens and database-side dashboard aggregation. The existing screens subscribe
to full lists; the new indexes improve targeted queries but do not make a million
records on one phone responsive. That is distinct from a million independent users.

Currency selection is deliberately fixed after business creation. A currency
switch is not a mathematical conversion. Tax presets are calculation shortcuts,
not tax advice. GST split labels apply only in the relevant Indian context.
The calculator is explicitly sequential (2 + 3 × 4 = 20), not scientific precedence.

Sources consulted for the implementation:
- https://drift.simonbinder.eu/examples/existing_databases/
- https://drift.simonbinder.eu/dart_api/transactions/
- https://developers.google.com/workspace/drive/api/guides/manage-uploads
- https://developers.google.com/workspace/drive/api/guides/limits
- https://developers.google.com/workspace/drive/api/guides/appdata
- https://pub.dev/documentation/cryptography/latest/
