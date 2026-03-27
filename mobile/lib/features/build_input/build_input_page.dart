import 'package:flutter/material.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_picker_sheet.dart';
import 'package:mobile/features/catalog/catalog_repository.dart';
import 'package:mobile/features/heroes/hero_item.dart';
import 'package:mobile/features/heroes/hero_repository.dart';
import 'package:mobile/features/runs/run_record.dart';
import 'package:mobile/features/runs/run_result_tier.dart';
import 'package:mobile/features/runs/run_tier_visual.dart';
import 'package:mobile/features/runs/runs_repository.dart';
import 'package:mobile/features/shared/ui/labeled_slider_row.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

class BuildInputPage extends StatefulWidget {
  const BuildInputPage({
    required this.isGuest,
    super.key,
    this.userId,
    this.existingRun,
  });

  final bool isGuest;
  final String? userId;
  /// When set, the form loads this run and saves with [updateRun] instead of [addRun].
  final RunRecord? existingRun;

  @override
  State<BuildInputPage> createState() => _BuildInputPageState();
}

class _BuildInputPageState extends State<BuildInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String? _heroId;
  String _mode = 'ranked';
  int _wins = 0;
  bool _perfect = false;
  bool _saving = false;
  final List<CatalogItem> _selectedItems = [];
  bool _seededBoardFromExisting = false;
  bool _seedBoardLoading = false;

  late final RunsRepository _runsRepo = createRunsRepository(
    isGuest: widget.isGuest,
    userId: widget.userId,
  );

  @override
  void initState() {
    super.initState();
    final run = widget.existingRun;
    if (run != null) {
      _heroId = run.heroId;
      _mode = run.mode;
      _wins = run.wins.clamp(0, 10);
      _perfect = run.perfect;
      _notesController.text = run.notes;
    }
    if (widget.existingRun != null) {
      _seedBoardItemsFromExisting();
    }
  }

  Future<void> _seedBoardItemsFromExisting() async {
    final run = widget.existingRun;
    if (run == null) return;
    if (_seededBoardFromExisting) return;
    if (_seedBoardLoading) return;

    _seededBoardFromExisting = true;
    _seedBoardLoading = true;

    // Start with placeholders so the UI can render immediately.
    final placeholders = run.itemIds
        .map((id) => CatalogItem.unknown(id))
        .toList(growable: false);
    setState(() {
      _selectedItems
        ..clear()
        ..addAll(placeholders);
    });

    final uniqueIds = run.itemIds.toSet().toList(growable: false);
    List<CatalogItem?> fetched;
    try {
      fetched = await Future.wait(
        uniqueIds.map((id) => catalogRepository.fetchCatalogItemById(id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _seedBoardLoading = false;
      });
      return;
    }

    if (!mounted) return;

    final byId = <String, CatalogItem?>{};
    for (var i = 0; i < uniqueIds.length; i += 1) {
      byId[uniqueIds[i]] = fetched[i];
    }
    final resolved = run.itemIds
        .map((id) => byId[id] ?? CatalogItem.unknown(id))
        .toList(growable: false);

    setState(() {
      _selectedItems
        ..clear()
        ..addAll(resolved);
      _seedBoardLoading = false;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _showPerfectToggle => _wins == 10;

  RunResultTier get _previewTier {
    final p = _showPerfectToggle && _perfect;
    return classifyRunResult(wins: _wins.clamp(0, 10), perfect: p);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final wins = _wins.clamp(0, 10);
    if (_heroId == null || _heroId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a hero.')),
      );
      return;
    }
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one board item.')),
      );
      return;
    }

    final notes = _notesController.text.trim();
    if (notes.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes must be 500 characters or less.')),
      );
      return;
    }

    final perfect = _showPerfectToggle && _perfect;
    final tier = classifyRunResult(wins: wins, perfect: perfect);

    setState(() => _saving = true);
    try {
      final prior = widget.existingRun;
      final run = RunRecord(
        id: prior?.id ?? newRunId(),
        itemIds: _selectedItems.map((e) => e.id).toList(growable: false),
        createdAt: prior?.createdAt ?? DateTime.now(),
        mode: _mode,
        heroId: _heroId!,
        wins: wins,
        perfect: perfect,
        resultTier: tier,
        notes: notes,
        screenshotPath: prior?.screenshotPath ?? '',
        screenshotUrl: prior?.screenshotUrl ?? '',
      );
      if (prior != null) {
        await _runsRepo.updateRun(run);
      } else {
        await _runsRepo.addRun(run);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(prior != null ? 'Run updated.' : 'Run saved.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save run: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickItem() async {
    final picked = await showCatalogItemPickerPaged(
      context: context,
      pageSize: 50,
    );
    if (picked != null) {
      setState(() => _selectedItems.add(picked));
    }
  }

  static const _surfaceInner = Color(0xFF241516);
  static const _border = Color(0xFF5B3A1F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(widget.existingRun != null ? 'Edit run' : 'Add run'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Run details',
              subtitle: 'Hero, mode, wins, outcome.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder<List<HeroItem>>(
                    stream: heroRepository.watchActiveHeroes(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Could not load heroes: ${snapshot.error}',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final heroes = snapshot.data!;
                      if (heroes.isEmpty) {
                        return const Text(
                          'No heroes in Firestore. Seed the `heroes` collection first.',
                        );
                      }
                      return DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _heroId,
                        decoration: const InputDecoration(
                          labelText: 'Hero',
                        ),
                        items: heroes
                            .map<DropdownMenuItem<String>>(
                              (HeroItem h) => DropdownMenuItem<String>(
                                value: h.id,
                                child: Text(h.name.isEmpty ? h.id : h.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _heroId = v),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Choose a hero' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mode',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: const Color(0xFFEED9BA),
                              ),
                        ),
                      ),
                      _DualPillSliderToggle(
                        leftLabel: 'Ranked',
                        rightLabel: 'Normal',
                        isLeftSelected: _mode == 'ranked',
                        onChanged: (leftSelected) {
                          setState(() => _mode = leftSelected ? 'ranked' : 'normal');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LabeledSliderRow(
                    label: 'Wins',
                    value: _wins,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    onChanged: (x) {
                      setState(() {
                        _wins = x.round();
                        if (_wins < 10) _perfect = false;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final style = RunTierStyle.forTier(_previewTier);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _surfaceInner,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border.withValues(alpha: 0.85)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: style.iconBackground,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: style.buildIcon(size: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    runResultTierLabel(_previewTier),
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: style.labelColor,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Container(
                                height: 5,
                                color: style.accentBar,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_showPerfectToggle) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _perfect,
                      onChanged: (v) => setState(() => _perfect = v),
                      title: const Text('Perfect run'),
                      subtitle: const Text(
                        'Only at 10 wins.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFC3B5A0)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'How did the run go?',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Board items',
              subtitle: 'From the catalog. Duplicates allowed.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickItem(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                  if (_selectedItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'No items yet. Tap Add item.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFC3B5A0),
                            ),
                      ),
                    )
                  else
                    ..._selectedItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final base = item.name.isEmpty ? item.id : item.name;
                      final priorSame = _selectedItems
                          .take(i)
                          .where((e) => e.id == item.id)
                          .length;
                      final label =
                          priorSame > 0 ? '$base (${priorSame + 1})' : base;
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Material(
                          color: _surfaceInner,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              child: Text('${i + 1}'),
                            ),
                            title: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (item.heroTag.isNotEmpty) item.heroTag,
                                item.startingRarity,
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: const TextStyle(
                                color: Color(0xFFD0C0A8),
                                fontSize: 13,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => _selectedItems.removeAt(i));
                              },
                              tooltip: 'Remove',
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DualPillSliderToggle extends StatelessWidget {
  const _DualPillSliderToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    const surface = Color(0xFF120A0B);
    const border = Color(0xFF62401F);
    const textMuted = Color(0xFFE2B569);
    const onSelected = Color(0xFF1A1106);

    return Container(
      height: 52,
      width: 186,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            alignment: isLeftSelected ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(true),
                  child: Center(
                    child: Text(
                      leftLabel,
                      style: TextStyle(
                        color: isLeftSelected ? onSelected : textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(false),
                  child: Center(
                    child: Text(
                      rightLabel,
                      style: TextStyle(
                        color: isLeftSelected ? textMuted : onSelected,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
