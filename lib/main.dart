import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(Ps4ToolApp(prefs: prefs));
}

class Ps4ToolApp extends StatefulWidget {
  final SharedPreferences prefs;
  const Ps4ToolApp({super.key, required this.prefs});
  
  @override
  State<Ps4ToolApp> createState() => _Ps4ToolAppState();
}

class _Ps4ToolAppState extends State<Ps4ToolApp> {
  late ThemeMode _themeMode;
  Color? _seedColor; 
  String? _accountId; // Added to store your PSN Account ID

  @override
  void initState() {
    super.initState();
    // Load saved settings
    final themeIndex = widget.prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    
    final colorVal = widget.prefs.getInt('seedColor');
    if (colorVal != null) _seedColor = Color(colorVal);

    // Load saved Account ID
    _accountId = widget.prefs.getString('accountId');
  }

  void changeTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    widget.prefs.setInt('themeMode', mode.index);
  }

  void changeColor(Color? color) {
    setState(() => _seedColor = color);
    if (color != null) {
      widget.prefs.setInt('seedColor', color.toARGB32());
    } else {
      widget.prefs.remove('seedColor');
    }
  }

  // Added: Update and save the PSN Account ID
  void changeAccountId(String id) {
    setState(() => _accountId = id);
    widget.prefs.setString('accountId', id);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightScheme, darkScheme;

        if (_seedColor != null) {
          lightScheme = ColorScheme.fromSeed(seedColor: _seedColor!, brightness: Brightness.light);
          darkScheme = ColorScheme.fromSeed(seedColor: _seedColor!, brightness: Brightness.dark);
        } else if (lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        } else {
          lightScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light);
          darkScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark);
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'PS4 Tool',
          themeMode: _themeMode,
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          home: MainScreen(
            currentMode: _themeMode,
            currentColor: _seedColor,
            currentAccountId: _accountId, // Passing Account ID to the UI
            onThemeChanged: changeTheme,
            onColorChanged: changeColor,
            onAccountIdChanged: changeAccountId, // Passing the update function
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(ColorScheme cs) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}