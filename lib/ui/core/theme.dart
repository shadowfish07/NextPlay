import 'package:flutter/material.dart';

class AppTheme {
  // Gaming-focused color constants
  static const Color _primarySeedColor = Color(0xFF2A48A0); // Rich gaming blue
  static const Color _accentColor = Color(0xFF6B73FF); // Electric blue accent
  static const Color _gameHighlight = Color(0xFF00D4FF); // Cyan highlight
  
  // Gaming dark surface colors
  static const Color _gamingSurface = Color(0xFF0F1419); // Deep charcoal background
  static const Color _gamingCard = Color(0xFF1A1F26); // Card background
  static const Color _gamingElevated = Color(0xFF252A32); // Elevated surfaces
  static const Color _gameMetaBackground = Color(0xFF1E2328); // Metadata backgrounds
  static const Color _gameTagBackground = Color(0xFF2A3441); // Genre tag backgrounds
  
  // Game status colors
  static const Color _statusPlaying = Color(0xFF4CAF50);
  static const Color _statusCompleted = Color(0xFF2196F3);
  static const Color _statusNotStarted = Color(0xFFFF9800);
  static const Color _statusAbandoned = Color(0xFFF44336);
  static const Color _statusPaused = Color(0xFFFF5722);
  static const Color _statusMultiplayer = Color(0xFF9C27B0);
  
  // Enhanced light theme for consistency
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primarySeedColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }

  // Premium gaming dark theme
  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeedColor,
      brightness: Brightness.dark,
      surface: _gamingSurface,
      onSurface: const Color(0xFFE8E8E8),
      surfaceContainer: _gamingCard,
      surfaceContainerHighest: _gamingElevated,
      primary: _accentColor,
      secondary: _gameHighlight,
      tertiary: const Color(0xFF9C27B0),
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _gamingSurface,
      
      // Enhanced AppBar for gaming aesthetic
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _gamingSurface,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: _accentColor.withValues(alpha: 0.1),
      ),
      
      // Gaming-style cards
      cardTheme: CardThemeData(
        elevation: 12,
        color: _gamingCard,
        shadowColor: _accentColor.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _gamingElevated.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      
      // Premium button styles
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 48),
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: _accentColor.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 48),
          foregroundColor: _gameHighlight,
          side: BorderSide(color: _gameHighlight, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Gaming-style chips
      chipTheme: ChipThemeData(
        backgroundColor: _gameTagBackground,
        selectedColor: _accentColor.withValues(alpha: 0.2),
        labelStyle: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        side: BorderSide(
          color: _gamingElevated.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      
      // Enhanced navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _gamingCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _accentColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: _accentColor, size: 28);
          }
          return IconThemeData(
            color: Colors.white.withValues(alpha: 0.6),
            size: 24,
          );
        }),
        elevation: 8,
        shadowColor: _accentColor.withValues(alpha: 0.05),
      ),
      
      // Enhanced list tile theme
      listTileTheme: ListTileThemeData(
        tileColor: _gamingCard,
        selectedTileColor: _accentColor.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Enhanced divider theme
      dividerTheme: DividerThemeData(
        color: _gamingElevated.withValues(alpha: 0.5),
        thickness: 0.5,
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _gameHighlight,
        linearTrackColor: _gameMetaBackground,
        circularTrackColor: _gameMetaBackground,
      ),
    );
  }
  
  // Gaming status colors (public accessors)
  static Color get statusPlaying => _statusPlaying;
  static Color get statusCompleted => _statusCompleted;
  static Color get statusNotStarted => _statusNotStarted;
  static Color get statusAbandoned => _statusAbandoned;
  static Color get statusPaused => _statusPaused;
  static Color get statusMultiplayer => _statusMultiplayer;
  
  // Gaming surface colors (public accessors)
  static Color get gamingSurface => _gamingSurface;
  static Color get gamingCard => _gamingCard;
  static Color get gamingElevated => _gamingElevated;
  static Color get gameMetaBackground => _gameMetaBackground;
  static Color get gameTagBackground => _gameTagBackground;
  static Color get accentColor => _accentColor;
  static Color get gameHighlight => _gameHighlight;
}