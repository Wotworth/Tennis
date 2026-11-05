package io.github.wotworth.tennis.photos

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.anthropic.client.okhttp.AnthropicOkHttpClient
import com.anthropic.core.JsonValue
import com.anthropic.errors.AnthropicServiceException
import com.anthropic.errors.RateLimitException
import com.anthropic.errors.UnauthorizedException
import com.anthropic.models.messages.Base64ImageSource
import com.anthropic.models.messages.ContentBlockParam
import com.anthropic.models.messages.JsonOutputFormat
import com.anthropic.models.messages.MessageCreateParams
import com.anthropic.models.messages.OutputConfig
import com.anthropic.models.messages.StopReason
import io.github.wotworth.tennis.data.StringSpec
import org.json.JSONObject
import java.time.Duration

/**
 * PHO-20, PHO-23: the one class that uses the network. It sends one package photo to the Claude
 * API (api.anthropic.com only, HTTPS) and asks for brand, model, gauge and material as JSON.
 */
object ClaudeReader {
    /** PHO-20 (Q9, Chris 5 Nov): Claude Sonnet 5.5. Tunable. */
    const val MODEL = "claude-sonnet-5-5"
    const val HOST = "https://api.anthropic.com"

    sealed interface Result {
        data class Read(val spec: StringSpec) : Result
        data class Failed(val message: String) : Result
    }

    /** PHO-21: a network Android has checked reaches the internet. */
    fun online(context: Context): Boolean {
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return false
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    val PROMPT = """
        This photo shows a tennis string package. Read it and give the string's brand, model name,
        gauge and material. Gauge: as printed (for example 16L or 17); if only a diameter is
        printed, convert it (1.25 mm is 16L, 1.30 mm is 16, 1.20 mm is 17). Material: one of
        polyester, co-poly, multifilament, synthetic gut, natural gut, Kevlar/aramid; infer it from
        the product name when it isn't printed. Use an empty string for anything you can't tell.
    """.trimIndent()

    private fun schema(): JsonOutputFormat.Schema {
        fun str() = mapOf("type" to "string")
        return JsonOutputFormat.Schema.builder()
            .putAdditionalProperty("type", JsonValue.from("object"))
            .putAdditionalProperty("properties", JsonValue.from(mapOf("brand" to str(), "model" to str(), "gauge" to str(), "material" to str())))
            .putAdditionalProperty("required", JsonValue.from(listOf("brand", "model", "gauge", "material")))
            .putAdditionalProperty("additionalProperties", JsonValue.from(false))
            .build()
    }

    /** Parses the model's JSON answer (unit-tested). */
    fun parse(json: String): StringSpec {
        val o = JSONObject(json)
        return StringSpec(o.optString("brand").trim(), o.optString("model").trim(), o.optString("gauge").trim(), o.optString("material").trim())
    }

    /** Sends [jpeg] (already downscaled, PHO-20). Blocking: call off the main thread. */
    fun read(apiKey: String, jpeg: ByteArray): Result {
        val client = AnthropicOkHttpClient.builder().apiKey(apiKey).baseUrl(HOST).timeout(Duration.ofSeconds(90)).maxRetries(2).build()
        return try {
            val params = MessageCreateParams.builder()
                .model(MODEL)
                .maxTokens(2000L)
                .outputConfig(OutputConfig.builder().effort(OutputConfig.Effort.LOW).format(JsonOutputFormat.builder().schema(schema()).build()).build())
                .addUserMessageOfContentBlockParams(listOf(
                    ContentBlockParam.ofImage(Base64ImageSource.builder().mediaType(Base64ImageSource.MediaType.IMAGE_JPEG)
                        .data(android.util.Base64.encodeToString(jpeg, android.util.Base64.NO_WRAP)).build()),
                    ContentBlockParam.ofText(PROMPT),
                ))
                .build()
            val m = client.messages().create(params)
            if (m.stopReason().orElse(null) == StopReason.REFUSAL) return Result.Failed("Claude couldn't read this photo.")
            val text = m.content().mapNotNull { it.text().orElse(null)?.text() }.joinToString("")
            Result.Read(parse(text))
        } catch (e: UnauthorizedException) {
            Result.Failed("The API key was refused. Check it in settings.")
        } catch (e: RateLimitException) {
            Result.Failed("Too many requests right now. Try again in a minute.")
        } catch (e: AnthropicServiceException) {
            Result.Failed("Claude's service had a problem (${e.statusCode()}). Try again later.")
        } catch (e: Exception) {
            Result.Failed("Couldn't reach Claude: ${e.message ?: e.javaClass.simpleName}")
        } finally {
            runCatching { client.close() }
        }
    }
}
