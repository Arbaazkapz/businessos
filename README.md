# ShopHisab 1.7

Polished offline-first shop bookkeeping app. Existing navigation and green theme
are preserved, with targeted calculator, inventory, payment and backup fixes.

Start with [Build and release](docs/BUILD_AND_RELEASE.md).
See [Product and reliability review](docs/PRODUCT_AND_RELIABILITY.md) for changes,
backup behavior, migration details and the one-million-user capacity discussion.
See [Validation](VALIDATION_1_7.md) for checks actually performed.

The delivered **ShopHisab.apk** is a verified release-mode build signed with the
bundled test key. The included GitHub workflow can reproduce the build.
APK build and verification status is recorded in the validation report. The application ID remains
`com.businessos.businessos` to preserve update compatibility. The bundled signing
key is for testing; use your own private key for Play Store distribution.

Do not uninstall an existing installation until you have a verified backup.
Keep the backup passphrase: it cannot be recovered on a new phone.


## New in 1.7

- Home → plus/tools → History / Previous: 30-day pages, date picker, daily
  invoice sales, credit and collections; tap a date for paged transaction
  records and tap an invoice to view its full details.
- Shared numeric, phone and name validation; invalid pasted prices are rejected
  instead of silently becoming zero. India numbers need 10 digits; international
  customer numbers use an explicit +country code. Optional phone fields stay optional.
- Resizable Android activity, scrollable calculator/PIN screens and compact
  navigation for split-screen and supported handset pop-up windows.
- Existing database and application ID retained. No uninstall is required when
  the installed app uses the same signing key and an older version code.

See docs/RELEASE_1_7.md for exact support and verification status.
