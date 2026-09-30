# ShopHisab 1.6

Polished offline-first shop bookkeeping app. Existing navigation and green theme
are preserved, with targeted calculator, inventory, payment and backup fixes.

Start with [Build and release](docs/BUILD_AND_RELEASE.md).
See [Product and reliability review](docs/PRODUCT_AND_RELIABILITY.md) for changes,
backup behavior, migration details and the one-million-user capacity discussion.
See [Validation](docs/VALIDATION.md) for checks actually performed.

The included GitHub workflow is configured to build **ShopHisab.apk**.
An APK was not completed in this execution environment; see the validation report. The application ID remains
`com.businessos.businessos` to preserve update compatibility. The bundled signing
key is for testing; use your own private key for Play Store distribution.

Do not uninstall an existing installation until you have a verified backup.
Keep the backup passphrase: it cannot be recovered on a new phone.
