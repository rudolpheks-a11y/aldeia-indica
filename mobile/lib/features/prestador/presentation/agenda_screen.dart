import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../data/prestador_repository.dart';
import '../providers/prestador_provider.dart';
import '../../provider_profile/providers/profile_provider.dart';

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
  // day_of_week → lista de horários daquele dia; ausente/vazio = dia desativado
  final Map<int, List<_DaySlot>> _slots = {};
  final _listCtrl = ScrollController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(prestadorProfileProvider);

    profileAsync.whenData((profile) {
      if (!_loaded) {
        for (final sl in profile.availability) {
          _slots.putIfAbsent(sl.dayOfWeek, () => []).add(_DaySlot(
                start: _parseTime(sl.startTime),
                end: _parseTime(sl.endTime),
              ));
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
              child: AppScrollbar(
                controller: _listCtrl,
                child: ListView(
                controller: _listCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  Text(
                    'Selecione os dias e horários em que você está disponível:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(7, (i) => _DayRow(
                    dayIndex: i,
                    daySlots: _slots[i] ?? const [],
                    onToggle: (enabled) => setState(() {
                      if (enabled) {
                        _slots[i] = [
                          const _DaySlot(
                            start: TimeOfDay(hour: 8, minute: 0),
                            end: TimeOfDay(hour: 18, minute: 0),
                          ),
                        ];
                      } else {
                        _slots.remove(i);
                      }
                    }),
                    onAddSlot: () => setState(() {
                      _slots[i]!.add(const _DaySlot(
                        start: TimeOfDay(hour: 8, minute: 0),
                        end: TimeOfDay(hour: 18, minute: 0),
                      ));
                    }),
                    onRemoveSlot: (slotIndex) => setState(() {
                      _slots[i]!.removeAt(slotIndex);
                    }),
                    onPickStart: (slotIndex) => _pickTime(i, slotIndex, isStart: true),
                    onPickEnd: (slotIndex) => _pickTime(i, slotIndex, isStart: false),
                  )),
                  const SizedBox(height: 24),
                ],
                ),
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

  Future<void> _pickTime(int dayIndex, int slotIndex, {required bool isStart}) async {
    final daySlots = _slots[dayIndex];
    if (daySlots == null || slotIndex >= daySlots.length) return;
    final current = daySlots[slotIndex];

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
      daySlots[slotIndex] = isStart
          ? current.copyWith(start: picked)
          : current.copyWith(end: picked);
    });
  }

  Future<void> _save() async {
    // Valida cada horário e evita sobreposição entre horários do mesmo dia
    for (final entry in _slots.entries) {
      final daySlots = entry.value;
      for (final sl in daySlots) {
        final startMins = sl.start.hour * 60 + sl.start.minute;
        final endMins = sl.end.hour * 60 + sl.end.minute;
        if (endMins <= startMins) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Horário inválido em ${_dayFullNames[entry.key]}: o fim deve ser após o início.'),
            backgroundColor: AppColors.error900,
          ));
          return;
        }
      }

      final sorted = [...daySlots]
        ..sort((a, b) =>
            (a.start.hour * 60 + a.start.minute).compareTo(b.start.hour * 60 + b.start.minute));
      for (var i = 1; i < sorted.length; i++) {
        final prevEnd = sorted[i - 1].end.hour * 60 + sorted[i - 1].end.minute;
        final curStart = sorted[i].start.hour * 60 + sorted[i].start.minute;
        if (curStart < prevEnd) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Horários sobrepostos em ${_dayFullNames[entry.key]}. Ajuste os intervalos.'),
            backgroundColor: AppColors.error900,
          ));
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final slots = _slots.entries
          .expand((e) => e.value.map((sl) => AvailabilitySlot(
                dayOfWeek: e.key,
                startTime: _formatTime(sl.start),
                endTime: _formatTime(sl.end),
              )))
          .toList()
        ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

      await ref.read(prestadorRepositoryProvider).updateAvailability(slots);
      ref.invalidate(prestadorProfileProvider);
      invalidateOwnProviderData(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agenda salva com sucesso!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Não foi possível salvar. Tente novamente.'),
          backgroundColor: AppColors.error900,
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
  final List<_DaySlot> daySlots;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAddSlot;
  final ValueChanged<int> onRemoveSlot;
  final ValueChanged<int> onPickStart;
  final ValueChanged<int> onPickEnd;

  const _DayRow({
    required this.dayIndex,
    required this.daySlots,
    required this.onToggle,
    required this.onAddSlot,
    required this.onRemoveSlot,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = daySlots.isNotEmpty;

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
              for (var i = 0; i < daySlots.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      const Text('Das', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      _TimeButton(
                        time: daySlots[i].start,
                        onTap: () => onPickStart(i),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('às', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ),
                      _TimeButton(
                        time: daySlots[i].end,
                        onTap: () => onPickEnd(i),
                      ),
                      if (daySlots.length > 1) ...[
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: Colors.grey[600],
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onRemoveSlot(i),
                        ),
                      ],
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton.icon(
                  onPressed: onAddSlot,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar horário'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
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
