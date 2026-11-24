import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database_helper.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://avhkkfessvtwoisiioei.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2aGtrZmVzc3Z0d29pc2lpb2VpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUwMTMxMTEsImV4cCI6MjExMDU4OTExMX0.JeppTjaiKVvLE3f20rmlO09OlhrUgcKEu86g4XwaArg',
);

final ValueNotifier<bool> rubberwayAuthenticated = ValueNotifier<bool>(false);

class SupabaseAuthService {
  SupabaseAuthService._();

  static const _accessTokenKey = 'rubberway.auth.access_token';
  static const _refreshTokenKey = 'rubberway.auth.refresh_token';
  static const _expiresAtKey = 'rubberway.auth.expires_at';
  static const _emailKey = 'rubberway.auth.email';
  static const _agentNameKey = 'rubberway.auth.agent_name';
  static String? producerSyncMessage;

  static Future<String?> get savedAgentName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_agentNameKey);
  }

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

  static Future<bool> restoreSession() async {
    if (!isConfigured) return false;
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    final refreshToken = prefs.getString(_refreshTokenKey);
    if (accessToken == null || refreshToken == null) return false;

    final expiresAt = prefs.getInt(_expiresAtKey) ?? 0;
    if (expiresAt > DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60) {
      await _trySyncSectionProducers(accessToken);
      return true;
    }

    try {
      await _refreshSession(refreshToken, prefs);
      final refreshedToken = prefs.getString(_accessTokenKey);
      if (refreshedToken != null) await _trySyncSectionProducers(refreshedToken);
      return true;
    } on AuthException {
      await _clearSession(prefs);
      return false;
    } on HttpException {
      // Keep the locally saved session available for offline field work. A
      // rejected refresh token is different from a network/server failure.
      return true;
    } on SocketException {
      return true;
    } on TimeoutException {
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    if (!isConfigured) {
      throw const AuthException(
        'Configuration Supabase manquante. Ajoutez SUPABASE_URL et la clé publique SUPABASE_ANON_KEY à la compilation.',
      );
    }

    final session = await _request(
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
      body: {'email': _authEmailForIdentifier(identifier), 'password': password},
    );
    final accessToken = session['access_token'] as String?;
    final refreshToken = session['refresh_token'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw const AuthException('Supabase n’a pas renvoyé de session valide.');
    }
    await _saveSession(session);
    await _trySyncSectionProducers(accessToken);
  }

  static Future<void> _trySyncSectionProducers(String accessToken) async {
    try {
      final user = await _get(Uri.parse('$supabaseUrl/auth/v1/user'), accessToken: accessToken) as Map<String, dynamic>;
      final userId = user['id']?.toString();
      if (userId == null || userId.isEmpty) {
        throw const AuthException('Session Supabase invalide.');
      }
      final profileResponse = await _get(
        Uri.parse('$supabaseUrl/rest/v1/user_profiles?user_id=eq.$userId&select=section_name,villages&limit=1'),
        accessToken: accessToken,
      );
      final profiles = profileResponse as List<dynamic>;
      if (profiles.isEmpty) {
        throw const AuthException('Profil agent introuvable dans Supabase. Faites vérifier le compte sur la plateforme.');
      }
      final profile = profiles.first as Map<String, dynamic>;
      final villages = (profile['villages'] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rubberway.agent.section.name', (profile['section_name'] ?? '').toString());
      await prefs.setStringList('rubberway.agent.section.villages', villages);
      if (villages.isEmpty) {
        producerSyncMessage = 'Aucun village attribué à ce compte. Faites vérifier sa section sur la plateforme.';
        return;
      }

      final allProducers = <Map<String, dynamic>>[];
      var offset = 0;
      const pageSize = 1000;
      while (true) {
        final rows = await _get(
          Uri.parse('$supabaseUrl/rest/v1/producteurs?select=code_phi,nom,contact,village&order=code_phi.asc'),
          accessToken: accessToken,
          rangeStart: offset,
          rangeEnd: offset + pageSize - 1,
        ) as List<dynamic>;
        allProducers.addAll(rows.cast<Map<String, dynamic>>());
        if (rows.length < pageSize) break;
        offset += pageSize;
      }
      await DatabaseHelper.cacheAssignedProducers(allProducers);
      await prefs.setInt(
        'rubberway.agent.producers.synced_at',
        DateTime.now().millisecondsSinceEpoch,
      );
      producerSyncMessage = allProducers.isEmpty
          ? 'Supabase répond, mais ne renvoie aucun producteur pour les villages attribués. Faites vérifier leur synchronisation sur la plateforme.'
          : '${allProducers.length} producteur(s) reçu(s) de Supabase.';
    } catch (error) {
      // La liste déjà mise en cache reste utilisable sans réseau.
      debugPrint('Synchronisation des planteurs de la section ignorée : $error');
      producerSyncMessage = error is AuthException
          ? error.message
          : 'Synchronisation indisponible. Vérifiez votre connexion Internet et réessayez.';
    }
  }

  static Future<void> refreshSectionProducers() async {
    producerSyncMessage = null;
    final connected = await restoreSession();
    producerSyncMessage ??= connected
        ? 'Supabase est indisponible. Vérifiez votre connexion Internet et réessayez.'
        : 'Reconnectez-vous à votre compte RubberWay pour synchroniser les producteurs.';
  }

  static Future<dynamic> _get(Uri uri, {required String accessToken, int? rangeStart, int? rangeEnd}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.set('apikey', supabaseAnonKey);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      if (rangeStart != null && rangeEnd != null) request.headers.set('Range', '$rangeStart-$rangeEnd');
      final response = await request.close().timeout(const Duration(seconds: 30));
      final text = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final resource = uri.pathSegments.last;
        final label = resource == 'producteurs' ? 'des producteurs' : 'du profil agent';
        throw AuthException('Lecture $label dans Supabase impossible (HTTP ${response.statusCode}).');
      }
      return text.isEmpty ? <dynamic>[] : jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }

  static String _authEmailForIdentifier(String identifier) {
    final value = identifier.trim();
    if (value.contains('@')) return value.toLowerCase();
    final encoded = base64Url
        .encode(utf8.encode(value.toLowerCase()))
        .replaceAll('=', '');
    return 'agent.$encoded@agents.rubberway.invalid';
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);
    await _clearSession(prefs);
    if (isConfigured && token != null) {
      unawaited(_revokeSession(token));
    }
  }

  static Future<void> _revokeSession(String token) async {
    try {
      await _request(
        Uri.parse('$supabaseUrl/auth/v1/logout'),
        accessToken: token,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // The device is already signed out, even offline.
    }
  }

  static Future<Map<String, dynamic>> _refreshSession(
    String refreshToken,
    SharedPreferences prefs,
  ) async {
    final session = await _request(
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
      body: {'refresh_token': refreshToken},
    );
    if (prefs.getString(_refreshTokenKey) != refreshToken) {
      throw const HttpException('Session changed during refresh');
    }
    await _saveSession(session, prefs: prefs);
    return session;
  }

  static Future<Map<String, dynamic>> _request(
    Uri uri, {
    String method = 'POST',
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set('apikey', supabaseAnonKey);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (accessToken != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $accessToken',
        );
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final text = await response.transform(utf8.decoder).join();
      final decoded = text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = '${decoded['error_code'] ?? decoded['code'] ?? ''}';
        final message =
            '${decoded['msg'] ?? decoded['message'] ?? decoded['error_description'] ?? decoded['error'] ?? ''}';
        throw AuthException(_friendlyError(code, message));
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _saveSession(
    Map<String, dynamic> session, {
    SharedPreferences? prefs,
  }) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    final expiresIn = (session['expires_in'] as num?)?.toInt() ?? 3600;
    final user = session['user'] as Map<String, dynamic>?;
    final refreshToken = session['refresh_token'] as String;
    await Future.wait([
      storage.setString(_accessTokenKey, session['access_token'] as String),
      storage.setString(_refreshTokenKey, refreshToken),
      storage.setInt(
        _expiresAtKey,
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn,
      ),
    ]);
    if (storage.getString(_refreshTokenKey) != refreshToken) return;
    final email = user?['email'] as String?;
    if (email != null) await storage.setString(_emailKey, email);
    final userMetadata = user?['user_metadata'] as Map<String, dynamic>?;
    final agentName = userMetadata?['full_name'] as String?;
    if (agentName != null && agentName.trim().isNotEmpty) {
      final normalizedName = agentName.trim();
      final localAgentName = storage.getString('agent_nom');
      if (localAgentName != null &&
          localAgentName.trim().toLowerCase() !=
              normalizedName.toLowerCase()) {
        await storage.setString('agent_nom', normalizedName);
        await storage.remove('agent_signature_path');
      }
      await storage.setString(_agentNameKey, normalizedName);
    }
  }

  static Future<void> _clearSession(SharedPreferences prefs) async {
    producerSyncMessage = null;
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_expiresAtKey),
      prefs.remove(_emailKey),
      prefs.remove(_agentNameKey),
    ]);
  }

  static String _friendlyError(String code, String message) {
    final normalized = '$code $message'.toLowerCase();
    if (normalized.contains('invalid_credentials') ||
        normalized.contains('invalid login credentials')) {
      return 'Identifiant ou mot de passe incorrect.';
    }
    if (normalized.contains('email_not_confirmed')) {
      return 'Confirmez d’abord votre adresse e-mail dans Supabase.';
    }
    if (normalized.contains('too many requests')) {
      return 'Trop de tentatives. Attendez quelques minutes puis réessayez.';
    }
    if (message.isNotEmpty) return message;
    return 'Connexion impossible. Vérifiez votre réseau et réessayez.';
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
