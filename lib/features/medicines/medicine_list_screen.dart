import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/auth_api.dart';
import '../../core/demo_data.dart';
import '../../core/reminder_service.dart';
import '../../core/storage/offline_action_queue.dart';
import '../../core/utils/app_events.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

enum _MedicineViewState { content, empty, error, loading }

enum _SortBy { time, name }

enum _TimeFilter { morning, afternoon, evening }

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key, this.onAddTap});

  final VoidCallback? onAddTap;

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen>
    with AutomaticKeepAliveClientMixin {
  static List<Medicine> _cache = [];
  static DateTime? _cacheAt;

  final _api = ApiClient();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _selectedStatuses = <MedicineStatus>{
    MedicineStatus.taken,
    MedicineStatus.later,
    MedicineStatus.missed,
    MedicineStatus.pending,
  };
  final _selectedTimes = <_TimeFilter>{};

  var _sortBy = _SortBy.time;
  var _viewState = _MedicineViewState.loading;
  Timer? _refreshDebounce;
  String? _error;

  final _medicines = <Medicine>[];

  @override
  void initState() {
    super.initState();
    AppEvents.medicineChanged.addListener(_queueRefresh);
    if (_cache.isNotEmpty) {
      _medicines.addAll(_cache);
      _viewState = _MedicineViewState.content;
      if (_cacheIsStale) _queueRefresh();
    } else {
      _loadMedicines(showLoading: true);
    }
  }

  @override
  void dispose() {
    AppEvents.medicineChanged.removeListener(_queueRefresh);
    _refreshDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  bool get _cacheIsStale {
    final cached = _cacheAt;
    if (cached == null) return true;
    return DateTime.now().difference(cached) > const Duration(seconds: 45);
  }

  List<Medicine> get _visibleMedicines {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _medicines.where((medicine) {
      final matchesQuery =
          query.isEmpty || medicine.name.toLowerCase().contains(query);
      final matchesStatus = _selectedStatuses.contains(medicine.status);
      final matchesTime =
          _selectedTimes.isEmpty ||
          _selectedTimes.contains(_timeFilterFor(medicine.time));
      return matchesQuery && matchesStatus && matchesTime;
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortBy) {
        _SortBy.time => a.time.compareTo(b.time),
        _SortBy.name => a.name.compareTo(b.name),
      };
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dorilar ro'yxati"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _showFilterSheet,
            onLongPress: _cyclePreviewState,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 116),
          children: [
            _SearchField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: switch (_viewState) {
                _MedicineViewState.loading => const _SkeletonList(
                  key: ValueKey('loading'),
                ),
                _MedicineViewState.error => _ErrorState(
                  key: const ValueKey('error'),
                  message: _error,
                  onRetry: () => _loadMedicines(showLoading: true),
                ),
                _MedicineViewState.empty => _EmptyState(
                  key: const ValueKey('empty'),
                  onTap: widget.onAddTap ?? () {},
                ),
                _MedicineViewState.content => _MedicineContent(
                  key: const ValueKey('content'),
                  medicines: _visibleMedicines,
                  onAddTap: widget.onAddTap ?? () {},
                  onTap: (medicine) => Navigator.pushNamed(
                    context,
                    AppRoutes.details,
                    arguments: medicine.id,
                  ),
                  onStatusChanged: _updateStatus,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _queueRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadMedicines(showLoading: false),
    );
  }

  Future<void> _loadMedicines({bool showLoading = false}) async {
    if (showLoading || _medicines.isEmpty) {
      setState(() {
        _viewState = _MedicineViewState.loading;
        _error = null;
      });
    }
    try {
      await OfflineActionQueue.sync(api: _api);
      final items = await _api.getMedicines();
      unawaited(ReminderService.instance.syncFromMedicineMaps(items));
      if (!mounted) return;
      final medicines = items.map(Medicine.fromJson).toList();
      _cache = medicines;
      _cacheAt = DateTime.now();
      setState(() {
        _medicines
          ..clear()
          ..addAll(medicines);
        _viewState = _medicines.isEmpty
            ? _MedicineViewState.empty
            : _MedicineViewState.content;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.userMessage;
        if (_medicines.isEmpty) _viewState = _MedicineViewState.error;
      });
    }
  }

  Future<void> _updateStatus(Medicine medicine, MedicineStatus status) async {
    if (medicine.id != null &&
        medicine.scheduleId != null &&
        medicine.plannedAt != null) {
      try {
        switch (status) {
          case MedicineStatus.taken:
            await _api.markTaken(
              medicineId: medicine.id!,
              scheduleId: medicine.scheduleId!,
              plannedAt: medicine.plannedAt!,
            );
          case MedicineStatus.missed:
            await _api.markMissed(
              medicineId: medicine.id!,
              scheduleId: medicine.scheduleId!,
              plannedAt: medicine.plannedAt!,
            );
          case MedicineStatus.later:
            await _api.snooze(
              medicineId: medicine.id!,
              scheduleId: medicine.scheduleId!,
              plannedAt: medicine.plannedAt!,
              minutes: 10,
            );
          case MedicineStatus.pending:
            return;
        }
      } on AuthApiException catch (error) {
        if (error.kind == AuthApiErrorKind.network ||
            error.kind == AuthApiErrorKind.server) {
          await OfflineActionQueue.enqueue(
            medicineId: medicine.id!,
            scheduleId: medicine.scheduleId!,
            plannedAt: medicine.plannedAt!,
            action: switch (status) {
              MedicineStatus.taken => 'taken',
              MedicineStatus.missed => 'missed',
              MedicineStatus.later => 'snooze',
              MedicineStatus.pending => 'pending',
            },
            minutes: status == MedicineStatus.later ? 10 : null,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Internet yo‘q. Amal offline saqlandi.'),
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.userMessage)));
          return;
        }
      }
    }

    final index = _medicines.indexOf(medicine);
    if (index == -1) return;
    setState(() {
      final updated = medicine.copyWith(status: status);
      _medicines[index] = updated;
      final cacheIndex = _cache.indexWhere(
        (item) =>
            item.id == medicine.id &&
            item.scheduleId == medicine.scheduleId &&
            item.plannedAt == medicine.plannedAt,
      );
      if (cacheIndex != -1) _cache[cacheIndex] = updated;
    });
    HapticFeedback.selectionClick();
  }

  void _cyclePreviewState() {
    _loadMedicines(showLoading: true);
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void toggleStatus(MedicineStatus status) {
              setState(() {
                if (_selectedStatuses.contains(status)) {
                  _selectedStatuses.remove(status);
                } else {
                  _selectedStatuses.add(status);
                }
              });
              setSheetState(() {});
            }

            void setSort(_SortBy sortBy) {
              setState(() => _sortBy = sortBy);
              setSheetState(() {});
            }

            void toggleTime(_TimeFilter value) {
              setState(() {
                if (_selectedTimes.contains(value)) {
                  _selectedTimes.remove(value);
                } else {
                  _selectedTimes.add(value);
                }
              });
              setSheetState(() {});
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  6,
                  16,
                  28 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Filtr',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FilterStatusTile(
                      status: MedicineStatus.pending,
                      selected: _selectedStatuses.contains(
                        MedicineStatus.pending,
                      ),
                      onTap: () => toggleStatus(MedicineStatus.pending),
                    ),
                    _FilterStatusTile(
                      status: MedicineStatus.taken,
                      selected: _selectedStatuses.contains(
                        MedicineStatus.taken,
                      ),
                      onTap: () => toggleStatus(MedicineStatus.taken),
                    ),
                    _FilterStatusTile(
                      status: MedicineStatus.missed,
                      selected: _selectedStatuses.contains(
                        MedicineStatus.missed,
                      ),
                      onTap: () => toggleStatus(MedicineStatus.missed),
                    ),
                    const Divider(height: 24),
                    Text(
                      'Kun vaqti',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _TimeChip(
                          label: 'ertalab',
                          selected: _selectedTimes.contains(
                            _TimeFilter.morning,
                          ),
                          onTap: () => toggleTime(_TimeFilter.morning),
                        ),
                        _TimeChip(
                          label: 'tush',
                          selected: _selectedTimes.contains(
                            _TimeFilter.afternoon,
                          ),
                          onTap: () => toggleTime(_TimeFilter.afternoon),
                        ),
                        _TimeChip(
                          label: 'kechqurun',
                          selected: _selectedTimes.contains(
                            _TimeFilter.evening,
                          ),
                          onTap: () => toggleTime(_TimeFilter.evening),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Saralash',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _SortTile(
                      label: 'Vaqt',
                      selected: _sortBy == _SortBy.time,
                      onTap: () => setSort(_SortBy.time),
                    ),
                    _SortTile(
                      label: 'Nomi',
                      selected: _sortBy == _SortBy.name,
                      onTap: () => setSort(_SortBy.name),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  _TimeFilter _timeFilterFor(String value) {
    final hour = int.tryParse(value.split(':').first) ?? 0;
    if (hour < 12) return _TimeFilter.morning;
    if (hour < 18) return _TimeFilter.afternoon;
    return _TimeFilter.evening;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(13)),
        boxShadow: AppColors.softShadow,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 28),
          hintText: 'Dori nomini qidirish...',
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 14,
          ),
        ),
      ),
    );
  }
}

