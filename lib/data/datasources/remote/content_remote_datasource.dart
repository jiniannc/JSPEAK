import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/apps_script_fetch.dart';
import '../../models/content_bundle.dart';

/// 콘텐츠 JSON을 내려받는다.
/// 지금은 Apps Script Web App URL, 나중에는 정적 content.json 등 무엇이든
/// "JSON을 돌려주는 URL"이면 그대로 동작한다.
class ContentRemoteDataSource {
  final Dio _dio;
  final AppsScriptFetch _appsScriptFetch;

  ContentRemoteDataSource([Dio? dio, AppsScriptFetch? appsScriptFetch])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              followRedirects: true,
              maxRedirects: 5,
            )),
        _appsScriptFetch = appsScriptFetch ?? AppsScriptFetch(dio);

  Future<ContentBundle> fetch(String url) async {
    final body = AppsScriptFetch.isWebAppUrl(url)
        ? await _appsScriptFetch.getText(url)
        : await _fetchPlain(url);
    if (body.isEmpty) {
      throw Exception('콘텐츠 응답이 비어 있습니다.');
    }
    if (body.trimLeft().startsWith('<')) {
      throw Exception(
        '콘텐츠 URL이 JSON이 아닌 HTML을 반환했습니다. '
        'CONTENT_URL이 .../exec 로 끝나는지 확인하세요.',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return ContentBundle.fromJson(json);
  }

  Future<String> _fetchPlain(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }
}
