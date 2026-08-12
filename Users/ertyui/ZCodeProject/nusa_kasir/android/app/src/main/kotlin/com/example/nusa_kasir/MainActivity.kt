package com.example.nusa_kasir

import android.Manifest
import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.os.Bundle
import android.provider.ContactsContract
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

// MUST use FlutterFragmentActivity for local_auth biometric prompt
// on Xiaomi/Redmi MIUI and Samsung OneUI devices.
// FlutterActivity does NOT provide the FragmentManager that
// BiometricPrompt (AndroidX) requires on these devices.
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.nusa_kasir/contacts"
    private val BT_CHANNEL = "com.nusa_kasir/bluetooth"
    private val INSTALL_CHANNEL = "com.nusa_kasir/installer"

    private var contactResult: MethodChannel.Result? = null
    private var btPendingResult: MethodChannel.Result? = null
    private var btSocket: BluetoothSocket? = null
    private var btOutputStream: OutputStream? = null

    // ── NFC foreground dispatch ──
    // nfc_manager's enableReaderMode() silently fails on MIUI/Xiaomi
    // and some Samsung devices. Foreground dispatch is the reliable
    // fallback: while our activity is resumed, all NFC intents come
    // to us (not DANA or other apps). nfc_manager's onTagDiscovered
    // stream receives them via the platform channel.
    private var nfcAdapter: NfcAdapter? = null
    private var nfcPendingIntent: PendingIntent? = null
    private var nfcIntentFilters: Array<IntentFilter>? = null
    private var nfcTechLists: Array<Array<String>>? = null

    companion object {
        private const val TAG = "NUSA"
        private const val REQUEST_CONTACTS_PERMISSION = 1002
        // Standard SPP UUID for thermal printers
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupNfc()
    }

    private fun setupNfc() {
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        if (nfcAdapter == null) return

        // PendingIntent that wraps our activity — when an NFC tag is
        // discovered, Android delivers it as a new intent to this activity.
        nfcPendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Intent filters: match ALL NFC tag types. TECH_DISCOVERED is the
        // broadest and catches everything; NDEF_DISCOVERED is higher priority
        // for NDEF-formatted tags (NTAG215).
        nfcIntentFilters = arrayOf(
            IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED),
            IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED),
            IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED),
        )

        // Tech lists: tell Android which tag technologies we support.
        // This is also declared in res/xml/nfc_tech_filter.xml for the
        // manifest intent filter.
        nfcTechLists = arrayOf(
            arrayOf("android.nfc.tech.NfcA", "android.nfc.tech.Ndef", "android.nfc.tech.NdefFormatable"),
            arrayOf("android.nfc.tech.MifareClassic", "android.nfc.tech.NfcA"),
            arrayOf("android.nfc.tech.NfcA"),
        )
    }

    override fun onResume() {
        super.onResume()
        // Enable foreground dispatch: while our activity is visible,
        // ALL NFC tag discoveries come to us instead of being dispatched
        // to other apps (DANA, etc.). This works alongside nfc_manager's
        // enableReaderMode() — reader mode takes priority when active,
        // foreground dispatch is the fallback.
        nfcAdapter?.enableForegroundDispatch(this, nfcPendingIntent, nfcIntentFilters, nfcTechLists)
    }

    override fun onPause() {
        super.onPause()
        // Disable foreground dispatch when we're not visible so other
        // NFC apps (Google Pay, etc.) can work normally.
        nfcAdapter?.disableForegroundDispatch(this)
    }

    // ── NFC: forward tag intents to the Flutter engine ──
    // When enableReaderMode() succeeds: tag → reader callback (nfc_manager handles it).
    // When enableReaderMode() fails: tag → foreground dispatch → this intent →
    //   onNewIntent → setIntent → nfc_manager's platform channel picks it up.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    @Deprecated("Required for Bluetooth enable — contact picker uses direct result.success")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        Log.d(TAG, "onActivityResult req=$requestCode res=$resultCode hasData=${data != null}")

        when (requestCode) {
            1001 -> { // Contact picker — direct result.success back to Dart
                try {
                    val pending = contactResult
                    contactResult = null
                    if (pending == null) {
                        Log.w(TAG, "Contact picker: no pending result (activity recreated?)")
                        return
                    }
                    if (resultCode != RESULT_OK || data == null || data.data == null) {
                        Log.d(TAG, "Contact picker: user cancelled or no data")
                        pending.success(null)
                        return
                    }
                    val uri = data.data!!
                    Log.d(TAG, "Contact picker: reading URI $uri")
                    val projection = arrayOf(
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                        ContactsContract.CommonDataKinds.Phone.NUMBER
                    )
                    val cursor = contentResolver.query(uri, projection, null, null, null)
                    if (cursor != null) {
                        cursor.use {
                            if (it.moveToFirst()) {
                                val name = it.getString(0) ?: ""
                                val phone = it.getString(1) ?: ""
                                Log.d(TAG, "Contact picker: SUCCESS name='$name' phone='$phone'")
                                pending.success(mapOf("name" to name, "phone" to phone))
                            } else {
                                Log.w(TAG, "Contact picker: cursor empty")
                                pending.success(null)
                            }
                        }
                    } else {
                        Log.w(TAG, "Contact picker: null cursor")
                        pending.success(null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Contact picker: error", e)
                    contactResult?.success(null)
                    contactResult = null
                }
            }
            2001 -> { // Bluetooth enable
                btPendingResult?.success(resultCode == RESULT_OK)
                btPendingResult = null
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CONTACTS_PERMISSION) {
            val pending = contactResult
            if (pending == null) {
                Log.w(TAG, "Contact permission: no pending result")
                return
            }
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "Contact permission: GRANTED — launching picker")
                launchContactPicker(pending)
            } else {
                Log.w(TAG, "Contact permission: DENIED")
                contactResult = null
                pending.success(null)
            }
        }
    }

    private fun launchContactPicker(result: MethodChannel.Result) {
        try {
            contactResult = result
            val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI).apply {
                type = ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE
            }
            startActivityForResult(intent, 1001)
            // Do NOT call result.success here — will be called in onActivityResult
        } catch (e: Exception) {
            Log.e(TAG, "pickContact: launch failed", e)
            contactResult = null
            result.error("PICK_FAILED", e.message, null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Bluetooth channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothEnabled" -> {
                    val adapter = BluetoothAdapter.getDefaultAdapter()
                    result.success(adapter?.isEnabled ?: false)
                }
                "requestBluetoothEnable" -> {
                    val adapter = BluetoothAdapter.getDefaultAdapter()
                    if (adapter == null) {
                        result.success(false)
                    } else if (!adapter.isEnabled) {
                        btPendingResult = result
                        val intent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                        startActivityForResult(intent, 2001)
                    } else {
                        result.success(true)
                    }
                }
                "openBluetoothSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = android.net.Uri.parse("package:$packageName")
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                // ── Native SPP: scan bonded + paired devices ──
                "scanDevices" -> {
                    try {
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        if (adapter == null || !adapter.isEnabled) {
                            result.success(emptyList<Map<String, String>>())
                            return@setMethodCallHandler
                        }
                        val devices = mutableListOf<Map<String, String>>()
                        // Bonded (paired) devices
                        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
                            == PackageManager.PERMISSION_GRANTED) {
                            for (d in adapter.bondedDevices) {
                                devices.add(mapOf(
                                    "name" to (d.name ?: "Printer"),
                                    "address" to (d.address ?: "")
                                ))
                            }
                        }
                        result.success(devices)
                    } catch (e: Exception) {
                        Log.e(TAG, "scanDevices error", e)
                        result.success(emptyList<Map<String, String>>())
                    }
                }
                // ── Native SPP: connect to device ──
                "connectDevice" -> {
                    val address = call.argument<String>("address") ?: ""
                    if (address.isNullOrEmpty()) {
                        result.error("INVALID_ADDRESS", "Address is empty", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            if (adapter == null || !adapter.isEnabled) {
                                runOnUiThread { result.error("BT_OFF", "Bluetooth is off", null) }
                                return@Thread
                            }
                            // Close existing connection
                            try { btSocket?.close() } catch (_: Exception) {}
                            btSocket = null
                            btOutputStream = null

                            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
                                != PackageManager.PERMISSION_GRANTED) {
                                runOnUiThread { result.error("NO_PERMISSION", "Bluetooth permission denied", null) }
                                return@Thread
                            }

                            val device: BluetoothDevice = adapter.getRemoteDevice(address)
                            btSocket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                            btSocket?.connect()
                            btOutputStream = btSocket?.outputStream
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            Log.e(TAG, "connectDevice error", e)
                            try { btSocket?.close() } catch (_: Exception) {}
                            btSocket = null
                            btOutputStream = null
                            runOnUiThread { result.error("CONNECT_FAILED", e.message, null) }
                        }
                    }.start()
                }
                // ── Native SPP: send raw bytes ──
                "sendBytes" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data == null || btOutputStream == null) {
                        result.error("NOT_CONNECTED", "No active connection", null)
                        return@setMethodCallHandler
                    }
                    try {
                        btOutputStream?.write(data)
                        btOutputStream?.flush()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "sendBytes error", e)
                        try { btSocket?.close() } catch (_: Exception) {}
                        btSocket = null
                        btOutputStream = null
                        result.error("SEND_FAILED", e.message, null)
                    }
                }
                // ── Native SPP: disconnect ──
                "disconnectDevice" -> {
                    try { btSocket?.close() } catch (_: Exception) {}
                    btSocket = null
                    btOutputStream = null
                    result.success(true)
                }
                "isConnected" -> {
                    result.success(btSocket?.isConnected ?: false)
                }
                else -> result.notImplemented()
            }
        }

        // ── Contact picker (one-way: native replies directly via result.success) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickContact" -> {
                    Log.d(TAG, "pickContact: launching contact picker")

                    // MIUI/Redmi blocks ACTION_PICK without runtime READ_CONTACTS.
                    // Check & request permission before launching the system picker.
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS)
                        != PackageManager.PERMISSION_GRANTED
                    ) {
                        Log.d(TAG, "pickContact: requesting READ_CONTACTS permission")
                        contactResult = result // hold result → reply in onRequestPermissionsResult
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_CONTACTS),
                            REQUEST_CONTACTS_PERMISSION
                        )
                    } else {
                        launchContactPicker(result)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── In-app APK installer ──
        // Launches the system package installer via ACTION_VIEW + FileProvider.
        // Authority is "${applicationId}.fileprovider" so it's correct for all
        // 8 variant apps automatically. Android will ask "install from this
        // source?" once, then install over the same debug signature.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "APK path empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK tidak ditemukan: $path", null)
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "installApk error", e)
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
