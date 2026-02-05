import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:uuid/uuid.dart';
import '../models/mod_info.dart'; // Ensure this model has the ModType enum

class IoService {
  
  // --- BOT SIZE CALCULATOR ---
  static String getBotSizeString(File file) {
    if (!file.existsSync()) return "File not found";
    final int bytes = file.lengthSync();
    final double mb = bytes / (1024 * 1024);
    
    if (mb <= 25) return "25mb (can fail at apply cheats step)";
    if (mb <= 32) return "32mb (can fail at apply cheats step)";
    if (mb <= 64) return "64mb (can fail at apply cheats step)";
    if (mb <= 128) return "128mb (can fail at apply cheats step)";
    if (mb <= 256) return "256mb (can fail at apply cheats step)";
    if (mb <= 512) return "512mb (can fail at apply cheats step)";
    return "1GB (Safest)";
  }

  // --- VISUAL PACK MANAGER (INSPECTOR) ---
  // Now detects ModType (World vs Skin vs Resource)
  static Future<ModInfo> inspectMod(File zipFile) async {
    return await compute(_inspectWorker, zipFile.path);
  }

  static ModInfo _inspectWorker(String zipPath) {
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    
    String name = "Unknown Pack";
    String desc = "No description";
    String ver = "0.0.0";
    String uuid = "";
    Uint8List? icon;
    ModType type = ModType.unknown; // Default to unknown

    for (final file in archive) {
      // Normalize path separators
      final safeName = file.name.replaceAll('\\', '/');
      
      if (safeName.endsWith('manifest.json')) {
        try {
          final content = utf8.decode(file.content as List<int>);
          final json = jsonDecode(content);
          
          // 1. Read Header
          final header = json['header'];
          if (header != null) {
            name = header['name'] ?? name;
            desc = header['description'] ?? desc;
            uuid = header['uuid'] ?? uuid;
            final v = header['version'];
            if (v is List) ver = v.join('.');
          }

          // 2. DETECT TYPE (The Smart Part)
          // We look at 'modules' to see what kind of pack this is
          if (json['modules'] != null && json['modules'] is List) {
            for (var mod in json['modules']) {
              final t = mod['type'];
              if (t == 'world_template') type = ModType.world;
              else if (t == 'resources') type = ModType.resource;
              else if (t == 'data') type = ModType.behavior;
              else if (t == 'skin_pack') type = ModType.skin;
            }
          }
        } catch (e) {
          // ignore parsing errors
        }
      } else if (safeName.endsWith('pack_icon.png')) {
        // Read the image bytes directly into memory
        icon = Uint8List.fromList(file.content as List<int>);
      }
    }
    
    inputStream.close();
    
    return ModInfo(
      name: name,
      description: desc,
      version: ver,
      uuid: uuid,
      iconBytes: icon,
      type: type, // Return the detected type
    );
  }

  // --- UUID FIXER ---
  static Future<void> fixModUUIDs(File zipFile) async {
    await compute(_uuidFixerWorker, zipFile.path);
  }

  static void _uuidFixerWorker(String zipPath) {
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    final newArchive = Archive();
    final uuidGen = const Uuid();
    bool changed = false;

    for (final file in archive) {
      final safeName = file.name.replaceAll('\\', '/');

      if (safeName.endsWith('manifest.json')) {
        try {
          // Parse JSON
          final content = utf8.decode(file.content as List<int>);
          final json = jsonDecode(content);
          
          // Generate New UUIDs for header and modules
          if (json['header'] != null) {
            json['header']['uuid'] = uuidGen.v4();
          }
          if (json['modules'] != null && json['modules'] is List) {
            for (var mod in json['modules']) {
              mod['uuid'] = uuidGen.v4();
            }
          }

          // Write back the modified JSON
          final newContent = utf8.encode(jsonEncode(json));
          final newFile = ArchiveFile(file.name, newContent.length, newContent);
          newArchive.addFile(newFile);
          changed = true;
        } catch (e) {
          // If parsing fails, keep original file
          newArchive.addFile(file);
        }
      } else {
        // Keep other files (textures, sounds) exactly as they are
        newArchive.addFile(file);
      }
    }
    inputStream.close();

    // Overwrite the file ONLY if we actually changed something
    if (changed) {
      final outputStream = OutputFileStream(zipPath);
      final encoder = ZipEncoder();
      encoder.encode(newArchive, output: outputStream);
      outputStream.close();
    }
  }

  // --- REGION DATABASE ---
  static const Map<String, String> regions = {
    "Europe (EU)": "CUSA00265",
    "United States (US)": "CUSA00744",
    "Japan (JP)": "CUSA00283",
    "US Preview": "CUSA44267",
  };

  // --- PREP & INJECT LOGIC ---

  static Future<void> runPrep(String targetDir, String sourceZip) async {
    final safeSource = p.join(Directory.systemTemp.path, "temp_world_${DateTime.now().millisecondsSinceEpoch}.zip");
    await File(sourceZip).copy(safeSource);
    
    try {
      await compute(_prepWorker, {'target': targetDir, 'source': safeSource});
    } finally {
      final tempFile = File(safeSource);
      if (tempFile.existsSync()) tempFile.deleteSync();
    }
  }

