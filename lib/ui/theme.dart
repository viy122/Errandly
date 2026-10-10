import 'package:flutter/material.dart';

import 'components.dart';

ThemeData errandlyTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: teal,
      primary: teal,
      onPrimary: Colors.white,
      secondary: teal,
      surface: Colors.white,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: line,
      outlineVariant: line,
    ),
  );
  final text = base.textTheme.apply(bodyColor: ink, displayColor: ink);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return base.copyWith(
    textTheme: text.copyWith(
      bodyMedium: text.bodyMedium!.copyWith(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: text.bodyLarge!.copyWith(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: text.titleMedium!.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge!.copyWith(fontWeight: FontWeight.w700),
    ),
    dividerColor: line,
    dividerTheme: const DividerThemeData(color: line, thickness: 1),
    iconTheme: const IconThemeData(color: ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: teal,
        foregroundColor: Colors.white,
        shape: buttonShape,
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        foregroundColor: ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: line),
        shape: buttonShape,
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: teal,
        shape: buttonShape,
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(16),
      labelStyle: const TextStyle(
        color: muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: const TextStyle(
        color: teal,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: muted,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      prefixIconColor: muted,
      suffixIconColor: muted,
      border: inputBorder(line),
      enabledBorder: inputBorder(const Color(0xFF889D92)),
      focusedBorder: inputBorder(teal, 2),
      errorBorder: inputBorder(base.colorScheme.error),
      focusedErrorBorder: inputBorder(base.colorScheme.error, 2),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: ink,
      checkmarkColor: Colors.white,
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      labelStyle: const TextStyle(
        color: ink,
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: Colors.white,
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w700,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      side: const BorderSide(color: muted, width: 1.3),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? teal : pale,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? teal : line,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: line),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      textStyle: const TextStyle(
        color: ink,
        fontFamily: 'Manrope',
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: line),
      ),
    ),
  );
}
