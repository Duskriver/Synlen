/// 阅读方向与 [ShelfBook.direction] 的转换工具。
library;

/// 把 [ShelfBook.direction] 数值转为可读字符串。
/// LTR = 0，RTL = 1。
String directionToString(int direction) {
  switch (direction) {
    case 1:
      return 'RTL';
    case 0:
    default:
      return 'LTR';
  }
}
