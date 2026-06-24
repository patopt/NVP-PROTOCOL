package com.nvp.node.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Fintech identity shared with the iOS app: deep teal surfaces + lime accent.
object Nvp {
    val accent = Color(0xFFC9F24E)      // lime — primary action
    val onAccent = Color(0xFF0E211B)
    val tealLight = Color(0xFF143A32)   // feature card (balance hero)
    val tealDark = Color(0xFF0B2A22)
    val onTeal = Color(0xFFE8F3EE)

    val bgLight = Color(0xFFF4F7F2); val bgDark = Color(0xFF0E1F1A)
    val cardLight = Color(0xFFFFFFFF); val cardDark = Color(0xFF14342B)
    val card2Light = Color(0xFFEDF2EC); val card2Dark = Color(0xFF1C4A3B)
    val textLight = Color(0xFF10231C); val textDark = Color(0xFFEAF3EE)
    val mutedLight = Color(0xFF5C7268); val mutedDark = Color(0xFF9DB8AC)
    val green = Color(0xFF12A05E); val red = Color(0xFFD64545)
}

// Convenience accessors that follow the active scheme.
val androidx.compose.material3.ColorScheme.muted: Color get() = onSurfaceVariant
val androidx.compose.material3.ColorScheme.card2: Color get() = surfaceVariant

private val LightScheme = lightColorScheme(
    primary = Nvp.accent, onPrimary = Nvp.onAccent,
    background = Nvp.bgLight, onBackground = Nvp.textLight,
    surface = Nvp.cardLight, onSurface = Nvp.textLight,
    surfaceVariant = Nvp.card2Light, onSurfaceVariant = Nvp.mutedLight,
    secondary = Nvp.tealLight, onSecondary = Nvp.onTeal,
    error = Nvp.red,
)
private val DarkScheme = darkColorScheme(
    primary = Nvp.accent, onPrimary = Nvp.onAccent,
    background = Nvp.bgDark, onBackground = Nvp.textDark,
    surface = Nvp.cardDark, onSurface = Nvp.textDark,
    surfaceVariant = Nvp.card2Dark, onSurfaceVariant = Nvp.mutedDark,
    secondary = Nvp.tealDark, onSecondary = Nvp.onTeal,
    error = Nvp.red,
)

@Composable
fun NvpTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (dark) DarkScheme else LightScheme,
        typography = Typography(),
        content = content,
    )
}
