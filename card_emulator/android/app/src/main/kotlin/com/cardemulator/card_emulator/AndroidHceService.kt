package com.cardemulator.card_emulator

import android.util.Log
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.content.Intent

class AndroidHceService : HostApduService() {
    companion object {
        var permanentApduResponses = false
        var listenOnlyConfiguredPorts = false

        var aid = byteArrayOf(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
        var cla: Byte = 0
        var ins: Byte = 0xA4.toByte()

        var portData = mutableMapOf<Int, ByteArray>()
        var tagId: ByteArray? = null // Add this variable to store the tag ID

        fun byteArrayToString(array: ByteArray): String {
            return array.joinToString(prefix = "[", postfix = " ]") { it.toUByte().toString(16) }
        }
    }

    private val SUCCESS = byteArrayOf(0x90.toByte(), 0x00)
    private val BAD_LENGTH = byteArrayOf(0x67, 0x00)
    private val UNKNOWN_CLA = byteArrayOf(0x6E, 0x00)
    private val UNKNOWN_INS = byteArrayOf(0x6D, 0x00)
    private val UNSUPPORTED_CHANNEL = byteArrayOf(0x68, 0x81.toByte())
    private val FAILURE = byteArrayOf(0x6F, 0x00)

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        Log.d("HCE", "APDU Command ${byteArrayToString(commandApdu)}")

        if (commandApdu[0] != cla) return UNKNOWN_CLA
        if (commandApdu[1] != ins) return UNKNOWN_INS

        val port: Int = commandApdu[3].toUByte().toInt()

        if (commandApdu[4].toInt() != aid.size) return BAD_LENGTH

        for (i in aid.indices) {
            if (commandApdu[i + 5] != aid[i]) return UNSUPPORTED_CHANNEL
        }

        val responseApdu = portData[port]

        if (!listenOnlyConfiguredPorts || responseApdu != null) {
            Intent().also { intent ->
                intent.action = "apduCommand"
                intent.putExtra("port", port)
                intent.putExtra("command", commandApdu.copyOfRange(0, aid.size + 5))
                intent.putExtra("data", commandApdu.copyOfRange(aid.size + 5, commandApdu.size))
                sendBroadcast(intent)
            }
        }

        // Handle the case when the response is null
        return if (responseApdu == null) {
            val responseWithTagId = (tagId ?: byteArrayOf()) + SUCCESS
            responseWithTagId
        } else {
            if (!permanentApduResponses) portData.remove(port)
            responseApdu + SUCCESS
        }
    }

    override fun onDeactivated(reason: Int) {}
}
