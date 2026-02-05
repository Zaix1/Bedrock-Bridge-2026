import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PlayFabService {
  // --- CONFIG FROM PYTHON SCRIPT ---
  static const String _titleId = "20CA2"; 
  static const String _baseUrl = "https://20ca2.playfabapi.com";
  static const String _scid = "4fc10100-5f7a-4470-899b-280835760c07"; // Hardcoded in Python script
  
  // Auth Tokens
  static String? _entityToken;
  static String? _sessionTicket;
  
  // Error Tracking
  static String lastError = "Unknown Error";

  // --- 1. LOGIN (Matches Python: LoginWithCustomId -> Get EntityToken) ---
  static Future<bool> login() async {
    print("🔵 [PlayFab] Starting Login...");
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String? customId = prefs.getString('playfab_id');
      
      // Generate ID like Python: "MCPF" + Hex
      if (customId == null) {
        final randomHex = const Uuid().v4().replaceAll('-', '').substring(0, 16).toUpperCase();
        customId = "MCPF$randomHex";
        await prefs.setString('playfab_id', customId);
        print("🔵 [PlayFab] Generated New ID: $customId");
      }

      final uri = Uri.parse("$_baseUrl/Client/LoginWithCustomId");
      
      // Python Logic: Simpler approach for Mobile. 
      // We set CreateAccount: true to avoid the 1001 error loop without needing RSA.
      final body = jsonEncode({
        "TitleId": _titleId,
        "CustomId": customId,
        "CreateAccount": true,
        "InfoRequestParameters": {
          "GetUserAccountInfo": true,
        }
      });

      final headers = {
        "Content-Type": "application/json",
        "User-Agent": "libhttpclient/1.0.0.0", // Matches Python
        "Accept-Language": "en-US",
      };

      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          
          // 1. Get Session Ticket (For Client calls)
          _sessionTicket = data['data']['SessionTicket'];
          
          // 2. Get Entity Token (CRITICAL for Catalog Search)
          if (data['data']['EntityToken'] != null) {
             _entityToken = data['data']['EntityToken']['EntityToken'];
          } else {
             // Fallback: Sometimes EntityToken is not in Login response, request it manually
             return await _getEntityToken(); 
          }

          print("✅ [PlayFab] Login Success!");
          print("🔑 Entity Token: ${_entityToken?.substring(0, 5)}...");
          return true;
        }
      }
      
      lastError = "Login Failed: ${response.statusCode} - ${response.body}";
      print("❌ $lastError");
      return false;

    } catch (e) {
      lastError = "Connection Error: $e";
      print("❌ $lastError");
      return false;
    }
  }

  // Fallback to get EntityToken if Login didn't provide it
  static Future<bool> _getEntityToken() async {
    if (_sessionTicket == null) return false;
    
    final uri = Uri.parse("$_baseUrl/Authentication/GetEntityToken");
    final headers = {
      "Content-Type": "application/json",
      "X-Authorization": _sessionTicket! // Use SessionTicket to get EntityToken
    };
    
    try {
      final response = await http.post(uri, headers: headers, body: "{}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _entityToken = data['data']['EntityToken']['EntityToken'];
        return true;
      }
    } catch (e) {
      print("Failed to get EntityToken: $e");
    }
    return false;
  }

  // --- 2. SEARCH (Matches Python: /Catalog/Search) ---
  static Future<List<dynamic>> search(String query) async {
    // Ensure we have the EntityToken (Python uses X-EntityToken for Search)
    if (_entityToken == null) {
      if (!await login()) return [];
    }

    final uri = Uri.parse("$_baseUrl/Catalog/Search");
    
    // Construct Payload exactly like Python 'Search_name' function
    // Base Filter: (contentType eq 'MarketplaceDurableCatalog_V1.2')
    String filterQuery = "(contentType eq 'MarketplaceDurableCatalog_V1.2')"; 
    
    // If query is empty, just list newest. If query exists, add search term.
    String? searchQuery = query.trim().isNotEmpty ? "\"$query\"" : null;

    final body = jsonEncode({
      "count": true,
      "query": "", // Python sends empty query string here
      "filter": filterQuery,
      "orderBy": "creationDate DESC",
      "scid": _scid,
      "select": "contents,title,description,images,displayProperties,tags",
      "top": 20,
      "skip": 0,
      "search": searchQuery // The actual text search goes here
    });

    final headers = {
      "Content-Type": "application/json",
      "User-Agent": "libhttpclient/1.0.0.0",
      "X-EntityToken": _entityToken! // CRITICAL: Python uses X-EntityToken here
    };

    try {
      print("🔵 [PlayFab] Searching Catalog...");
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['Items'] != null) {
          final items = data['data']['Items'] as List;
          print("✅ [PlayFab] Found ${items.length} items.");
          return items;
        }
      } 
      
      lastError = "Search Error: ${response.statusCode}\n${response.body}";
      print("❌ $lastError");
      return [];

    } catch (e) {
      lastError = "Search Exception: $e";
      print("❌ $lastError");
      return [];
    }
  }

  /// Extract a direct content URL from a Catalog item (Python uses item["Contents"][..]["Url"]).
  static String? extractContentUrl(dynamic item) {
    if (item is! Map) return null;

    final dynamic contentsRaw = item['Contents'] ?? item['contents'];
    if (contentsRaw is! List || contentsRaw.isEmpty) return null;

    // Prefer non-skin binaries first; fallback to first URL.
    for (final entry in contentsRaw) {
      if (entry is! Map) continue;
      final String type = (entry['Type'] ?? entry['type'] ?? '').toString().toLowerCase();
      final String? url = (entry['Url'] ?? entry['url'])?.toString();
      if (url == null || url.isEmpty) continue;
      if (type != 'skinbinary' && type != 'personabinary') return url;
    }

    for (final entry in contentsRaw) {
      if (entry is! Map) continue;
      final String? url = (entry['Url'] ?? entry['url'])?.toString();
      if (url != null && url.isNotEmpty) return url;
    }

    return null;
  }

  // --- 3. GET DOWNLOAD URL ---
  static Future<String?> getDownloadUrl(String itemId) async {
    if (_sessionTicket == null) await login();

    final uri = Uri.parse("$_baseUrl/Client/GetContentDownloadUrl");
    final body = jsonEncode({
      "Key": itemId,
      "HttpMethod": "GET",
      "ThruCDN": true
    });

    final headers = {
      "Content-Type": "application/json",
      "User-Agent": "libhttpclient/1.0.0.0",
      "X-Authorization": _sessionTicket! // This API still needs SessionTicket
    };

    try {
      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['URL'] != null) {
          return data['data']['URL'];
        }
      }
      print("❌ Download URL Failed: ${response.body}");
    } catch (e) {
      print("❌ Download URL Error: $e");
    }
    return null;
  }
}
