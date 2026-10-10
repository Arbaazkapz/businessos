import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validation.dart';
import '../../../providers/app_providers.dart';
import '../../../services/device_contacts.dart';

enum _Stage { loading, denied, ready, importing, error }

/// Lets the owner pick contacts from the phone's address book and saves the
/// selected ones as customers. Pops with the number of customers added.
class ContactImportScreen extends ConsumerStatefulWidget {
  const ContactImportScreen({super.key});

  @override
  ConsumerState<ContactImportScreen> createState() =>
      _ContactImportScreenState();
}

class _ContactImportScreenState extends ConsumerState<ContactImportScreen> {
  _Stage _stage = _Stage.loading;
  List<PhoneContact> _contacts = const [];
  final Set<int> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _stage = _Stage.loading);
    try {
      var ok = await DeviceContacts.hasPermission();
      if (!ok) ok = await DeviceContacts.requestPermission();
      if (!mounted) return;
      if (!ok) {
        setState(() => _stage = _Stage.denied);
        return;
      }
      final list = await DeviceContacts.load();
      if (!mounted) return;
      setState(() {
        _contacts = list;
        _stage = _Stage.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.error);
    }
  }

  // ----------------------------------------------------------- cleaning

  /// Keeps letters, spaces and . ' - (what the customer form accepts).
  static String _cleanName(String raw) {
    var s = raw.replaceAll(
      RegExp(r"[^\p{L}\p{M} .'\u2019\-]", unicode: true),
      ' ',
    );
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceFirst(RegExp(r'^[^\p{L}]+', unicode: true), '');
    if (s.length > 80) s = s.substring(0, 80).trim();
    return s;
  }

  static String _cleanPhone(String raw) {
    var s = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    if (!s.startsWith('+')) {
      if (s.length == 11 && s.startsWith('0')) {
        s = s.substring(1);
      } else if (s.length == 12 && s.startsWith('91')) {
        s = '+$s';
      }
    }
    return s;
  }

  static String _phoneKey(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  // ------------------------------------------------------------- import

  Future<void> _import() async {
    if (_selected.isEmpty || _stage != _Stage.ready) return;
    setState(() => _stage = _Stage.importing);
    final repo = ref.read(customerRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    var added = 0, duplicates = 0, skipped = 0, withoutPhone = 0;
    try {
      final existing = await ref.read(customersProvider.future);
      final phoneKeys = <String>{};
      final nameKeys = <String>{};
      for (final c in existing) {
        if (c.phone.isNotEmpty) phoneKeys.add(_phoneKey(c.phone));
        nameKeys.add(c.name.trim().toLowerCase());
      }
      final indexes = _selected.toList()..sort();
      for (final i in indexes) {
        final contact = _contacts[i];
        final name = _cleanName(contact.name);
        if (name.length < 2) {
          skipped++;
          continue;
        }
        var phone = _cleanPhone(contact.phone);
        var notes = '';
        if (phone.isNotEmpty && AppValidation.phone(phone) != null) {
          // Keep the original number in the notes instead of losing it.
          notes = 'Phone in contacts: ${contact.phone.trim()}';
          phone = '';
          withoutPhone++;
        }
        final isDuplicate = phone.isNotEmpty
            ? phoneKeys.contains(_phoneKey(phone))
            : nameKeys.contains(name.toLowerCase());
        if (isDuplicate) {
          duplicates++;
          continue;
        }
        try {
          await repo.create(name: name, phone: phone, notes: notes);
          added++;
          if (phone.isNotEmpty) phoneKeys.add(_phoneKey(phone));
          nameKeys.add(name.toLowerCase());
        } catch (_) {
          skipped++;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _stage = _Stage.ready);
        messenger.showSnackBar(
          const SnackBar(content: Text('Import failed. Please try again.')),
        );
      }
      return;
    }
    final parts = <String>[
      'Imported $added ${added == 1 ? 'customer' : 'customers'}',
      if (duplicates > 0) '$duplicates already existed',
      if (withoutPhone > 0) '$withoutPhone saved without a valid phone',
      if (skipped > 0) '$skipped skipped',
    ];
    messenger.showSnackBar(SnackBar(content: Text(parts.join(' · '))));
    if (!mounted) return;
    if (added > 0) {
      Navigator.pop(context, added);
    } else {
      setState(() {
        _selected.clear();
        _stage = _Stage.ready;
      });
    }
  }

  // ----------------------------------------------------------------- UI

  List<int> get _visible {
    final q = _query.trim().toLowerCase();
    final qDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
    final out = <int>[];
    for (var i = 0; i < _contacts.length; i++) {
      final c = _contacts[i];
      if (q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          (qDigits.isNotEmpty &&
              c.phone.replaceAll(RegExp(r'[^0-9]'), '').contains(qDigits))) {
        out.add(i);
      }
    }
    return out;
  }

  Widget _message(IconData icon, String text, List<Widget> actions) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ...actions,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final visible = _stage == _Stage.ready ? _visible : const <int>[];
    final allVisibleSelected =
        visible.isNotEmpty && visible.every(_selected.contains);

    Widget body;
    switch (_stage) {
      case _Stage.loading:
      case _Stage.importing:
        body = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _stage == _Stage.importing
                    ? 'Importing customers…'
                    : 'Reading contacts…',
              ),
            ],
          ),
        );
      case _Stage.denied:
        body = _message(
          Icons.lock_outline,
          'Contacts permission is needed to import customers. Your contacts are read on this phone only and are never uploaded.',
          [
            FilledButton(
              onPressed: _start,
              child: const Text('Allow access'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: DeviceContacts.openAppSettings,
              child: const Text('Open app settings'),
            ),
          ],
        );
      case _Stage.error:
        body = _message(
          Icons.error_outline,
          'Could not read your contacts.',
          [FilledButton(onPressed: _start, child: const Text('Try again'))],
        );
      case _Stage.ready:
        body = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search contacts',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: visible.isEmpty
                        ? null
                        : () => setState(() {
                              if (allVisibleSelected) {
                                _selected.removeAll(visible);
                              } else {
                                _selected.addAll(visible);
                              }
                            }),
                    child: Text(
                      allVisibleSelected
                          ? 'Clear selection'
                          : 'Select all (${visible.length})',
                    ),
                  ),
                  const Spacer(),
                  Text('${_selected.length} selected'),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('No contacts found'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, row) {
                        final i = visible[row];
                        final c = _contacts[i];
                        return CheckboxListTile(
                          value: _selected.contains(i),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(i);
                            } else {
                              _selected.remove(i);
                            }
                          }),
                          title: Text(c.name),
                          subtitle: Text(
                            c.phone.isEmpty ? 'No phone number' : c.phone,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Import from contacts')),
      body: body,
      bottomNavigationBar: _stage == _Stage.ready
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty ? null : _import,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(
                    _selected.isEmpty
                        ? 'Select contacts to import'
                        : 'Import ${_selected.length} ${_selected.length == 1 ? 'customer' : 'customers'}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
