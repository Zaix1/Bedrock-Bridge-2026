import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../widgets/header.dart';
import '../widgets/action_tile.dart';
import '../services/io_service.dart';

class InjectorScreen extends StatefulWidget {
  final String? currentAccountId;

  const InjectorScreen({super.key, this.currentAccountId});

  @override
  State<InjectorScreen> createState() => _InjectorScreenState();
}

class _InjectorScreenState extends State<InjectorScreen> {
  String? _targetDir; 
  String? _modPath; 
  String? _sizeWarning; // Added to store the size warning text
  bool _isProcessing = false;

  Future<void> _pickTarget() async {
    final res = await FilePicker.platform.getDirectoryPath();
    if (res != null) {
      // --- SMART TARGET: AUTO-DETECT SAVEDATA0 ---
      final potentialSubDir = p.join(res, 'savedata0');
      if (Directory(potentialSubDir).existsSync()) {
        setState(() => _targetDir = potentialSubDir);
      } else {
        setState(() => _targetDir = res);
      }
    }
  }

  Future<void> _pickMod() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowCompression: false,
    );
    
    if (res != null && res.files.single.path != null) {
      final originalPath = res.files.single.path!;
      setState(() => _isProcessing = true);
      
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = p.basename(originalPath);
        final stagingPath = p.join(appDir.path, 'inj_staging_$fileName');
        
        final originalFile = File(originalPath);
        if (await originalFile.exists()) {
          await originalFile.copy(stagingPath);

          // --- FIXED: CALCULATE BOT SIZE WARNING ---
          final sizeStr = IoService.getBotSizeString(File(stagingPath));

          setState(() {
             _modPath = stagingPath;
             _sizeWarning = sizeStr;
          });
        } else {
          throw "Selected mod file is inaccessible.";
        }
      } catch (e) {
        if(mounted) _dialog("Error", "Failed to secure mod: $e");
      } finally {
        if(mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _runInject() async {
    if (_targetDir == null || _modPath == null) return;
    
    final stagedFile = File(_modPath!);
    if (!await stagedFile.exists()) {
      _dialog("Error", "Mod file missing. Please re-pick the mod.");
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      await IoService.runInject(_targetDir!, _modPath!);
      
      if (await stagedFile.exists()) await stagedFile.delete();
      setState(() {
        _modPath = null;
        _sizeWarning = null; // Clear warning on success
      });

      if(mounted) _showSuccessDialog();
    } catch (e) { 
      if(mounted) _dialog("Error", e.toString()); 
    } finally { 
      if(mounted) setState(() => _isProcessing = false); 
    }
  }

  // --- BOT COMMAND LOGIC ---
  void _copyBotCommand() {
    final id = widget.currentAccountId ?? "YOUR_ID";
    final command = "/raw_encrypt_folder account_id:$id save_files:LINK_HERE";
    
    Clipboard.setData(ClipboardData(text: command));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Command copied! Replace 'LINK_HERE' in Discord.")),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Success"),
        content: const Text("Mods Injected! Your world is ready for encryption."),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(c);
              _copyBotCommand();
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text("Copy Bot Command"),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Done")),
        ],
      ),
    );
  }

  void _dialog(String t, String b) => showDialog(
    context: context, 
    builder: (c) => AlertDialog(
      title: Text(t), 
      content: Text(b), 
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]
    )
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // --- FIXED: Append warning to subtitle ---
    String? modSubtitle;
    if (_modPath != null) {
      modSubtitle = p.basename(_modPath!);
      if (_sizeWarning != null) {
        modSubtitle = "$modSubtitle\n$_sizeWarning";
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Mod Injector")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Header(icon: Icons.bolt_rounded, title: "Mod Injector", subtitle: "Extract, Sort, Zip & Inject"),
          const SizedBox(height: 32),
          
          ActionTile(
            title: "Target World (savedata0)", 
            subtitle: _targetDir, 
            icon: Icons.public_rounded, 
            onTap: _pickTarget, 
            isDone: _targetDir != null
          ),
          
          ActionTile(
            title: "Mod File (.mcaddon, .mcpack, .zip)", 
            subtitle: modSubtitle, // Updated subtitle
            icon: Icons.extension_rounded, 
            onTap: _isProcessing ? () {} : () => _pickMod(), 
            isDone: _modPath != null
          ),
          
          const SizedBox(height: 32),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isProcessing 
              ? _buildStatusCard(cs)
              : SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: (_targetDir != null && _modPath != null) ? _runInject : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 4,
                      shadowColor: cs.primary.withValues(alpha: 0.4),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 28),
                    label: const Text("Inject Mod", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24, height: 24, 
                child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary)
              ),
              const SizedBox(width: 16),
              const Text("Injecting Mod...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              backgroundColor: cs.surfaceContainer,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text("Analyzing structure and zipping...", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}