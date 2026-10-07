import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'package:iris/app/theme/bevel_border.dart';
import 'package:iris/shared/theme/inverse_theme.dart';
import 'package:iris/shared/theme/over_video_theme.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// The voice of the interface: titles, text, tables and numbers.
const appFontFamily = 'Geist Mono';

/// Small chrome only: button labels, tooltips and snackbars, which read
/// faster in a proportional face and stay out of the content's way.
const appSansFamily = 'Geist';

/// Monochrome surfaces, square shapes and one signal colour.
///
/// The palette is ink and bone. [ColorScheme.tertiary] is the signal: it
/// marks what is live or in progress (watch and download progress, the
/// playing episode, an airing title) and nothing else, so it stays
/// meaningful. [ColorScheme.tertiaryFixed] is the same signal in both
/// themes, for marks drawn over video. Actions are monochrome: the primary
/// one is the inverted bone (or ink) button.
///
/// Each theme carries its opposite as an [InverseTheme] (built without a
/// twin of its own), and the light one also lends it to the player as its
/// [OverVideoTheme].
ThemeData buildAppTheme({
  Brightness brightness = Brightness.light,
  bool withTwin = true,
}) {
  final scheme = brightness == Brightness.dark ? _darkScheme : _lightScheme;
  final text = _textTheme(scheme);
  final dark = brightness == Brightness.dark;
  final twin = withTwin
      ? buildAppTheme(
          brightness: dark ? Brightness.light : Brightness.dark,
          withTwin: false,
        )
      : null;
  final bevel = BevelBorder(
    light: dark ? const Color(0xFFFFFFFF) : const Color(0xFF4D4D4B),
    dark: dark ? const Color(0xFF8E8B85) : const Color(0xFF000000),
  );

  const square = RoundedRectangleBorder();
  const buttonSize = Size(64, 44);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18);
  const buttonText = TextStyle(
    fontFamily: appSansFamily,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );
  const chromeText = TextStyle(
    fontFamily: appSansFamily,
    fontSize: 12,
    height: 1.35,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    splashFactory: NoSplash.splashFactory,
    hoverColor: scheme.onSurface.withValues(alpha: 0.06),
    focusColor: scheme.onSurface.withValues(alpha: 0.12),
    highlightColor: scheme.onSurface.withValues(alpha: 0.10),
    visualDensity: VisualDensity.standard,
    // Pages fade forward over the one before, a quiet move that suits the
    // flat surfaces; Apple platforms keep their native slide.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    extensions: [
      if (twin != null) InverseTheme(twin),
      if (twin != null && !dark) OverVideoTheme(twin),
    ],
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const PixelIcon(PixelGlyph.arrowLeft),
      closeButtonIconBuilder: (_) => const PixelIcon(PixelGlyph.close),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      titleTextStyle: text.titleLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        textStyle: const WidgetStatePropertyAll(buttonText),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.surfaceContainerHigh
              : scheme.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurfaceVariant
              : scheme.onPrimary,
        ),
        overlayColor: WidgetStatePropertyAll(
          scheme.onPrimary.withValues(alpha: 0.08),
        ),
        shape: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return square;
          return states.contains(WidgetState.pressed) ? bevel.pressed : bevel;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _flatButtonStyle(scheme, buttonText, buttonSize, buttonPadding),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        textStyle: const WidgetStatePropertyAll(buttonText),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurfaceVariant
              : scheme.onSurface,
        ),
        overlayColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: 0.08),
        ),
        shape: const WidgetStatePropertyAll(square),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.square(44)),
        shape: const WidgetStatePropertyAll(square),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
              : scheme.onSurface,
        ),
        overlayColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: bevel,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: text.bodySmall?.copyWith(color: scheme.onSurface),
      helperStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.onSurface),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.onSurface,
      selectionColor: scheme.onSurface.withValues(alpha: 0.24),
      selectionHandleColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: Border.all(color: scheme.outlineVariant),
    ),
    listTileTheme: ListTileThemeData(
      shape: square,
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
      subtitleTextStyle: text.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border.all(color: scheme.outline),
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: scheme.surfaceContainerLow,
      elevation: 0,
      modalElevation: 0,
      shape: Border(top: BorderSide(color: scheme.outline)),
      dragHandleColor: scheme.outline,
      dragHandleSize: const Size(32, 3),
    ),
    // Menus open in reverse, like the sheets and dialogs that carry the
    // inverse theme.
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.inverseSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      textStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      labelTextStyle: WidgetStatePropertyAll(
        text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(side: BorderSide(color: scheme.outline)),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: chromeText.copyWith(
        fontSize: 13,
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.onInverseSurface,
      elevation: 0,
      shape: square,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: scheme.inverseSurface),
      textStyle: chromeText.copyWith(color: scheme.onInverseSurface),
      waitDuration: const Duration(milliseconds: 400),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(side: BorderSide(color: scheme.outline)),
      labelStyle: text.labelMedium,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.onSurface,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: Colors.transparent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(4),
      radius: Radius.zero,
      thumbColor: WidgetStatePropertyAll(scheme.outline),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.tertiary,
      thumbColor: scheme.tertiary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onSurface
            : scheme.onSurfaceVariant,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(),
      side: BorderSide(color: scheme.onSurfaceVariant, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onSurface
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(scheme.surface),
    ),
  );
}

