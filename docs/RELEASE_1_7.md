# ShopHisab 1.7 release notes

## History

Find History / Previous in the Home plus/tools menu alongside Calculator and
Notepad. Browse 30-day date ranges or choose an end date. Daily totals show
invoice sales, gross credit postings and received money separately. Payments
linked to invoices are counted once in collections, on the payment date.
Rows without transactions are omitted. Open a day for all records, loaded 50
at a time. Open invoice records to see full invoice details.

History reflects current saved data, not an immutable audit log. Editing or
restoring records changes the report. Current invoice status is labelled as
such; it is not presented as that invoice's historical status on the selected
day. Inventory-only adjustments are not financial transactions in this report.

## Validation

Prices/amounts: non-negative decimal numbers, at most two decimal places;
positive values required for payments and ledger entries. Quantities: positive
for sales/adjustments, non-negative for stock, up to three decimal places.
Tax: 0–100%. Discounts cannot exceed subtotal; received amounts cannot exceed
invoice total. Optional credit limits may be blank; invalid text cannot clear
them. Required names cannot be blank. India phone numbers: ten digits, with
optional +91. International customer numbers require +country code, with an
8–15 digit structural limit. Format validation does not verify a phone number
or tax registration. Existing backup records are preserved without rewriting
phone numbers.

## Android windows and compatibility

The app supports system-managed split screen and resizable windows. On phones
that provide a pop-up/floating-window feature, select it from Android's Recent
apps menu. A help entry is included in Tools. This does not create an always-on-
top overlay or request permission to draw over other apps; devices without
floating windows can use split screen where Android exposes it.

Minimum Android API 24 (Android 7) is required by the current Flutter plugins;
compile/target API 36 is used. Android
13–17 are in the intended handset compatibility range. No max SDK or portrait
lock is imposed. Targeting API 36 does not itself prevent installation on newer
Android versions. Universal APKs contain the supported ARM32, ARM64 and x86_64
native libraries. Compatibility with every handset/ROM cannot be certified
without testing physical devices; Google sign-in also requires Google services.

Checks for this revision are recorded in VALIDATION_1_7.md. Prior 1.6 test logs
are historical and do not prove the new features passed.

Official compatibility references reviewed:
https://developer.android.com/develop/ui/views/layout/support-multi-window-mode
https://developer.android.com/about/versions/17/behavior-changes-all
https://developer.android.com/guide/practices/page-sizes

## 1.8.1 - History export

* History cards redesigned (colour-coded sales / credit / received).
* "Download PDF / Excel" button: choose any period (or This/Last financial year)
  and share a statement with a CA. PDF uses the embedded Noto Sans font so the
  rupee sign renders; Excel has Summary, Day-wise and Transactions sheets.
* New dependency: excel ^5.0.0.
