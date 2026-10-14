import 'dart:convert';

import 'package:http/http.dart' as http;

class PhotonVenueServiceException implements Exception {
  const PhotonVenueServiceException(this.message);

  final String message;
}

class PhotonVenueService {
  PhotonVenueService._();

  static final PhotonVenueService instance = PhotonVenueService._();
  static const _endpoint = 'photon.komoot.io';

  Future<List<String>> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 3) return const [];

    try {
      final response = await http
          .get(
            Uri.https(_endpoint, '/api/', {
              'q': normalizedQuery,
              'limit': '8',
              'lang': 'en',
            }),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw PhotonVenueServiceException(
          'Venue search is unavailable (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['features'] is! List<dynamic>) {
        throw const PhotonVenueServiceException(
          'Venue search returned an invalid response.',
        );
      }

      final venues = <String>[];
      for (final feature in decoded['features'] as List<dynamic>) {
        if (feature is! Map<String, dynamic>) continue;
        final properties = feature['properties'];
        if (properties is! Map<String, dynamic>) continue;

        final name = properties['name'] as String?;
        if (name == null || name.trim().isEmpty) continue;

        final locality = [
          properties['street'],
          properties['city'] ?? properties['district'],
          properties['state'],
          properties['country'],
        ].whereType<String>().where((part) => part.trim().isNotEmpty);
        final label = {name.trim(), ...locality}.join(', ');
        if (!venues.contains(label)) venues.add(label);
      }
      return venues;
    } on PhotonVenueServiceException {
      rethrow;
    } on http.ClientException catch (e) {
      throw PhotonVenueServiceException(
        'Could not connect to venue search: ${e.message}',
      );
    } on FormatException {
      throw const PhotonVenueServiceException(
        'Venue search returned an invalid response.',
      );
    } on Exception catch (e) {
      throw PhotonVenueServiceException('Venue search failed: $e');
    }
  }
}
