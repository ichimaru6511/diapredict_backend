import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// Result returned by the Flask backend (/predict)
class PredictionResult {
  final double probability; // percentage, e.g. 87.5
  final String prediction; // "Diabetes" or "No Diabetes"
  final double threshold; // 0.5
  final List<String> warnings;
  final String disclaimer;

  PredictionResult({
    required this.probability,
    required this.prediction,
    required this.threshold,
    required this.warnings,
    required this.disclaimer,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final warningList = (json['warnings'] as List?) ?? [];
    return PredictionResult(
      probability: (json['probability'] as num).toDouble(),
      prediction: json['prediction'].toString(),
      threshold: (json['threshold'] as num).toDouble(),
      warnings: warningList.map((w) => w.toString()).toList(),
      disclaimer: (json['disclaimer'] ?? '').toString(),
    );
  }
}

// Error with a message that can be shown to the user
class PredictionException implements Exception {
  final String message;
  PredictionException(this.message);

  @override
  String toString() => message;
}

class PredictionService {
  // Flask backend hosted on Render (serves the selected Random Forest model)
  static const String baseUrl = 'https://diapredict-backend-gmnl.onrender.com';

  // saved with every assessment so each result can be traced to its model
  static const String modelVersion = 'RF-6features-v1';

  static Future<PredictionResult> predict(Map<String, num> inputs) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(inputs),
          )
          // the free Render server may need up to about a minute to wake up
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw PredictionException(
          'The prediction server did not respond. Please try again.');
    } on SocketException {
      throw PredictionException(
          'No internet connection. Please check your connection and try again.');
    } on http.ClientException {
      throw PredictionException(
          'Could not reach the prediction server. Please try again.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw PredictionException(
          'Unexpected response from the prediction server '
          '(${response.statusCode}).');
    }

    if (response.statusCode == 200) {
      return PredictionResult.fromJson(body);
    }
    // e.g. 400 with {"error": "HbA1c must be a number."}
    throw PredictionException(
        (body['error'] ?? 'Prediction failed (${response.statusCode}).')
            .toString());
  }
}
