import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/key_database_service.dart';

// I am keeping the import commented out in case you don't have the file.
// The code below now includes a built-in color picker so it works regardless.
// import '../widgets/color_picker_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentMode;
  final Color? currentColor;
  final String? currentAccountId;
  final Function(ThemeMode) onThemeChanged;
  final Function(Color?) onColorChanged;
  final Function(String) onAccountIdChanged;

  const SettingsScreen({
    super.key,
    required this.currentMode,
    required this.currentColor,
    required this.currentAccountId,
    required this.onThemeChanged,
    required this.onColorChanged,
    required this.onAccountIdChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _idController;
  String? _keyStatus; // Feedback for key updates

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.currentAccountId);
    _initAutoPath(); // <--- AUTOMATICALLY SETS "Bedrock Console" FOLDER
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  // --- AUTOMATIC FOLDER LOGIC ---
  Future<void> _initAutoPath() async {
    // Check permissions first
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }

    // Default to: /storage/emulated/0/Download/Bedrock Console
    final downloadDir = Directory('/storage/emulated/0/Download');
    final targetDir = Directory('${downloadDir.path}/Bedrock Console');

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    // Save this path automatically so IoService knows where to put files
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('target_path', targetDir.path);
    print("✅ Auto-set path to: ${targetDir.path}");
  }

  // --- KEY UPDATE LOGIC ---
  Future<void> _updateKeys() async {
    setState(() => _keyStatus = "Updating...");
    final count = await KeyDatabaseService.checkForUpdates();
    if (mounted) {
      setState(() => _keyStatus = count > 0 ? "Updated $count keys!" : "Keys are up to date.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_keyStatus!), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            const Text("Settings", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            
            // --- SECTION 1: ACCOUNT (Your Original Code) ---
            const Text("PSN Account", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      labelText: "Online ID (Account ID)",
                      hintText: "Enter your PSN ID",
                      prefixIcon: const Icon(Icons.person_outline),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          if (_idController.text.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: _idController.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("ID copied to clipboard")),
                            );
                          }
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onChanged: (val) => widget.onAccountIdChanged(val),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "This ID is used for the /raw_encrypt_folder command.",
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- SECTION 2: SYSTEM (Added for Keys) ---
            const Text("System", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ListTile(
                leading: const Icon(Icons.vpn_key),
                title: const Text("Update Decryption Keys"),
                subtitle: Text(_keyStatus ?? "Required for Marketplace downloads"),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _updateKeys,
                ),
                onTap: _updateKeys,
              ),
            ),

            const SizedBox(height: 32),

            // --- SECTION 3: APPEARANCE (Your Original Code) ---
            const Text("Appearance", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(widget.currentMode == ThemeMode.dark ? "Dark theme enabled" : "Light theme enabled"),
                    secondary: Icon(widget.currentMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
                    value: widget.currentMode == ThemeMode.dark,
                    onChanged: (bool isDark) {
                      widget.onThemeChanged(isDark ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                  Divider(height: 1, indent: 64, endIndent: 24, color: cs.outlineVariant),
                  ListTile(
                    title: const Text("Color Scheme", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_getColorName(widget.currentColor)),
                    leading: CircleAvatar(backgroundColor: widget.currentColor ?? cs.primary),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showColorPicker(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getColorName(Color? c) {
    if (c == null) return "Default (Dynamic)";
    final val = c.toARGB32();
    if (val == Colors.blue.toARGB32()) return "Blue";
    if (val == Colors.green.toARGB32()) return "Green";
    if (val == Colors.orange.toARGB32()) return "Orange";
    if (val == Colors.red.toARGB32()) return "Red";
    if (val == Colors.pink.toARGB32()) return "Pink";
    if (val == Colors.teal.toARGB32()) return "Teal";
    if (val == Colors.lime.toARGB32()) return "Lime";
    return "Custom";
  }

  // Built-in color picker to ensure it works without external files
  void _showColorPicker(BuildContext context) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.pink, Colors.teal, Colors.lime];
    
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Accent Color", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildColorOption(ctx, null, "Dynamic"), 
                ...colors.map((c) => _buildColorOption(ctx, c, "")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(BuildContext ctx, Color? c, String label) {
    final isSelected = widget.currentColor?.value == c?.value;
    return GestureDetector(
      onTap: () async {
        widget.onColorChanged(c);
        if (mounted) Navigator.pop(ctx);
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: c ?? Theme.of(ctx).colorScheme.surfaceContainerHighest,
            child: isSelected 
              ? const Icon(Icons.check, color: Colors.white) 
              : (c == null ? const Icon(Icons.auto_awesome) : null),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ]
        ],
      ),
    );
  }
}