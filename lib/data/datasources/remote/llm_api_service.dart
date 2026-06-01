import 'package:dio/dio.dart';
import 'package:nai_huishi/core/constants/api_constants.dart';
import 'package:nai_huishi/core/errors/exceptions.dart';

class LlmApiService {
  final Dio _dio;

  LlmApiService(this._dio);

  void _configureAuth(String apiKey, String baseUrl) {
    _dio.options.baseUrl = _normalizeBaseUrl(baseUrl);
    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.headers['Accept'] = 'application/json';
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/v1')) {
      return trimmed.substring(0, trimmed.length - 3);
    }
    return trimmed;
  }

  /// 发起一次 OpenAI 兼容的 chat completions 请求，返回 assistant 文本
  /// messages 支持纯文本格式 Map<String,String> 和 vision 格式 Map<String,dynamic>
  Future<String> chatCompletions({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw ApiException(message: '请先在齿轮设置中填写 LLM API Key');
    }
    if (baseUrl.trim().isEmpty) {
      throw ApiException(message: '请先在齿轮设置中填写 LLM Base URL');
    }
    if (model.trim().isEmpty) {
      throw ApiException(message: '请先在齿轮设置中填写 LLM 模型名');
    }

    _configureAuth(apiKey, baseUrl);

    try {
      final response = await _dio.post(
        ApiConstants.chatCompletions,
        data: {
          'model': model,
          'messages': messages,
          'stream': false,
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices.first['message'];
          if (message is Map && message['content'] is String) {
            final content = (message['content'] as String).trim();
            if (content.isNotEmpty) return content;
          }
        }
      }
      throw ApiException(message: '响应格式异常，未能解析到回复内容');
    } on DioException catch (e) {
      throw ApiException(
        message: _handleDioError(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时，请检查网络连接';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        if (statusCode == 401) return 'API Key 无效或已过期';
        if (statusCode == 402) return '额度不足';
        if (statusCode == 404) return '接口不存在，请检查 Base URL 是否正确';
        if (statusCode == 429) return '请求过于频繁，请稍后再试';
        if (statusCode == 500) return '服务器内部错误';
        if (body is Map) {
          return body['error']?['message']?.toString() ?? '请求失败 ($statusCode)';
        }
        return '请求失败 ($statusCode)';
      case DioExceptionType.connectionError:
        return '无法连接到服务器，请检查 Base URL';
      default:
        return '网络错误: ${e.message}';
    }
  }
}
