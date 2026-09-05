import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_key_storage_provider.g.dart';

/// 用户自填密钥存于系统安全存储，不写入源码或构建配置。
@riverpod
FlutterSecureStorage apiKeyStorage(Ref ref) => const FlutterSecureStorage();
