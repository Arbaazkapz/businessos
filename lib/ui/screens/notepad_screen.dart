import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/app_database.dart';
import '../../providers/app_providers.dart';
import '../widgets/common_widgets.dart';

/// A genuine, working notepad - notes are persisted in the same local
/// SQLite database as everything else, so they survive app restarts and
/// are included in encrypted backups automatically.
class NotepadScreen extends ConsumerWidget {
  const NotepadScreen({super.key});

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {Note? existing}) async {
    final ctrl = TextEditingController(text: existing?.content ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'New note' : 'Edit note',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(hintText: 'Remember, buy milk, call supplier...'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save note'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty) return;
    final repo = ref.read(noteRepositoryProvider);
    if (existing == null) {
      await repo.create(result);
    } else {
      await repo.update(existing.id, result);
    }
    if (context.mounted) {
      showSuccessSnack(context, existing == null ? 'Note added' : 'Note updated');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notepad')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add note'),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return const EmptyState(
              icon: Icons.sticky_note_2_outlined,
              title: 'No notes yet',
              message: 'Jot down anything you need to remember - it stays on this phone.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final note = notes[i];
              return Dismissible(
                key: ValueKey(note.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) => confirmDialog(context,
                    title: 'Delete note?', message: 'This cannot be undone.'),
                onDismissed: (_) {
                  ref.read(noteRepositoryProvider).delete(note.id);
                  showSuccessSnack(context, 'Note deleted');
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _openEditor(context, ref, existing: note),
                    title: Text(note.content, maxLines: 4, overflow: TextOverflow.ellipsis),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(AppFormatters.dateTimeStr(note.updatedAt),
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
