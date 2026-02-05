import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../widgets/header.dart';
import '../widgets/action_tile.dart';
import '../services/io_service.dart';

class PrepScreen extends StatefulWidget {
  final String? currentAccountId; // Added to receive PSN ID

  const PrepScreen({super.key, this.currentAccountId});

  @override
  State<PrepScreen> createState() => _PrepScreenState();
}

class _PrepScreenState extends State<PrepScreen> {
  String? _targetDir; 
  String? _sourceZipPath; 
  String? _sizeWarning; // Added to store the size warning text
  bool _isProcessing = false;
  
  Future<void> _checkPerms() async {
    if (Platform.isAndroid && !await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _pickTarget() async {
    await _checkPerms();
    final res = await FilePicker.platform.getDirectoryPath();
    if (res != null) setState(() => _targetDir = res);
  }

  Future<void> _pickSource() async {
    await _checkPerms();
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
        final stagingPath = p.join(appDir.path, 'prep_staging_$fileName');
        
        final originalFile = File(originalPath);
        if (await originalFile.exists()) {
          await originalFile.copy(stagingPath);
          
          // --- FIXED: CALCULATE BOT SIZE WARNING ---
          final sizeStr = IoService.getBotSizeString(File(stagingPath));

          setState(() {
             _sourceZipPath = stagingPath;
             _sizeWarning = sizeStr;
          });
        } else {
          throw "Original file no longer accessible.";
        }
      } catch (e) {
        if(mounted) _dialog("Error", "Failed to secure file: $e");
      } finally {
        if(mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _runPrep() async {
    if (_targetDir == null || _sourceZipPath == null) return;
    
    final stagedFile = File(_sourceZipPath!);
    if (!await stagedFile.exists()) {
      _dialog("Error", "Staged file missing. Please re-pick the world file.");
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await IoService.runPrep(_targetDir!, _sourceZipPath!);
      
      if (await stagedFile.exists()) await stagedFile.delete();
      setState(() {
        _sourceZipPath = null;
        _sizeWarning = null; // Clear warning
      });

      if(mounted) _showSuccessDialog(); // Updated to success specific dialog
    } catch (e) { 
      if(mounted) _dialog("Error", e.toString()); 
    } finally { 
      if(mounted) setState(() => _isProcessing = false); 
    }
  }

  // --- BOT COMMAND LOGIC ---
  void _copyBotCommand() {
    final id = widget.currentAccountId ?? "YOUR_ID";
    // This builds the exact command you mentioned for the Discord bot
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
        content: const Text("World Prep Completed! Your folder is ready for the bot."),
        actions: [
          // New: Copy command button
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
    String? sourceSubtitle;
    if (_sourceZipPath != null) {
      sourceSubtitle = p.basename(_sourceZipPath!);
      if (_sizeWarning != null) {
        sourceSubtitle = "$sourceSubtitle\n$_sizeWarning";
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("World Prep")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Header(icon: Icons.cleaning_services_rounded, title: "Save Prep", subtitle: "Wipe data, Install world, Auto-Zip"),
          const SizedBox(height: 32),
          
          ActionTile(
            title: "Target Folder (savedata0)", 
            subtitle: _targetDir, 
            icon: Icons.folder_open_rounded, 
            onTap: _pickTarget, 
            isDone: _targetDir != null
          ),
          
          ActionTile(
            title: "Custom World Archive", 
            subtitle: sourceSubtitle, // Updated subtitle
            icon: Icons.public_rounded, 
            onTap: _isProcessing ? () {} : () => _pickSource(), 
            isDone: _sourceZipPath != null
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
                    onPressed: (_targetDir != null && _sourceZipPath != null) ? _runPrep : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text("Start Preparation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              const Text("Processing...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          Text("Wiping and extracting files...", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}