// Night theme (same colors as the iPhone app and web/styles.css) and the moon icons per bucket.
package nl.moonlight.measure

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object C {
    val bg = Color(0xFF1D1947)
    val surface = Color(0xFF2B2566)
    val surface2 = Color(0xFF3C3489)
    val text1 = Color(0xFFEEEDFE)
    val text2 = Color(0xFFAFA9EC)
    val moon = Color(0xFFFAC775)
    val moonDark = Color(0xFF534AB7)
    val accent = Color(0xFF5DCAA5)
    val warn = Color(0xFFEF9F27)
}

@Composable
fun MoonlightTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = C.moon, onPrimary = C.bg, background = C.bg, onBackground = C.text1,
            surface = C.bg, onSurface = C.text1, surfaceVariant = C.surface, onSurfaceVariant = C.text2,
            secondaryContainer = C.surface2, onSecondaryContainer = C.text1, surfaceContainer = C.surface,
        ),
        content = content,
    )
}

/** The moon for a night's bucket: full, three crescents, dark, missing (?) or future (dashed). */
@Composable
fun Moon(bucket: Bucket, size: Dp = 24.dp, modifier: Modifier = Modifier) {
    val label = if (bucket == Bucket.future) t("history.future") else t("bucket.${bucket.name}")
    Box(modifier.size(size).semantics { contentDescription = label }, contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(size).graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)) {
            val r = (this.size.minDimension - 2.dp.toPx()) / 2
            val shadow = when (bucket) {
                Bucket.light -> 0.75f
                Bucket.medium -> 0.45f
                Bucket.heavy -> 0.22f
                else -> null
            }
            when (bucket) {
                Bucket.free -> drawCircle(C.moon, r)
                Bucket.light, Bucket.medium, Bucket.heavy -> {
                    val dx = shadow!! * this.size.width
                    drawCircle(C.moon, r)
                    drawCircle(Color.Black, r, center + Offset(dx, -dx * 0.25f), blendMode = BlendMode.Clear)
                }
                Bucket.very_heavy -> drawCircle(C.moonDark, r)
                Bucket.missing -> drawCircle(C.text2, r, style = Stroke(1.dp.toPx()))
                Bucket.future -> drawCircle(C.moonDark, r, style = Stroke(1.dp.toPx(),
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 2.dp.toPx()))))
            }
        }
        if (bucket == Bucket.missing) Text("?", color = C.text2, fontSize = (size.value * 0.5f).sp)
    }
}

@Composable
fun Card(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth().background(C.surface, RoundedCornerShape(16.dp)).padding(16.dp),
        content = content,
    )
}

@Composable
fun PrimaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(containerColor = C.moon, contentColor = C.bg,
            disabledContainerColor = C.moon.copy(alpha = 0.4f), disabledContentColor = C.bg),
    ) { Text(text, fontWeight = FontWeight.SemiBold, fontSize = 17.sp) }
}

@Composable
fun SecondaryButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = modifier.fillMaxWidth()) { Text(text, color = C.moon, fontSize = 16.sp) }
}

@Composable
fun Title(text: String) = Text(text, color = C.text1, fontSize = 30.sp, fontWeight = FontWeight.Bold, lineHeight = 36.sp)

@Composable
fun Muted(text: String, size: Int = 15) = Text(text, color = C.text2, fontSize = size.sp, lineHeight = (size + 6).sp)

object Fmt {
    fun nights(n: Int) = if (n == 1) t("today.night1") else t("today.nights", mapOf("n" to n))
    fun minutes(m: Double) = if (m == Math.rint(m)) m.toInt().toString() else "%.1f".format(m)
}
