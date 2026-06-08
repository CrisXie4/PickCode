/// 取字符串首字符作头像文字。
/// null 或空字符串时返回 fallback —— 避免 "".substring(0,1) 抛 RangeError
/// 导致 release 包整页渲染成灰块。
String initial(Object? name, [String fallback = '?']) {
  final s = name?.toString() ?? '';
  return s.isEmpty ? fallback : s.substring(0, 1);
}