ButtonStyle _flatButtonStyle(
  ColorScheme scheme,
  TextStyle? textStyle,
  Size minimumSize,
  EdgeInsets padding,
) {
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(minimumSize),
    padding: WidgetStatePropertyAll(padding),
    textStyle: WidgetStatePropertyAll(textStyle),
    elevation: const WidgetStatePropertyAll(0),
    side: const WidgetStatePropertyAll(BorderSide.none),
    backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? scheme.onSurfaceVariant
          : scheme.onSurface,
    ),
    overlayColor: WidgetStatePropertyAll(
      scheme.onSurface.withValues(alpha: 0.08),
    ),
    shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
  );
}

/// Sizes are tuned for a monospaced face, whose glyphs run wider than a
/// proportional one: large type is set tight, small labels a little open.
///
/// The display styles are bases for [DisplayTitle], which sets the size
/// from the space it has; the scale jumps from them straight down to small
/// text, with little in between.
TextTheme _textTheme(ColorScheme scheme) {
  TextStyle style(
    double size,
    double height, {
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    Color? color,
  }) => TextStyle(
    fontFamily: appFontFamily,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color ?? scheme.onSurface,
  );

  final muted = scheme.onSurfaceVariant;
  return TextTheme(
    displayLarge: style(96, 1.02, spacing: -3.4),
    displayMedium: style(56, 1.02, spacing: -2),
    displaySmall: style(40, 1.05, spacing: -1.4),
    headlineLarge: style(30, 1.15, spacing: -0.8),
    headlineMedium: style(26, 1.15, spacing: -0.6),
    headlineSmall: style(22, 1.2, spacing: -0.4),
    titleLarge: style(18, 1.3, weight: FontWeight.w500, spacing: -0.2),
    titleMedium: style(15, 1.35, weight: FontWeight.w500),
    titleSmall: style(14, 1.35, weight: FontWeight.w500),
    bodyLarge: style(15, 1.6),
    bodyMedium: style(14, 1.5),
    bodySmall: style(12, 1.45, color: muted),
    labelLarge: style(14, 1.2, weight: FontWeight.w500),
    labelMedium: style(12, 1.3, weight: FontWeight.w500),
    labelSmall: style(11, 1.3, weight: FontWeight.w500, spacing: 0.8),
  );
}

const _signal = Color(0xFF76E838);
const _onSignal = Color(0xFF0E1A06);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFECEAE4),
  onPrimary: Color(0xFF141414),
  primaryContainer: Color(0xFF303030),
  onPrimaryContainer: Color(0xFFECEAE4),
  secondary: Color(0xFF9B9993),
  onSecondary: Color(0xFF141414),
  secondaryContainer: Color(0xFF262626),
  onSecondaryContainer: Color(0xFFECEAE4),
  tertiary: _signal,
  onTertiary: _onSignal,
  tertiaryContainer: Color(0xFF1F3312),
  onTertiaryContainer: Color(0xFFB9F59A),
  tertiaryFixed: _signal,
  onTertiaryFixed: _onSignal,
  error: Color(0xFFFF6B5E),
  onError: Color(0xFF141414),
  errorContainer: Color(0xFF3A1714),
  onErrorContainer: Color(0xFFFFB4AB),
  surface: Color(0xFF141414),
  onSurface: Color(0xFFECEAE4),
  onSurfaceVariant: Color(0xFF9B9993),
  surfaceDim: Color(0xFF101010),
  surfaceBright: Color(0xFF333333),
  surfaceContainerLowest: Color(0xFF0F0F0F),
  surfaceContainerLow: Color(0xFF191919),
  surfaceContainer: Color(0xFF1E1E1E),
  surfaceContainerHigh: Color(0xFF282828),
  surfaceContainerHighest: Color(0xFF333333),
  outline: Color(0xFF55534F),
  outlineVariant: Color(0xFF2C2C2B),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFECEAE4),
  onInverseSurface: Color(0xFF141414),
  inversePrimary: Color(0xFF141414),
  surfaceTint: Colors.transparent,
);

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF161616),
  onPrimary: Color(0xFFF1EDEB),
  primaryContainer: Color(0xFFDCD8D4),
  onPrimaryContainer: Color(0xFF161616),
  secondary: Color(0xFF5F5C58),
  onSecondary: Color(0xFFF1EDEB),
  secondaryContainer: Color(0xFFE2DEDA),
  onSecondaryContainer: Color(0xFF161616),
  tertiary: Color(0xFF2C8A0C),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFD6F2C4),
  onTertiaryContainer: Color(0xFF123C02),
  tertiaryFixed: _signal,
  onTertiaryFixed: _onSignal,
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
  surface: Color(0xFFF1EDEB),
  onSurface: Color(0xFF161616),
  onSurfaceVariant: Color(0xFF5F5C58),
  surfaceDim: Color(0xFFDDD9D5),
  surfaceBright: Color(0xFFFAF8F6),
  surfaceContainerLowest: Color(0xFFFAF8F6),
  surfaceContainerLow: Color(0xFFF6F3F1),
  surfaceContainer: Color(0xFFE8E4E1),
  surfaceContainerHigh: Color(0xFFE0DCD8),
  surfaceContainerHighest: Color(0xFFD5D1CD),
  outline: Color(0xFFA29E99),
  outlineVariant: Color(0xFFD3CFCB),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF161616),
  onInverseSurface: Color(0xFFF1EDEB),
  inversePrimary: Color(0xFFECEAE4),
  surfaceTint: Colors.transparent,
);
