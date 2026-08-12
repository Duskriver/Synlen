import 'package:logger/logger.dart';

/// 全局共享的日志实例（规范 §8：日志统一走 [Logger] 包，禁止 print / debugPrint）。
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    lineLength: 120,
    colors: false,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
