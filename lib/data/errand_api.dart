import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/proof_image.dart';

import 'session_memory.dart' if (dart.library.js_interop) 'session_web.dart';

class ErrandApi {
  ErrandApi({required this.url, http.Client? client})
    : client = client ?? http.Client(),
      token = readSession();

  final String url;
  final http.Client client;
  String? token;

  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    try {
      final response = await client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'action': action, ...data}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Unexpected API response');
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && action == 'state') {
          token = null;
          saveSession(null);
        }
        throw StateError(body['error'] as String? ?? 'Could not save changes.');
      }
      if (body['token'] is String) {
        token = body['token'] as String;
        saveSession(token);
      }
      return body;
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError(
        'Cannot reach the database. Check that XAMPP Apache and MySQL are running, then try again.',
      );
    }
  }

  void clearSession() {
    token = null;
    saveSession(null);
  }

  Future<Map<String, dynamic>> upload(
    String action,
    Map<String, String> fields,
    Map<String, SelectedProof> files,
  ) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll({if (token != null) 'Authorization': 'Bearer $token'})
        ..fields.addAll({'action': action, ...fields});
      for (final entry in files.entries) {
        request.files.add(
          http.MultipartFile.fromBytes(
            entry.key,
            entry.value.bytes,
            filename: entry.value.name,
          ),
        );
      }
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 45)),
      ).timeout(const Duration(seconds: 45));
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Unexpected API response');
      }
      if (response.statusCode >= 400) {
        throw StateError(body['error'] as String? ?? 'Could not save proof.');
      }
      return body;
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError(
        'Upload failed. Check your connection, then try again. Your selected images are still here.',
      );
    }
  }

  Future<Uint8List> proofBytes(String id) async {
    try {
      final uri = Uri.parse(url)
          .replace(queryParameters: {'action': 'proofFile', 'id': id});
      final response = await client
          .get(
            uri,
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 400) {
        throw StateError(
          'Proof image unavailable. Refresh the errand or sign in again.',
        );
      }
      if (!(response.headers['content-type'] ?? '').startsWith('image/')) {
        throw StateError('Could not load the proof image.');
      }
      return response.bodyBytes;
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError(
        'Could not load the proof image. Check your connection and try again.',
      );
    }
  }

  void close() => client.close();
}