class _MedicineContent extends StatelessWidget {
  const _MedicineContent({
    super.key,
    required this.medicines,
    required this.onAddTap,
    required this.onTap,
    required this.onStatusChanged,
  });

  final List<Medicine> medicines;
  final VoidCallback onAddTap;
  final void Function(Medicine medicine) onTap;
  final void Function(Medicine medicine, MedicineStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    if (medicines.isEmpty) {
      return _EmptyState(onTap: onAddTap);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...medicines.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AnimatedListItem(
              index: entry.key,
              child: _MedicineCard(
                medicine: entry.value,
                onTap: () => onTap(entry.value),
                onTaken: () =>
                    onStatusChanged(entry.value, MedicineStatus.taken),
                onMissed: () =>
                    onStatusChanged(entry.value, MedicineStatus.missed),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.onTap,
    required this.onTaken,
    required this.onMissed,
  });

  final Medicine medicine;
  final VoidCallback onTap;
  final VoidCallback onTaken;
  final VoidCallback onMissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${medicine.name}-${medicine.time}-${medicine.status}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onTaken();
        } else {
          onMissed();
        }
        return false;
      },
      background: const _SwipeAction(
        alignment: Alignment.centerLeft,
        color: AppColors.primary,
        icon: Icons.check,
        label: 'Ichdim',
      ),
      secondaryBackground: const _SwipeAction(
        alignment: Alignment.centerRight,
        color: AppColors.error,
        icon: Icons.close,
        label: "O'tkazdim",
      ),
      child: AppCard(
        onTap: onTap,
        radius: 9,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            _MedicineThumb(imageUrl: medicine.imageUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    medicine.time,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _StatusBadge(status: medicine.status),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final MedicineStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: statusColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            statusLabel(status),
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedListItem extends StatelessWidget {
  const _AnimatedListItem({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 45),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _MedicineFallback extends StatelessWidget {
  const _MedicineFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.medication_outlined,
        color: AppColors.primary,
        size: 24,
      ),
    );
  }
}

class _MedicineThumb extends StatelessWidget {
  const _MedicineThumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final value = imageUrl?.trim() ?? '';
    if (value.isEmpty) return const _MedicineFallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: value.startsWith('http://') || value.startsWith('https://')
          ? Image.network(
              value,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _MedicineFallback(),
            )
          : Image.file(
              File(value),
              width: 42,
              height: 42,
              cacheWidth: 84,
              cacheHeight: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _MedicineFallback(),
            ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterStatusTile extends StatelessWidget {
  const _FilterStatusTile({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final MedicineStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: statusColor(status),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                selected ? Icons.check : statusIcon(status),
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              statusLabel(status),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: selected
          ? const Icon(Icons.check, size: 15, color: AppColors.primary)
          : null,
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.35)
            : Colors.transparent,
      ),
      backgroundColor: selected
          ? AppColors.successSoft
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected
            ? AppColors.primary
            : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  const _SortTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        selected ? Icons.check : Icons.sort,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 430,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 134,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 92,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: const Icon(
                    Icons.medication_liquid_outlined,
                    color: AppColors.primary,
                    size: 42,
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 18,
                  child: Icon(
                    Icons.medication,
                    color: AppColors.primary.withValues(alpha: 0.85),
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Hozircha dori qo‘shilmagan",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 132,
            child: AppButton(
              label: "Dori qo'shish",
              onPressed: onTap,
              expand: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 430,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_rounded, color: AppColors.error, size: 76),
          const SizedBox(height: 16),
          Text(
            'Xatolik yuz berdi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: 132,
            child: AppButton(
              label: 'Qayta urinish',
              onPressed: onRetry,
              expand: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: AppCard(
            radius: 12,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _SkeletonBox(width: 48, height: 48, radius: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SkeletonBox(
                        width: double.infinity,
                        height: 12,
                        radius: 8,
                      ),
                      SizedBox(height: 7),
                      _SkeletonBox(width: 150, height: 10, radius: 8),
                      SizedBox(height: 7),
                      _SkeletonBox(width: 190, height: 8, radius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _SkeletonBox(width: 58, height: 24, radius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
