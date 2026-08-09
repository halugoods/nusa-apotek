package com.example.nusa_kasir

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.os.Bundle
import android.provider.ContactsContract
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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

    private var contactResult: MethodChannel.Result? = null
    private var btPendingResult: MethodChannel.Result? = null
    private var btSocket: BluetoothSocket? = null
    private var btOutputStream: OutputStream? = null

    companion object {
        private const val TAG = "NUSA"
        private const val REQUEST_CONTACTS_PERMISSION = 1002
        // Standard SPP UUID for thermal printers
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    // ── NFC: forward tag intents to Flutter engine ──
    // When the user already has a card near the phone before enableReaderMode()
    // engages, Android delivers the tag as an intent instead of the reader callback.
    // Without onNewIntent, the intent gets dispatched to DANA or other NFC apps.
    // With onNewIntent + intent filters, our activity captures it and nfc_manager
    // can process it through its internal platform channel.
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
    }
}
