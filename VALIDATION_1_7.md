# ShopHisab 1.7 verification

Verified on 2026-10-01 with Flutter 3.47.5 / Dart 3.13.4.

- 35 automated tests passed, including date-wise history, payment date boundaries,
  no double-counting after settlement, decimal/phone validation, compact-window
  history navigation, calculator widgets, invoice/stock/ledger behavior, PIN
  protection, authenticated backup encryption, restore rollback and legacy migration.
- Static analysis passed with no errors or warnings (68 informational style and
  deprecation notices remain).
- The source retains the existing app ID and database. Android configuration:
  minimum API 24, compile and target API 36, resizable activity.
- Release-mode APK built successfully and signed with the bundled test key.
  APK signature, package/version/SDK metadata, resizable activity, ZIP integrity,
  16 KB ZIP alignment and 64-bit native ELF alignment were verified.
  See docs/verification/1.7/apk-report.json for its SHA-256 and size.

Logs: docs/verification/1.7/. Older 1.6 logs are historical.
Physical handset/emulator testing and a live Google Drive sign-in/restore were
not performed. Universal device compatibility and one-million-user cloud
capacity have not been load-tested. Drive requires the correct OAuth and signing
certificate configuration. 
