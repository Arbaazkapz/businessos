# Validation results

Validation used Flutter 3.47.5, Dart 3.13.4 and Java 17.

| Check | Observed result |
| --- | --- |
| Dependency resolution and Drift generation | Passed |
| `flutter analyze --no-pub --no-fatal-infos` | Passed: no errors or warnings; 54 informational style/deprecation diagnostics remain |
| `flutter test --no-pub` | 28 tests passed |
| Standalone calculator smoke checks | 10 passed |
| Calculator render | Passed at 390 × 844; screenshot in calculator-preview.png |
| Android launcher icons and XML configuration | Generated and checked |
| Release APK | Not produced in this environment; see build attempt notes below |

## Covered behavior

- Calculator signs, contextual percentages, repeated equals, division by zero,
  decimal input, bounded history, small-phone layout and tax-cent rounding.
- Authenticated encrypted backup round trips; wrong passwords and damaged
  headers/nonces/ciphertext; legacy CBC compatibility.
- Restore into a live database without closing its connection; unchanged data
  after rejected restores; version-1 database migration, historical paid
  invoices, notes creation and default currency.
- Invoice/ledger consistency, partial payments, oldest-invoice payment
  allocation, credit limits, protected history, stock rollback and concurrent
  stock adjustments.
- Mocked Drive pagination, 429 retries, bounded failures and ambiguous upload
  recovery without creating a second upload.
- Salted PIN verification, persistent lockout and legacy PIN migration.

The calculator screenshot is rendered from the actual widget tree. The widget
harness substitutes the bundled Noto Sans fonts for Flutter test-only fonts;
phone system typography may differ slightly.

Drift emits a debug-only multiple-instance warning during restore tests because
staging uses a second AppDatabase. The staged database has its own executor and
file; it does not share the live QueryExecutor.

## Still requiring release validation

Google OAuth login and Drive round trips on a real account, biometric hardware,
installation/upgrade on a real Android phone, low-memory/low-disk operation,
process-kill recovery, and production traffic have not been tested here.

No one-million-user or one-million-concurrent-login load test was performed.
The app keeps records locally and uses optional Google Drive backups; it does
not include a shared account/database server. See PRODUCT_AND_RELIABILITY.md
for rollout limits and the difference between installations and concurrent
cloud traffic. A successful build does not certify production capacity.

## Android build attempt

The build progressed through Flutter/Gradle setup. The environment initially
provided only a Java runtime; a full JDK 17 was installed to resolve the missing
Java compiler. The next attempt identified plugin requirements for Android
platforms 34 and 35 in addition to platform 36. Installation was started, but
the execution environment reset before another complete build could run.

No installable APK or successful APK build is claimed. The build instructions
and GitHub workflow now include these SDK requirements. The Android build,
installation and upgrade still need verification in a persistent environment.
