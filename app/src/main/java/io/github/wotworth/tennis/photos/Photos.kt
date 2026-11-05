package io.github.wotworth.tennis.photos

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** PHO-01, PHO-02, PHO-10: package photos on disk, and reading their text on the phone. */
object Photos {
    const val AUTHORITY = "io.github.wotworth.tennis.files"

    fun dir(c: Context) = File(c.filesDir, "photos").apply { mkdirs() }
    fun file(c: Context, name: String) = File(dir(c), name)

    /** A new, empty photo file and the content URI the camera app writes to (PHO-01). */
    fun newCapture(c: Context): Pair<String, Uri> {
        val name = "pkg-${UUID.randomUUID()}.jpg"
        return name to FileProvider.getUriForFile(c, AUTHORITY, file(c, name))
    }

    /** Copies a picked image into the photo folder; its new file name. */
    suspend fun importPicked(c: Context, uri: Uri): String = withContext(Dispatchers.IO) {
        val name = "pkg-${UUID.randomUUID()}.jpg"
        c.contentResolver.openInputStream(uri)!!.use { input -> file(c, name).outputStream().use { input.copyTo(it) } }
        name
    }

    /** Decodes a photo at most [maxSide] px on its long side, the right way up. */
    fun decode(f: File, maxSide: Int): Bitmap? {
        if (!f.exists() || f.length() == 0L) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(f.path, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSide) sample *= 2
        val b = BitmapFactory.decodeFile(f.path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
        val rot = runCatching { ExifInterface(f.path).rotationDegrees }.getOrDefault(0)
        val scale = maxSide.toFloat() / maxOf(b.width, b.height)
        val m = Matrix().apply { if (scale < 1f) postScale(scale, scale); if (rot != 0) postRotate(rot.toFloat()) }
        return if (m.isIdentity) b else Bitmap.createBitmap(b, 0, 0, b.width, b.height, m, true)
    }

    /** PHO-20: the photo as a JPEG at most 1568 px on its long side. */
    fun forClaude(f: File, maxSide: Int = 1568): ByteArray? = decode(f, maxSide)?.let { b ->
        ByteArrayOutputStream().also { b.compress(Bitmap.CompressFormat.JPEG, 88, it) }.toByteArray()
    }

    /** PHO-10: ML Kit's bundled Latin text recognizer, offline. */
    suspend fun readText(c: Context, f: File): String = withContext(Dispatchers.Default) {
        val bmp = decode(f, 2048) ?: return@withContext ""
        val rec = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            suspendCancellableCoroutine { cont ->
                rec.process(InputImage.fromBitmap(bmp, 0))
                    .addOnSuccessListener { r ->
                        // Biggest text first: ML Kit's blocks, sorted by line height.
                        val lines = r.textBlocks.flatMap { it.lines }.sortedByDescending { it.boundingBox?.height() ?: 0 }.map { it.text }
                        cont.resume(lines.joinToString("\n"))
                    }
                    .addOnFailureListener { cont.resumeWithException(it) }
            }
        } finally { rec.close() }
    }
}
