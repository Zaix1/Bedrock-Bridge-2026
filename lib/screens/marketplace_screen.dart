import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/playfab_service.dart';
import '../services/key_database_service.dart';
import '../managers/market_manager.dart';

class MarketplaceScreen extends StatefulWidget {
  final String? currentAccountId;
  
  const MarketplaceScreen({super.key, this.currentAccountId});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _items = [];
  bool _isLoading = false;
  String _status = "Initializing..."; // Changed default status
  bool _isConnected = false; // Track connection state
  
  String? _targetPath;

  // Track download progress
  double? _downloadProgress; 
  String _downloadStatus = ""; 

  @override
  void initState() {
    super.initState();
    _initMarket(); // <--- NEW: Auto-connect on startup
  }

  // --- 1. AUTO-CONNECT & LOAD PATH ---
  Future<void> _initMarket() async {
    setState(() { _isLoading = true; _status = "Connecting to PlayFab..."; });
    
    // Load Path
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('target_path');
    
    // Attempt Login
    final success = await PlayFabService.login();

    if (mounted) {
      setState(() {
        _targetPath = path;
        _isConnected = success;
        _isLoading = false;
        _status = success 
            ? "Ready to search." 
            : "Connection failed. Check Internet.";
      });
    }
  }

  // --- 2. SEARCH LOGIC ---
  Future<void> _doSearch() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    
    // If not connected, try connecting first
    if (!_isConnected) {
      await _initMarket();
      if (!_isConnected) return; // Still failed
    }
    
    setState(() { _isLoading = true; _status = "Searching..."; });
    
