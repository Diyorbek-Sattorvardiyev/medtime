import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../auth_api.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(authApi: ref.watch(authApiProvider)),
);
