import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/redacting_log_interceptor.dart';
import 'token_store.dart';

/// Builds the app's single [Dio] instance.
///
/// One instance, registered once in the service locator. Creating a Dio per
/// data source means each one needs its own interceptors, and the day someone
/// forgets the auth interceptor you get a feature that is mysteriously always
/// logged out.
abstract final class DioClient {
  static Dio create(TokenStore tokenStore) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,

        // Dio's default `validateStatus` is kept deliberately: anything that
        // is not 2xx throws a DioException. It is tempting to let 4xx come
        // back as a normal response so a data source can read the server's
        // `{"message": ...}` — but a DioException of type `badResponse` still
        // carries the whole response, body included, so `mapDioException`
        // already has everything it needs. Widening `validateStatus` would
        // buy nothing and split error handling into two paths: thrown for
        // 5xx, returned for 4xx. One path is worth more than the convenience.
      ),
    );

    dio.interceptors.add(AuthInterceptor(tokenStore));

    if (AppConfig.enableNetworkLogs) {
      dio.interceptors.add(const RedactingLogInterceptor());
    }

    return dio;
  }
}
