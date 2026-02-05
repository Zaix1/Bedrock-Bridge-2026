import 'dart:io';
import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

// DEPENDENCY: Make sure 'pointycastle: ^3.7.3' is in your pubspec.yaml
import 'package:pointycastle/export.dart'; 

class DecryptionService {
  
  // Magic Header for Minecraft Encrypted Content
  static const int _magicHeader = 0x9BCFB9FC;

  // --- PUBLIC API ---
  static Future<File?> decryptPack(File encryptedFile, String keyString) async {
    return await compute(_decryptWorker, {
      'path': encryptedFile.path,
      'key': keyString,
    });
  }

  // --- ISOLATE WORKER ---
  static Future<File?> _decryptWorker(Map<String, String> args) async {
    final File inFile = File(args['path']!);
    final String keyStr = args['key']!;
    
    // 1. Read the file
    final RandomAccessFile raf = await inFile.open(mode: FileMode.read);
    final int length = await raf.length();
    
    try {
      // 2. Validate Header (First 4 bytes must match Magic)
      raf.setPositionSync(4);
      final Uint8List magicBytes = await raf.read(4);
      final ByteData magicData = ByteData.sublistView(magicBytes);
      final int fileMagic = magicData.getUint32(0, Endian.little); 

      if (fileMagic != _magicHeader) {
        // ignore: avoid_print
        print("❌ Invalid Magic Header: ${fileMagic.toRadixString(16)}");
      }

      // 3. Setup Decryption (AES-256-CFB)
      const int contentOffset = 0x100;
      if (length <= contentOffset) throw "File too small";

      final int payloadSize = length - contentOffset;
      raf.setPositionSync(contentOffset);
      
      // Read the ENTIRE Encrypted Payload
      final Uint8List encryptedData = await raf.read(payloadSize);

      // Setup Key & IV
      final Uint8List keyBytes = Uint8List.fromList(keyStr.codeUnits);
      final Uint8List ivBytes = keyBytes.sublist(0, 16);

      // --- CIPHER SETUP ---
      // AES block size is 16 bytes. CFB mode adapts it.
      final cipher = CFBBlockCipher(AESEngine(), 16); 
      
      final params = ParametersWithIV(KeyParameter(keyBytes), ivBytes);
      
      cipher.init(false, params); // false = Decrypt

      // 4. Perform Decryption
      final Uint8List decryptedData = cipher.process(encryptedData);

      // 5. Save Decrypted File
      final String dir = p.dirname(inFile.path);
      final String filename = p.basenameWithoutExtension(inFile.path);
      final File outFile = File(p.join(dir, "${filename}_decrypted.zip"));
      
      await outFile.writeAsBytes(decryptedData);
      
      return outFile;

    } catch (e) {
      // ignore: avoid_print
      print("❌ Decryption Failed: $e");
      return null;
    } finally {
      await raf.close();
    }
  }
}