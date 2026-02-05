import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path/path.dart' as p;

class GoogleDriveService {
  static final _googleSignIn = GoogleSignIn.instance;

  static Future<String?> uploadAndGetLink(File file) async {
    try {
      // 1. Authenticate the user
      final GoogleSignInAccount? account = await _googleSignIn.authenticate();
      if (account == null) return null;

      // 2. Define the required scopes
      const scopes = [drive.DriveApi.driveFileScope];

      // 3. Obtain Authorization (New v7 Flow)
      // We request/check authorization for the specific scopes
      final auth = await account.authorizationClient.authorizeScopes(scopes);

      // 4. Get the authenticated HTTP client (New v3.0 extension method)
      // Note: the method is now 'authClient' and called on the authorization object
      final client = auth.authClient(scopes: scopes);

      var driveApi = drive.DriveApi(client);

      // 3. Define file metadata
      var driveFile = drive.File();
      driveFile.name = p.basename(file.path);
      driveFile.description = "Uploaded via PS4 Bot Tool";

      // 4. Perform the upload
      var media = drive.Media(file.openRead(), file.lengthSync());
      final result = await driveApi.files.create(driveFile, uploadMedia: media);
      
      final fileId = result.id;
      if (fileId == null) return null;

      // 5. Set Permission to "anyone with link"
      var permission = drive.Permission()
        ..type = "anyone"
        ..role = "reader";
      await driveApi.permissions.create(permission, fileId);

      // 6. Return the Direct Download Link for the bot
      return "https://drive.google.com/uc?export=download&id=$fileId";
    } catch (e) {
      debugPrint("GDrive Error: $e");
      return null;
    }
  }
}