    try {
      final results = await PlayFabService.search(_searchCtrl.text);
      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
          _status = results.isEmpty ? "No results found for '${_searchCtrl.text}'" : "";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _status = "Error: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER & SEARCH ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  SearchBar(
                    controller: _searchCtrl,
                    hintText: "Search Marketplace (e.g. 'City')",
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_isLoading) 
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      if (!_isLoading)
                        IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _doSearch),
                    ],
                    onSubmitted: (_) => _doSearch(),
                    elevation: WidgetStateProperty.all(2.0),
                    backgroundColor: WidgetStateProperty.all(cs.surfaceContainer),
                  ),
                  
                  // Status Text / Folder Warning
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          _targetPath == null ? Icons.folder_off : Icons.folder_shared, 
                          size: 14, 
                          color: _targetPath == null ? cs.error : cs.primary
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _targetPath == null 
                                ? "Auto-folder not set. Restart App or go to Settings." 
                                : "Saving to: .../${_targetPath!.split('/').last}",
                            style: TextStyle(
                              color: _targetPath == null ? cs.error : cs.onSurfaceVariant, 
                              fontSize: 11
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- RESULT GRID ---
            Expanded(
              child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isConnected ? Icons.storefront_rounded : Icons.wifi_off_rounded, 
                          size: 64, 
                          color: cs.secondary.withValues(alpha: 0.5)
                        ),
                        const SizedBox(height: 16),
                        Text(_status, style: TextStyle(color: cs.onSurfaceVariant)),
                        if (!_isConnected && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: FilledButton.tonal(
                              onPressed: _initMarket, 
                              child: const Text("Retry Connection")
                            ),
                          )
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, 
                      childAspectRatio: 0.75, 
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      return _buildProductCard(cs, item);
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ColorScheme cs, dynamic item) {
    final String name = item['Title']?['en-US'] ?? item['Title']?['NEUTRAL'] ?? item['DisplayName'] ?? "Unknown Pack";
    final String uuid = item['Id'] ?? item['ItemId'] ?? "";
    final String? imgUrl = _findImageUrl(item);
    final bool isUnlocked = KeyDatabaseService.hasKey(uuid);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: () => _showDetailsSheet(item, isUnlocked),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgUrl != null)
                    Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image))
                  else
                    Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.image_not_supported)),
                  
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnlocked ? Colors.green.withValues(alpha: 0.2) : cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isUnlocked ? Icons.key : Icons.lock, size: 12, color: isUnlocked ? Colors.green : cs.error),
                          const SizedBox(width: 4),
                          Text(
                            isUnlocked ? "KEY FOUND" : "LOCKED", 
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isUnlocked ? Colors.green : cs.error)
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(uuid, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsSheet(dynamic item, bool isUnlocked) {
    final cs = Theme.of(context).colorScheme;
    final String name = item['Title']?['en-US'] ?? item['Title']?['NEUTRAL'] ?? item['DisplayName'] ?? "Unknown";
    final String desc = item['Description']?['en-US'] ?? item['Description']?['NEUTRAL'] ?? item['Description'] ?? "No description available.";
    final String uuid = item['Id'] ?? item['ItemId'] ?? "";
    final String? imgUrl = _findImageUrl(item);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      builder: (ctx) => StatefulBuilder( // Use StatefulBuilder to update Sheet content (progress)
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(0),
                children: [
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: imgUrl != null ? Image.network(imgUrl, fit: BoxFit.cover) : Container(color: cs.surfaceContainerHighest),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SelectableText("UUID: $uuid", style: TextStyle(fontFamily: 'monospace', color: cs.primary)),
                        const SizedBox(height: 16),
                        Text(desc, style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 32),
                        
                        // --- ACTION BUTTON / PROGRESS BAR ---
                        if (_downloadProgress != null) ...[
                           // Downloading State
                           LinearProgressIndicator(value: _downloadProgress, borderRadius: BorderRadius.circular(4)),
                           const SizedBox(height: 8),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Text(_downloadStatus, style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                               Text("${(_downloadProgress! * 100).toInt()}%", style: TextStyle(color: cs.onSurfaceVariant)),
                             ],
                           ),
                        ] else ...[
                           // Idle State
                           SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton.icon(
                              onPressed: (isUnlocked && _targetPath != null) 
                                ? () {
                                    // Trigger download, and update THIS sheet's state
                                    _handleDownload(item, uuid, name, setSheetState);
                                  }
                                : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: isUnlocked ? cs.primary : cs.surfaceContainerHighest,
                                foregroundColor: isUnlocked ? cs.onPrimary : cs.outline,
                              ),
                              icon: Icon(isUnlocked ? Icons.download_rounded : Icons.lock_outline),
                              label: Text(
                                _targetPath == null 
                                  ? "Auto-Folder Not Set" 
                                  : (isUnlocked ? "Download & Inject" : "Missing Key"), 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }
          );
        }
      ),
    ).whenComplete(() {
      // Reset progress when sheet closes
      if (mounted) setState(() => _downloadProgress = null);
    });
  }

  // Updated to accept setSheetState so we can update the BottomSheet UI
  Future<void> _handleDownload(dynamic item, String uuid, String name, StateSetter setSheetState) async {
    if (_targetPath == null) return;

    setSheetState(() {
      _downloadProgress = 0.0;
      _downloadStatus = "Starting...";
    });

    final String? directDownloadUrl = PlayFabService.extractContentUrl(item);

    final result = await MarketManager.downloadAndInject(
      uuid, 
      name, 
      _targetPath!,
      directDownloadUrl: directDownloadUrl,
      onProgress: (p) {
        // Update the BottomSheet UI
        setSheetState(() {
          _downloadProgress = p;
          _downloadStatus = (p < 1.0) ? "Downloading..." : "Decrypting & Injecting...";
        });
      }
    );

    if (mounted) {
      Navigator.pop(context); // Close sheet
      _dialog(result.startsWith("Success") ? "Success" : "Error", result);
    }
  }

  void _dialog(String t, String b) => showDialog(
    context: context, 
    builder: (c) => AlertDialog(
      title: Text(t), 
      content: Text(b), 
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]
    )
  );

  String? _findImageUrl(dynamic item) {
    if (item['ItemImageUrl'] != null && item['ItemImageUrl'].toString().isNotEmpty) return item['ItemImageUrl'];
    if (item['Images'] != null && item['Images'] is List && item['Images'].isNotEmpty) {
      final dynamic thumb = (item['Images'] as List).cast<dynamic>().firstWhere(
        (img) => (img['Type'] ?? '').toString() == 'Thumbnail',
        orElse: () => item['Images'][0],
      );
      return thumb['Url'];
    }
    return null;
  }
}