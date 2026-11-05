package io.github.wotworth.tennis.photos

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * PHO-22: Chris's Anthropic API key, encrypted with an AES key that never leaves the Android
 * Keystore. Never logged, never exported, never in the repository.
 */
class ApiKeyStore(context: Context, private val key: () -> SecretKey = ::keystoreKey) {
    private val sp = context.getSharedPreferences("secure", Context.MODE_PRIVATE)

    fun get(): String? = sp.getString(NAME, null)?.let { runCatching { decrypt(it) }.getOrNull() }
    fun set(apiKey: String) = sp.edit().putString(NAME, encrypt(apiKey.trim())).apply()
    fun clear() = sp.edit().remove(NAME).apply()
    /** Settings shows only this (PHO-22). */
    fun hint(): String? = get()?.takeLast(4)

    private fun encrypt(plain: String): String {
        val c = Cipher.getInstance(TRANSFORM).apply { init(Cipher.ENCRYPT_MODE, key()) }
        return Base64.encodeToString(c.iv + c.doFinal(plain.toByteArray()), Base64.NO_WRAP)
    }

    private fun decrypt(stored: String): String {
        val all = Base64.decode(stored, Base64.NO_WRAP)
        val c = Cipher.getInstance(TRANSFORM).apply { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, all, 0, 12)) }
        return String(c.doFinal(all, 12, all.size - 12))
    }

    companion object {
        private const val NAME = "anthropic_api_key"
        private const val ALIAS = "tennis-api-key"
        private const val TRANSFORM = "AES/GCM/NoPadding"

        fun keystoreKey(): SecretKey {
            val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
            val g = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            g.init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())
            return g.generateKey()
        }
    }
}
