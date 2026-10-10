import 'package:flutter/services.dart';

/// A contact read from the phone's address book.
class PhoneContact {
  const PhoneContact({required this.name, required this.phone});
  final String name;

  /// First phone number of the contact, exactly as stored (may be empty).
  final String phone;
}

/// Thin wrapper over the native "shophisab/contacts" channel (MainActivity).
class DeviceContacts {
  DeviceContacts._();
  static const _channel = MethodChannel('shophisab/contacts');

  static Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('hasPermission') ?? false;

  static Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  static Future<void> openAppSettings() async {
    await _channel.invokeMethod<bool>('openSettings');
  }

  static Future<List<PhoneContact>> load() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getContacts');
    final out = <PhoneContact>[];
    for (final item in raw ?? const <dynamic>[]) {
      final map = item as Map<dynamic, dynamic>;
      out.add(
        PhoneContact(
          name: (map['name'] ?? '').toString(),
          phone: (map['phone'] ?? '').toString(),
        ),
      );
    }
    return out;
  }
}
