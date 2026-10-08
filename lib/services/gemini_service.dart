import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent';

  Future<String> generateText(String prompt) async {
    final uri = Uri.parse('$_apiUrl?key=$apiKey');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        final candidates = decodedResponse['candidates'] as List<dynamic>?;

        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'];
          if (content != null && content['parts'] != null) {
            final parts = content['parts'] as List<dynamic>;
            if (parts.isNotEmpty) {
              return parts.first['text'] as String;
            }
          }
        }
        throw Exception('API returned success but candidates data is missing or invalid.');
      } else {
        throw Exception('Failed to generate text. Status Code: ${response.statusCode} - Body: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }
}
