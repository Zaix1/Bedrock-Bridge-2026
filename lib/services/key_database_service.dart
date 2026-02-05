import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class KeyDatabaseService {
  // The main cache: UUID -> Decryption Key
  static final Map<String, String> _keyMap = {};
  
  // Use a reliable community list or your own raw Github URL.
  // Leaving this as a placeholder will result in "0 updates" but won't crash.
  static const String _updateUrl = "https://raw.githubusercontent.com/bedrock-dot-dev/packs/master/packs.json"; // Example Placeholder

  static bool _isInitialized = false;

  /// INITIALIZE
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Load the base keys (if the file exists)
      try {
        final String assetData = await rootBundle.loadString('assets/keys.tsv');
        _parseAndLoad(assetData);
      } catch (_) {
        print("⚠️ Warning: assets/keys.tsv not found. Skipping base keys.");
      }

      // 2. Check for updates in storage
      final directory = await getApplicationDocumentsDirectory();
      final File localFile = File('${directory.path}/keys_update.tsv');

      if (await localFile.exists()) {
        final String localData = await localFile.readAsString();
        _parseAndLoad(localData);
        print("✅ Loaded updated keys from storage.");
      }

      _isInitialized = true;
      print("✅ Key Database Initialized. Total Keys: ${_keyMap.length}");
    } catch (e) {
      print("❌ Critical KeyDB Error: $e");
      // Mark initialized anyway so we don't block the app
      _isInitialized = true;
    }
  }

  /// PARSER (Now with Normalization)
  static void _parseAndLoad(String content) {
    final List<String> lines = content.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('MarketUUID')) continue;

      final parts = line.split('\t');
      if (parts.length >= 4) {
        // Normalize IDs (remove dashes, lower case)
        final marketUuid = _normalize(parts[0]);
        final manifestUuid = _normalize(parts[1]);
        final key = parts[3].trim();

        if (key.length >= 32) {
          if (marketUuid.isNotEmpty) _keyMap[marketUuid] = key;
          if (manifestUuid.isNotEmpty) _keyMap[manifestUuid] = key;
        }
      }
    }
  }

  /// HELPER: strips dashes so matches always work
  static String _normalize(String input) {
    return input.replaceAll('-', '').trim().toLowerCase();
  }

  /// UPDATE KEYS
  static Future<int> checkForUpdates() async {
    try {
      print("🌐 Fetching keys from: $_updateUrl");
      final response = await http.get(Uri.parse(_updateUrl));
      
      if (response.statusCode == 200) {
        final content = response.body;
        
        final directory = await getApplicationDocumentsDirectory();
        final File localFile = File('${directory.path}/keys_update.tsv');
        await localFile.writeAsString(content);

        int oldCount = _keyMap.length;
        _parseAndLoad(content);
        int newCount = _keyMap.length;

        return newCount - oldCount;
      } else {
        print("⚠️ Update Server Error: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Connection Failed: $e");
    }
    return 0;
  }

  /// LOOKUP
  static String? getKey(String uuid) {
    return _keyMap[_normalize(uuid)];
  }

  /// CHECK
  static bool hasKey(String uuid) {
    return _keyMap.containsKey(_normalize(uuid));
  }
}