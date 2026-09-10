import 'dart:convert';

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

    // Dio가 이미 UTF-8로 디코딩한 문자열 — codeUnits(UTF-16)로 바꾸면 깨진다.
    return Response<List<int>>(
      requestOptions: first.requestOptions,
      statusCode: first.statusCode,
      headers: first.headers,
      data: utf8.encode(first.data ?? ''),
    );
  }

  /// JSON 등 텍스트 응답용. 바이트 변환 없이 Dio 문자열을 그대로 쓴다.
  Future<String> getText(String url) async {
    if (!isWebAppUrl(url)) {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return response.data ?? '';
    }

    final first = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    final redirectUrl = first.headers.value('location');
    if ((first.statusCode == 301 || first.statusCode == 302) &&
        redirectUrl != null &&
        redirectUrl.isNotEmpty) {
      final second = await _dio.get<String>(
        redirectUrl,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );
      return second.data ?? '';
    }

    return first.data ?? '';
  }
}
