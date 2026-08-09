import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/content_bundle.dart';

/// 콘텐츠 JSON을 내려받는다.
/// 지금은 Apps Script Web App URL, 나중에는 정적 content.json 등 무엇이든
/// "JSON을 돌려주는 URL"이면 그대로 동작한다.
class ContentRemoteDataSource {
  final Dio _dio;

  ContentRemoteDataSource([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              // Apps Script는 302 리다이렉트로 응답하는 경우가 있어 따라가야 한다.
              followRedirects: true,
              maxRedirects: 5,
            ));

  Future<ContentBundle> fetch(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data;
    if (body == null || body.isEmpty) {
      throw Exception('콘텐츠 응답이 비어 있습니다.');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return ContentBundle.fromJson(json);
  }
}
