import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'services/api_client.dart';
import 'services/appapi/app_auth_service.dart';
import 'services/appapi/app_participants_service.dart'; // ← правильний імпорт

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final dioProvider = Provider<Dio>((ref) => ref.watch(apiClientProvider).dio);

final appAuthServiceProvider =
    Provider<AuthService>((ref) => AuthService.withDio(ref.watch(dioProvider)));

final participantsServiceProvider = Provider<ParticipantsService>(
    (ref) => ParticipantsService.withDio(ref.watch(dioProvider)));
