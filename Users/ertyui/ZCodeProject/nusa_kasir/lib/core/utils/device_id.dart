import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:nusa_kasir/core/constants/app_constants.dart';

Future<String> getDeviceId() async {
  const storage = FlutterSecureStorage();
  final existing = await storage.read(key: AppConstants.deviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = const Uuid().v4();
  await storage.write(key: AppConstants.deviceIdKey, value: id);
  return id;
}
