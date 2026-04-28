import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/auth_api.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _api = ApiClient();
  final _members = <_FamilyMember>[];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Oila a'zolari"),
        actions: [
          IconButton(
            onPressed: _showAddMemberSheet,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Text(
              'Dorilarni birgalikda nazorat qiling',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              TextButton(onPressed: _loadMembers, child: Text(_error!))
            else if (_members.isEmpty)
              _FamilyEmptyState(onAdd: _showAddMemberSheet)
            else
              ..._members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Dismissible(
                    key: ValueKey(member.id ?? member.name),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      await _deleteMember(member);
                      return false;
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 22),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: _MemberCard(
                      member: member,
                      onTap: () => _showMemberDetail(member),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _FamilyOverview(memberCount: _members.length),
          ],
        ),
      ),
    );
  }

  void _showAddMemberSheet() {
    _showMemberForm();
  }

  void _showMemberForm({_FamilyMember? member}) {
    final nameController = TextEditingController();
    nameController.text = member?.name ?? '';
    var relationship = member?.relation.isNotEmpty == true
        ? member!.relation
        : 'Boshqa';
    var avatarColor = member?.hexColor ?? '#16a34a';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  member == null ? "Oila a'zosi qo'shish" : 'Tahrirlash',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 18),
              const Text('Ism', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Masalan: Onam'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Qarindoshlik',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: relationship,
                items: const ['Boshqa', 'Ona', 'Ota', 'Bola', 'Turmush o‘rtoq']
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setSheetState(() => relationship = value ?? 'Boshqa'),
              ),
              const SizedBox(height: 14),
              const Text('Rang', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                children:
                    ['#16a34a', '#E9933B', '#43B7C1', '#8567D8', '#475569']
                        .map(
                          (hex) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () =>
                                  setSheetState(() => avatarColor = hex),
                              child: CircleAvatar(
                                radius: avatarColor == hex ? 21 : 18,
                                backgroundColor: _FamilyMember._colorFrom(hex),
                                child: avatarColor == hex
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 18),
              AppButton(
                label: member == null ? "Qo'shish" : 'Saqlash',
                onPressed: () => member == null
                    ? _createMember(
                        nameController.text.trim(),
                        relationship,
                        avatarColor,
                      )
                    : _updateMember(
                        member,
                        nameController.text.trim(),
                        relationship,
                        avatarColor,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getFamilyMembers();
      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(items.map(_FamilyMember.fromJson));
      });
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createMember(
    String fullName,
    String relationship,
    String avatarColor,
  ) async {
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ism kiriting')));
      return;
    }
    try {
      await _api.createFamilyMember(
        fullName: fullName,
        relationship: relationship,
        avatarColor: avatarColor,
      );
      if (mounted) Navigator.pop(context);
      await _loadMembers();
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteMember(_FamilyMember member) async {
    if (member.id == null) return;
    try {
      await _api.deleteFamilyMember(member.id!);
      if (mounted) setState(() => _members.remove(member));
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _updateMember(
    _FamilyMember member,
    String fullName,
    String relationship,
    String avatarColor,
  ) async {
    if (member.id == null || fullName.isEmpty) return;
    try {
      await _api.updateFamilyMember(
        memberId: member.id!,
        fullName: fullName,
        relationship: relationship,
        avatarColor: avatarColor,
      );
      if (mounted) Navigator.pop(context);
      await _loadMembers();
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  void _showMemberDetail(_FamilyMember member) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: member.color,
              child: Text(
                member.initials,
                style: const TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              member.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              member.relation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MemberStat(
                    value: '${member.takenCount}',
                    label: 'Taken',
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _MemberStat(
                    value: '${member.missedCount}',
                    label: 'Missed',
                    color: AppColors.error,
                  ),
                ),
                Expanded(
                  child: _MemberStat(
                    value: '${member.pendingCount}',
                    label: 'Pending',
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniAction(
                    icon: Icons.add,
                    label: "Dori qo'shish",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        AppRoutes.addMedicine,
                        arguments: member.id,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _MiniAction(
                    icon: Icons.edit_outlined,
                    label: 'Tahrirlash',
                    onTap: () {
                      Navigator.pop(context);
                      _showMemberForm(member: member);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyMember {
  const _FamilyMember({
    this.id,
    required this.name,
    required this.relation,
    required this.initials,
    required this.color,
    required this.hexColor,
    required this.takenCount,
    required this.missedCount,
    required this.pendingCount,
  });
  final int? id;
  final String name;
  final String relation;
  final String initials;
  final Color color;
  final String hexColor;
  final int takenCount;
  final int missedCount;
  final int pendingCount;

  factory _FamilyMember.fromJson(Map<String, dynamic> json) {
    final name = (json['full_name'] ?? '').toString();
    return _FamilyMember(
      id: int.tryParse((json['id'] ?? '').toString()),
      name: name,
      relation: (json['relationship'] ?? '').toString(),
      initials: _initials(name),
      color: _colorFrom((json['avatar_color'] ?? '#16a34a').toString()),
      hexColor: (json['avatar_color'] ?? '#16a34a').toString(),
      takenCount: _int(json['taken_count']),
      missedCount: _int(json['missed_count']),
      pendingCount: _int(json['pending_count']),
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '??';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  static Color _colorFrom(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.tryParse('FF$value', radix: 16) ?? 0xFF16A34A);
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});
  final _FamilyMember member;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    radius: 16,
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: member.color,
              child: Text(
                member.initials,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    member.relation,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TinyStat(
                  icon: Icons.check,
                  color: AppColors.primary,
                  text: '${member.takenCount}',
                ),
                _TinyStat(
                  icon: Icons.close,
                  color: AppColors.error,
                  text: '${member.missedCount}',
                ),
                _TinyStat(
                  icon: Icons.alarm,
                  color: Theme.of(context).colorScheme.onSurface,
                  text: '${member.pendingCount}',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            color: AppColors.primary,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    ),
  );

  double get _progress {
    final total = member.takenCount + member.missedCount + member.pendingCount;
    return total == 0 ? 0 : member.takenCount / total;
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

class _MemberStat extends StatelessWidget {
  const _MemberStat({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(label),
    ],
  );
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FamilyOverview extends StatelessWidget {
  const _FamilyOverview({required this.memberCount});

  final int memberCount;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Family Overview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text("Oila a'zolari: $memberCount"),
              const SizedBox(height: 6),
              const Text('Dorilar va bajarilish holati API orqali yangilanadi'),
            ],
          ),
        ),
        SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: memberCount == 0 ? 0 : 1,
                strokeWidth: 7,
                color: AppColors.primary,
                backgroundColor: AppColors.border,
              ),
              Text(
                '$memberCount',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FamilyEmptyState extends StatelessWidget {
  const _FamilyEmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 18,
    child: Column(
      children: [
        const Icon(Icons.family_restroom, size: 78, color: AppColors.primary),
        const SizedBox(height: 14),
        Text(
          "Oila a’zolari qo‘shilmagan",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        AppButton(label: "Qo'shish", onPressed: onAdd, expand: false),
      ],
    ),
  );
}