  static Future<void> runInject(String targetDir, String modZip) async {
    // We copy the mod to temp to avoid locking the original file
    final safeMod = p.join(Directory.systemTemp.path, "temp_mod_${DateTime.now().millisecondsSinceEpoch}.zip");
    await File(modZip).copy(safeMod);

    try {
      await compute(_injectWorker, {'target': targetDir, 'mod': safeMod});
    } finally {
      final tempFile = File(safeMod);
      if (tempFile.existsSync()) tempFile.deleteSync();
    }
  }

  // --- WORKERS ---

  static Future<void> _prepWorker(Map<String, String> args) async {
    final target = Directory(args['target']!);
    final sceSys = Directory(p.join(target.path, 'sce_sys'));
    if (!sceSys.existsSync()) throw "ERROR: Not a valid PS4 Save folder (sce_sys missing).";

    // Clean existing files except sce_sys
    for (var entity in target.listSync()) {
      if (p.basename(entity.path) != 'sce_sys') {
        entity.deleteSync(recursive: true);
      }
    }

    final inputStream = InputFileStream(args['source']!);
    final archive = ZipDecoder().decodeBuffer(inputStream);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File(p.join(target.path, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory(p.join(target.path, filename)).createSync(recursive: true);
      }
    }
    inputStream.close();

    _zipPacksInDir(p.join(target.path, 'resource_packs'));
    _zipPacksInDir(p.join(target.path, 'behavior_packs'));
  }

  static Future<void> _injectWorker(Map<String, String> args) async {
    final target = Directory(args['target']!);
    final temp = Directory.systemTemp.createTempSync('work_');
    
    try {
      final inputStream = InputFileStream(args['mod']!);
      final archive = ZipDecoder().decodeBuffer(inputStream);
      
      for (final file in archive) {
        final path = p.join(temp.path, file.name);
        if (file.isFile) {
          File(path)..createSync(recursive: true)..writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(path).createSync(recursive: true);
        }
      }
      inputStream.close();

      List<Directory> packFolders = [];
      _findPackFolders(temp, packFolders);
      
      // If no sub-packs found, fallback to checking root manifest
      if (packFolders.isEmpty) {
        if (File(p.join(temp.path, 'manifest.json')).existsSync()) {
             packFolders.add(temp);
        } else {
             throw "Could not find valid manifest.json in the mod.";
        }
      }

      for (var pack in packFolders) {
        _processAndZip(pack, target.path);
      }
    } finally {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    }
  }

  // --- HELPERS ---

  static void _findPackFolders(Directory dir, List<Directory> results) {
    if (File(p.join(dir.path, 'manifest.json')).existsSync()) {
      results.add(dir);
      return;
    }
    for (var entity in dir.listSync()) {
      if (entity is Directory) _findPackFolders(entity, results);
    }
  }

  // --- FIXED: AUTO-SORTING LOGIC ---
  static void _processAndZip(Directory packDir, String targetRoot) {
    // Default destination: Resource Packs
    String subFolder = 'resource_packs';
    
    final manifestFile = File(p.join(packDir.path, 'manifest.json'));
    
    if (manifestFile.existsSync()) {
      try {
        final content = manifestFile.readAsStringSync();
        
        // --- SMART DETECTION ---
        // 1. Is it a Behavior Pack?
        if (content.contains('"type": "data"') || content.contains('"type":"data"')) {
          subFolder = 'behavior_packs';
        } 
        // 2. Is it a World Template? (The Bug Fix)
        else if (content.contains('"type": "world_template"') || content.contains('"type":"world_template"')) {
          subFolder = 'minecraftWorlds';
        }
        // 3. Is it a Skin Pack?
        else if (content.contains('"type": "skin_pack"') || content.contains('"type":"skin_pack"')) {
          subFolder = 'skin_packs';
        }
        // Default remains 'resource_packs'
      } catch (e) {
        // If read fails, stick to default
      }
    }

    // Create the correct destination folder (e.g. .../games/com.mojang/minecraftWorlds)
    final destParent = p.join(targetRoot, subFolder);
    Directory(destParent).createSync(recursive: true);

    // Name the file
    final zipName = "${p.basename(packDir.path)}.zip";
    
    // Create the Zip
    ZipFileEncoder()..create(p.join(destParent, zipName))..addDirectory(packDir)..close();
    
    // ignore: avoid_print
    print("✅ Packed ${p.basename(packDir.path)} into $subFolder");
  }

  static void _zipPacksInDir(String path) {
    final d = Directory(path);
    if (!d.existsSync()) return;
    for (var entity in d.listSync()) {
      if (entity is Directory) {
        ZipFileEncoder()..create('${entity.path}.zip')..addDirectory(entity)..close();
        entity.deleteSync(recursive: true);
      }
    }
  }
}