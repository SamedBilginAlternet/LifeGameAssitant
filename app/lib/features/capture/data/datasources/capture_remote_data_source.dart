import 'package:supabase_flutter/supabase_flutter.dart';

class CaptureRemoteDataSource {
  CaptureRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<void> upsertDailyLog({
    required String userId,
    required String localDate,
    int? moodScore,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'local_date': localDate,
      if (moodScore != null) 'mood_score': moodScore,
      if (note != null) 'note': note,
    };
    await _client
        .from('daily_logs')
        .upsert(payload, onConflict: 'user_id,local_date');
  }

  Future<void> upsertFitness({
    required String userId,
    required String localDate,
    required String metric,
    required num value,
  }) async {
    await _client.from('fitness_data').upsert({
      'user_id': userId,
      'local_date': localDate,
      'metric': metric,
      'value': value,
      'source': 'manual',
    }, onConflict: 'user_id,local_date,metric');
  }

  Future<void> insertLearning({
    required String userId,
    required String localDate,
    required String track,
    required int minutes,
    String? topic,
  }) async {
    await _client.from('learning_logs').insert({
      'user_id': userId,
      'local_date': localDate,
      'track': track,
      'minutes': minutes,
      if (topic != null && topic.isNotEmpty) 'topic': topic,
    });
  }

  Future<void> insertMeal({
    required String userId,
    required String localDate,
    required String mealType,
    required String title,
    int? calories,
    num? proteinG,
    num? carbsG,
  }) async {
    await _client.from('meals').insert({
      'user_id': userId,
      'local_date': localDate,
      'meal_type': mealType,
      'title': title,
      if (calories != null) 'calories': calories,
      if (proteinG != null) 'protein_g': proteinG,
      if (carbsG != null) 'carbs_g': carbsG,
    });
  }

  Future<void> insertMovie({
    required String userId,
    required String localDate,
    required String title,
    int? releaseYear,
    int? rating,
    String? medium,
  }) async {
    await _client.from('movies_watched').insert({
      'user_id': userId,
      'local_date': localDate,
      'title': title,
      if (releaseYear != null) 'release_year': releaseYear,
      if (rating != null) 'rating': rating,
      if (medium != null) 'medium': medium,
    });
  }

  Future<void> insertRide({
    required String userId,
    required String localDate,
    required num distanceKm,
    int? durationMin,
    String? routeTag,
    String? notes,
  }) async {
    await _client.from('motorcycle_rides').insert({
      'user_id': userId,
      'local_date': localDate,
      'distance_km': distanceKm,
      if (durationMin != null) 'duration_min': durationMin,
      if (routeTag != null && routeTag.isNotEmpty) 'route_tag': routeTag,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  Future<void> insertWorkout({
    required String userId,
    required String localDate,
    required String name,
    int? durationMin,
    num? totalVolumeKg,
    String? notes,
  }) async {
    await _client.from('workouts').insert({
      'user_id': userId,
      'local_date': localDate,
      'name': name,
      if (durationMin != null) 'duration_min': durationMin,
      if (totalVolumeKg != null) 'total_volume_kg': totalVolumeKg,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }
}
