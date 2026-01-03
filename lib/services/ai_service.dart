import 'package:cloud_functions/cloud_functions.dart';
import '../models/parking_session_model.dart';

class AIService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<AIParsed?> parseParkingNote(String note) async {
    try {
      final callable = _functions.httpsCallable('aiParseParkingNote');
      final result = await callable.call({'note': note});

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true && data['parsed'] != null) {
        return AIParsed.fromJson(data['parsed'] as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      print('Error parsing note with AI: $e');
      return null;
    }
  }

  Future<AIConfidence?> getConfidenceAdvisor({
    required double gpsAccuracy,
    required bool isUnderground,
    required bool hasPhoto,
    required bool hasNote,
  }) async {
    try {
      final callable = _functions.httpsCallable('aiConfidenceAdvisor');
      final result = await callable.call({
        'gpsAccuracy': gpsAccuracy,
        'isUnderground': isUnderground,
        'hasPhoto': hasPhoto,
        'hasNote': hasNote,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true && data['confidence'] != null) {
        return AIConfidence.fromJson(data['confidence'] as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      print('Error getting confidence advisor: $e');
      return null;
    }
  }

  Future<String?> searchParkingSession(
    String query,
    List<Map<String, dynamic>> sessionsSummary,
  ) async {
    try {
      final callable = _functions.httpsCallable('aiSearchParkingSession');
      final result = await callable.call({
        'query': query,
        'sessions': sessionsSummary,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true && data['sessionId'] != null) {
        return data['sessionId'] as String;
      }

      return null;
    } catch (e) {
      print('Error searching parking session: $e');
      return null;
    }
  }

  Future<String?> askFAQ(String question) async {
    try {
      final callable = _functions.httpsCallable('aiFaq');
      final result = await callable.call({'question': question});

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true && data['answer'] != null) {
        return data['answer'] as String;
      }

      return null;
    } catch (e) {
      print('Error asking FAQ: $e');
      return null;
    }
  }
}

