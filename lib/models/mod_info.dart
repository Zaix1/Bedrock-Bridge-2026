import 'dart:typed_data';

// 1. Define the Types
enum ModType { world, resource, behavior, skin, unknown }

class ModInfo {
  final String name;
  final String description;
  final String version;
  final Uint8List? iconBytes;
  final String uuid;
  final ModType type; // <--- NEW FIELD

  ModInfo({
    required this.name,
    required this.description,
    required this.version,
    this.iconBytes,
    required this.uuid,
    required this.type, // <--- Required
  });

  factory ModInfo.empty() {
    return ModInfo(
      name: "Unknown Mod",
      description: "No manifest.json found",
      version: "0.0.0",
      uuid: "unknown",
      iconBytes: null,
      type: ModType.unknown,
    );
  }
}