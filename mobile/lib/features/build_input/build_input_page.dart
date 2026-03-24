import 'package:flutter/material.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

class BuildInputPage extends StatelessWidget {
  const BuildInputPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add run')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SectionCard(
            title: 'Run Details',
            subtitle: 'MVP fields: hero, mode, wins, perfect, notes.',
            child: _RunDetailsForm(),
          ),
          SectionCard(
            title: 'Board Items',
            subtitle: 'Choose board items and optional enchanted status.',
            child: _BoardItemPlaceholder(),
          ),
        ],
      ),
    );
  }
}

class _RunDetailsForm extends StatelessWidget {
  const _RunDetailsForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          items: const [
            DropdownMenuItem(value: 'dooley', child: Text('Dooley')),
            DropdownMenuItem(value: 'pyg', child: Text('Pyg')),
            DropdownMenuItem(value: 'vanessa', child: Text('Vanessa')),
          ],
          onChanged: (_) {},
          decoration: const InputDecoration(labelText: 'Hero'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          items: const [
            DropdownMenuItem(value: 'ranked', child: Text('Ranked')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
          ],
          onChanged: (_) {},
          decoration: const InputDecoration(labelText: 'Mode'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Wins',
            hintText: '0 to 10',
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: false,
          onChanged: (_) {},
          title: const Text('Perfect run'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'Add notes about this run',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: null, child: Text('Save run')),
      ],
    );
  }
}

class _BoardItemPlaceholder extends StatelessWidget {
  const _BoardItemPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            6,
            (index) => Chip(label: Text('Item slot ${index + 1}')),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Use the item picker to add board items in this run.'),
      ],
    );
  }
}
