import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/playfab_service.dart';
import '../services/key_database_service.dart';
import '../services/decryption_service.dart';
import '../services/io_service.dart';
import '../models/mod_info.dart'; // REQUIRED: To see ModType

class MarketManager {

  /// DOWNLOAD & INSTALL FLOW
  /// 1. Check Key
  /// 2. Download (Streamed)
  /// 3. Decrypt
  /// 4. Inspect & Sort (World vs Skin vs Pack)
  /// 5. Save to Downloads Folder
  /// 6. Inject to Game
  static Future<String> downloadAndInject(
    String uuid, 
    String name, 
    String targetDir, 
    {Function(double)? onProgress}
  ) async {
    
    // 1. Check Key
    final String? key = KeyDatabaseService.getKey(uuid);
    if (key == null) return "Error: No key found for this content.";

    // 2. Get URL
    final String? url = await PlayFabService.getDownloadUrl(uuid);
    if (url == null) return "Error: Could not retrieve download URL.";

    try {
      // --- DOWNLOAD PHASE ---
      final Directory tempDir = await getTemporaryDirectory();
      final File encFile = File(p.join(tempDir.path, "${name}_enc.zip"));
      
      // ignore: avoid_print
      print("⬇️ Downloading $name...");

      final HttpClient client = HttpClient();
      final HttpClientRequest request = await client.getUrl(Uri.parse(url));
      final HttpClientResponse response = await request.close();

      final int totalBytes = response.contentLength;
      int receivedBytes = 0;
      final IOSink fileSink = encFile.openWrite();
      final Completer<void> completer = Completer<void>();

      response.listen(
        (List<int> chunk) {
          fileSink.add(chunk);
          receivedBytes += chunk.length;
          if (onProgress != null && totalBytes != -1) {
            onProgress(receivedBytes / totalBytes);
          }
        },
        onDone: () {
          fileSink.close();
          completer.complete();
        },
        onError: (e) {
          fileSink.close();
          completer.completeError(e);
        },
        cancelOnError: true,
      );
      await completer.future;

      // --- DECRYPT PHASE ---
      // ignore: avoid_print
      print("🔓 Decrypting...");
      if (onProgress != null) onProgress(1.0); // 100% Downloaded

      final File? decryptedFile = await DecryptionService.decryptPack(encFile, key);
      if (decryptedFile == null) return "Error: Decryption failed.";

      // --- INSPECT & SORT PHASE ---
      // ignore: avoid_print
      print("🔍 Analyzing Pack Type...");
      final ModInfo info = await IoService.inspectMod(decryptedFile);

      String subFolder = "Others";
      
      // Determine what kind of mod this is
      switch (info.type) {
        case ModType.world:
          subFolder = "Worlds";
          break;
        case ModType.skin:
          subFolder = "Skins";
          break;
        case ModType.resource:
          subFolder = "Texture_Packs";
          break;
        case ModType.behavior:
          subFolder = "Behavior_Packs";
          break;
        default:
          subFolder = "Unknown_Packs";
      }

      // --- SAVE TO DOWNLOADS PHASE ---
      // We save a backup copy to the user's public Download folder
      Directory? publicDownloadDir;
      if (Platform.isAndroid) {
        publicDownloadDir = Directory("/storage/emulated/0/Download");
      } else {
        publicDownloadDir = await getDownloadsDirectory();
      }

      if (publicDownloadDir != null) {
        final String organizedPath = p.join(publicDownloadDir.path, "Minecraft_Mods", subFolder);
        await Directory(organizedPath).create(recursive: true);

        final String safeName = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_'); // Sanitize filename
        final String backupPath = p.join(organizedPath, "$safeName.zip");
        
        // Copy the clean, decrypted zip there
        await decryptedFile.copy(backupPath);
        // ignore: avoid_print
        print("💾 Saved backup to: $backupPath");
      }

      // --- INJECT PHASE ---
      // ignore: avoid_print
      print("💉 Injecting into Game...");
      
      // Note: IoService.runInject handles standard packs well. 
      // For Worlds, we pass the targetDir. If targetDir is the root 'files' or 'savedata0',
      // IoService logic might need to be robust enough to handle it.
      // For now, we trust the existing logic you pasted.
      await IoService.runInject(targetDir, decryptedFile.path);

      // Cleanup
      if (encFile.existsSync()) encFile.deleteSync();
      if (decryptedFile.existsSync()) decryptedFile.deleteSync();

      return "Success! Saved to Download/Minecraft_Mods/$subFolder";

    } catch (e) {
      return "Error: $e";
    }
  }
}