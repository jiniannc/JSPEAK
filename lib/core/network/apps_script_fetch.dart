import 'package:dio/dio.dart';

/// Google Apps Script 웹앱은 exec → googleusercontent 2단계 리다이렉트가 필요하다.
/// 쿼리 파라미터는 1차 exec 요청에서 처리되고, 응답 본문은 2차 echo URL에서 받는다.
class AppsScriptFetch {
  final Dio _dio;

  AppsScriptFetch([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 2),
              followRedirects: false,
              validateStatus: (status) => status != null && status < 500,
            ));

  static bool isWebAppUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host.contains('script.google.com') ||
        uri.host.contains('script.googleusercontent.com');
  }

  Future<Response<List<int>>> getBytes(String url) async {
    if (!isWebAppUrl(url)) {
      return _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );
    }

    final first = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    final redirectUrl = first.headers.value('location');
    if ((first.statusCode == 301 || first.statusCode == 302) &&
        redirectUrl != null &&
        redirectUrl.isNotEmpty) {
      return _dio.get<List<int>>(
        redirectUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );
    }

    return Response<List<int>>(
      requestOptions: first.requestOptions,
      statusCode: first.statusCode,
      headers: first.headers,
      data: first.data?.codeUnits,
    );
  }
}
