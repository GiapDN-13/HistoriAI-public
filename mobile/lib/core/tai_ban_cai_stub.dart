/// Bản web không cài APK — chỉ để biên dịch được.
Future<String> taiBanCai({
  required String url,
  required String thuMuc,
  required int build,
  int? tongByte,
  required void Function(double) tienDo,
  required bool Function() daHuy,
}) =>
    throw UnsupportedError('chỉ dùng trên Android');
