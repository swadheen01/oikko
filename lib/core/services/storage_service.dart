import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_config.dart';

/// Handles file uploads: profile photos, dues receipts, PDF statements.
///
/// Backed by Supabase Storage rather than Firebase Storage — Firebase
/// Storage now requires the paid Blaze plan just to be enabled at all
/// (even usage within its free-tier limits), whereas Supabase's free tier
/// needs no card on file. Auth and Firestore stay on Firebase; only file
/// storage moved. See ADMIN_SETUP.md for the one-time bucket setup this
/// depends on.
///
/// Uploads take raw bytes (not a dart:io File) so the same call site works
/// on both Android and Flutter Web — pair with `XFile.readAsBytes()` from
/// image_picker at the call site.
class StorageService {
  StorageFileApi get _bucket => Supabase.instance.client.storage.from(SupabaseConfig.bucket);

  Future<String> uploadProfilePhoto({
    required String memberId,
    required Uint8List bytes,
  }) async {
    final path = 'profile_photos/$memberId.jpg';
    await _uploadWithUpsertFallback(
      path,
      bytes,
      const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    // Cache-bust: the path is stable per member, so without this the photo
    // widget's NetworkImage would keep showing a cached old photo after
    // a re-upload since the URL never changes.
    return '${_bucket.getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// `upsert: true` re-uploads rely on the Supabase `update` RLS policy on
  /// `storage.objects` (the object already exists on a second photo
  /// upload). If that policy is missing/misconfigured while the `insert`
  /// and `delete` policies are fine (a partial SQL-script run is an easy
  /// way to end up in exactly this state), the upsert fails with a 403
  /// even though the bucket is otherwise writable. Falling back to an
  /// explicit remove-then-insert only ever needs those two policies, so a
  /// re-upload still succeeds without the user having to fix Supabase SQL.
  Future<void> _uploadWithUpsertFallback(
    String path,
    Uint8List bytes,
    FileOptions fileOptions,
  ) async {
    try {
      await _bucket.uploadBinary(path, bytes, fileOptions: fileOptions);
    } on StorageException catch (e) {
      final isRlsFailure = e.statusCode == '403' ||
          e.message.toLowerCase().contains('row-level security');
      if (!isRlsFailure) rethrow;
      try {
        await _bucket.remove([path]);
      } catch (_) {
        // Nothing to remove yet, or delete also blocked — either way,
        // still worth attempting the plain insert below.
      }
      await _bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: fileOptions.contentType, upsert: false),
      );
    }
  }

  /// Committee member photo, keyed by the fixed slot id (c0..c4). Same
  /// cache-bust trick as profile photos, since the path is stable per slot.
  Future<String> uploadCommitteePhoto({
    required String slotId,
    required Uint8List bytes,
  }) async {
    final path = 'committee_photos/$slotId.jpg';
    await _uploadWithUpsertFallback(
      path,
      bytes,
      const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    return '${_bucket.getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadReceipt({
    required String transactionId,
    required Uint8List bytes,
  }) async {
    final path = 'receipts/$transactionId.pdf';
    await _uploadWithUpsertFallback(
      path,
      bytes,
      const FileOptions(contentType: 'application/pdf', upsert: true),
    );
    return _bucket.getPublicUrl(path);
  }

  Future<void> deleteFile(String downloadUrl) async {
    final marker = '/public/${SupabaseConfig.bucket}/';
    final index = downloadUrl.indexOf(marker);
    if (index == -1) return;
    final pathWithQuery = downloadUrl.substring(index + marker.length);
    final path = pathWithQuery.split('?').first;
    await _bucket.remove([path]);
  }
}
