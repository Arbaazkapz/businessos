package com.businessos.businessos

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity (needed by local_auth) plus a tiny "contacts"
 * channel used by Customers > Import from contacts. Contacts are only read
 * after the user grants the READ_CONTACTS permission and never leave the phone.
 */
class MainActivity : FlutterFragmentActivity() {
    private val contactsPermissionCode = 4711
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "shophisab/contacts"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasContactsPermission())
                "requestPermission" -> requestContactsPermission(result)
                "getContacts" -> loadContacts(result)
                "openSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null)
                    )
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasContactsPermission(): Boolean =
        checkSelfPermission(android.Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestContactsPermission(result: MethodChannel.Result) {
        if (hasContactsPermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("busy", "A permission request is already open.", null)
            return
        }
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(android.Manifest.permission.READ_CONTACTS),
            contactsPermissionCode
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == contactsPermissionCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    /** Returns [{name, phone}] sorted by name. Runs off the main thread. */
    private fun loadContacts(result: MethodChannel.Result) {
        if (!hasContactsPermission()) {
            result.error("permission", "Contacts permission not granted.", null)
            return
        }
        Thread {
            try {
                val phones = HashMap<Long, String>()
                contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    arrayOf(
                        ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                        ContactsContract.CommonDataKinds.Phone.NUMBER
                    ),
                    null,
                    null,
                    null
                )?.use { c ->
                    val idCol = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
                    val numCol = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    while (c.moveToNext()) {
                        val id = c.getLong(idCol)
                        val number = c.getString(numCol) ?: ""
                        if (number.isNotBlank() && !phones.containsKey(id)) {
                            phones[id] = number
                        }
                    }
                }
                val list = ArrayList<Map<String, String>>()
                contentResolver.query(
                    ContactsContract.Contacts.CONTENT_URI,
                    arrayOf(
                        ContactsContract.Contacts._ID,
                        ContactsContract.Contacts.DISPLAY_NAME_PRIMARY
                    ),
                    null,
                    null,
                    ContactsContract.Contacts.DISPLAY_NAME_PRIMARY + " COLLATE NOCASE ASC"
                )?.use { c ->
                    val idCol = c.getColumnIndex(ContactsContract.Contacts._ID)
                    val nameCol = c.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME_PRIMARY)
                    while (c.moveToNext() && list.size < 20000) {
                        val name = (c.getString(nameCol) ?: "").trim()
                        if (name.isEmpty()) continue
                        list.add(
                            mapOf(
                                "name" to name,
                                "phone" to (phones[c.getLong(idCol)] ?: "")
                            )
                        )
                    }
                }
                runOnUiThread { result.success(list) }
            } catch (e: Exception) {
                runOnUiThread { result.error("failed", e.message, null) }
            }
        }.start()
    }
}
