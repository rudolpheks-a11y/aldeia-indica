import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../data/prestador_repository.dart';
import '../providers/prestador_provider.dart';

const _dayNames = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
const _dayFullNames = [
  'Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'
];

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  // day_of_week → {start, end} — null means day is off
  final Map<int, _DaySlot> _slots = {};
  bool _loaded = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(prestadorProfileProvider);

    profileAsync.whenData((profile) {
      if (!_loaded) {
        for (final sl in profile.availability) {
          _slots[sl.dayOfWeek] = _DaySlot(
            start: _parseTime(sl.startTime),
            end: _parseTime(sl.endTime),
          );
        }
        _loaded = true;
      }
    });

    return LoadingOverlay(
      isLoading: _saving,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Minha agenda'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  Text(
                    'Selecione os dias e horários em que você está disponível:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(7, (i) => _DayRow(
                    dayIndex: i,
                    slot: _slots[i],
                    onToggle: (enabled) => setState(() {
                      if (enabled) {
                        _slots[i] = const _DaySlot(
                          start: TimeOfDay(hour: 8, minute: 0),
                          end: TimeOfDay(hour: 18, minute: 0),
                        );
                      } else {
                        _slots.remove(i);
                      }
                    }),
                    onPickStart: () => _pickTime(i, isStart: true),
                    onPickEnd: () => _pickTime(i, isStart: false),
                  )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Salvar disponibilidade'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(int dayIndex, {required bool isStart}) async {
    final current = _slots[dayIndex];
    if (current == null) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? current.start : current.end,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      _slots[dayIndex] = isStart
          ? current.copyWith(start: picked)
          : current.copyWith(end: picked);
    });
  }

  Future<void> _save() async {
    // Validate: end must be after start
    for (final entry in _slots.entries) {
      final sl = entry.value;
      final startMins = sl.start.hour * 60 + sl.start.minute;
      final endMins = sl.end.hour * 60 + sl.end.minute;
      if (endMins <= startMins) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Horário inválido em ${_dayFullNames[entry.key]}: o fim deve ser após o início.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final slots = _slots.entries
          .map((e) => AvailabilitySlot(
                dayOfWeek: e.key,
                startTime: _formatTime(e.value.start),
                endTime: _formatTime(e.value.end),
              ))
          .toList()
        ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

      await ref.read(prestadorRepositoryProvider).updateAvailability(slots);
      ref.invalidate(prestadorProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agenda salva com sucesso!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DaySlot {
  final TimeOfDay start;
  final TimeOfDay end;

  const _DaySlot({required this.start, required this.end});

  _DaySlot copyWith({TimeOfDay? start, TimeOfDay? end}) =>
      _DaySlot(start: start ?? this.start, end: end ?? this.end);
}

class _DayRow extends StatelessWidget {
  final int dayIndex;
  final _DaySlot? slot;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DayRow({
    required this.dayIndex,
    required this.slot,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = slot != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: enabled ? AppColors.primary.withValues(alpha: 0.05) : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: enabled ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    _dayNames[dayIndex],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: enabled ? AppColors.primary : Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _dayFullNames[dayIndex],
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled ? AppColors.textPrimary : Colors.grey[500],
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  const Text('Das', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  _TimeButton(
                    time: slot!.start,
                    onTap: onPickStart,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('às', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ),
                  _TimeButton(
                    time: slot!.end,
                    onTap: onPickEnd,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: AppColors.primary),
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}
