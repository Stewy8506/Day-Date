/// Bottom sheet modal for creating and editing floating task targets / goals.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/domain/entities/task_target.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

class EditTargetSheet extends ConsumerStatefulWidget {
  final TaskTarget? target; // Null if creating new

  const EditTargetSheet({super.key, this.target});

  static Future<void> show(BuildContext context, {TaskTarget? target}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditTargetSheet(target: target),
    );
  }

  @override
  ConsumerState<EditTargetSheet> createState() => _EditTargetSheetState();
}

class _EditTargetSheetState extends ConsumerState<EditTargetSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late double _weeklyHours;
  late int _priority;
  late TimeAffinity _affinity;
  late double _dailyCapHours;
  bool _isSaving = false;

  bool get _isEditing => widget.target != null;

  @override
  void initState() {
    super.initState();
    final t = widget.target;
    _nameController = TextEditingController(text: t?.name ?? '');
    _weeklyHours = t?.weeklyHours ?? 10.0;
    _priority = t?.priority ?? 1;
    _affinity = t?.affinity ?? TimeAffinity.afternoon;
    _dailyCapHours = t?.dailyCapHours ?? 3.0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _adjustWeeklyHours(double delta) {
    setState(() {
      _weeklyHours = (_weeklyHours + delta).clamp(1.0, 50.0);
      // Round to 1 decimal place to prevent floating point drift
      _weeklyHours = double.parse(_weeklyHours.toStringAsFixed(1));
    });
  }

  void _adjustDailyCap(double delta) {
    setState(() {
      _dailyCapHours = (_dailyCapHours + delta).clamp(0.5, 12.0);
      _dailyCapHours = double.parse(_dailyCapHours.toStringAsFixed(1));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final target = TaskTarget(
      id: widget.target?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      weeklyHours: _weeklyHours,
      priority: _priority,
      affinity: _affinity,
      dailyCapHours: _dailyCapHours,
    );

    if (_isEditing) {
      await ref.read(updateTaskTargetProvider)(target);
    } else {
      await ref.read(addTaskTargetProvider)(target);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    if (widget.target == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Goal', style: AppTypography.cardTitle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to remove "${widget.target!.name}" from your weekly schedule?',
          style: AppTypography.body(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTypography.caption(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AppTypography.caption(color: AppColors.accentTerracotta)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSaving = true);
      await ref.read(removeTaskTargetProvider)(widget.target!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Drag Handle ─────────────────────────
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Header Title & Actions ───────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditing ? 'Edit Goal Target' : 'Add New Goal',
                      style: AppTypography.cardTitle(color: AppColors.textPrimary),
                    ),
                    if (_isEditing)
                      Tactile(
                        onTap: _isSaving ? null : _delete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete_outline, size: 14, color: AppColors.accentTerracotta),
                              const SizedBox(width: 4),
                              Text(
                                'Delete',
                                style: AppTypography.caption(color: AppColors.accentTerracotta).copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Goal Name ────────────────────────────
                Text('GOAL / ACTIVITY NAME', style: AppTypography.overline(color: AppColors.textTertiary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: AppTypography.body(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. SWE Roadmap, CAT Prep, Gym...',
                    hintStyle: AppTypography.body(color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.surfaceBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.textSecondary),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter a goal name';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Weekly Target Hours ──────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('WEEKLY TARGET HOURS', style: AppTypography.overline(color: AppColors.textTertiary)),
                    Text(
                      '${_weeklyHours.toStringAsFixed(1)} hrs/week',
                      style: AppTypography.monoNumber(fontSize: 15, color: AppColors.accentWarm),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStepperBtn(
                      label: '-1h',
                      onTap: () => _adjustWeeklyHours(-1.0),
                    ),
                    const SizedBox(width: 6),
                    _buildStepperBtn(
                      label: '-0.5h',
                      onTap: () => _adjustWeeklyHours(-0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Center(
                          child: Text(
                            '${_weeklyHours.toStringAsFixed(1)}h',
                            style: AppTypography.monoNumber(fontSize: 18, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStepperBtn(
                      label: '+0.5h',
                      onTap: () => _adjustWeeklyHours(0.5),
                    ),
                    const SizedBox(width: 6),
                    _buildStepperBtn(
                      label: '+1h',
                      onTap: () => _adjustWeeklyHours(1.0),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Priority ─────────────────────────────
                Text('PRIORITY LEVEL', style: AppTypography.overline(color: AppColors.textTertiary)),
                const SizedBox(height: 8),
                Row(
                  children: [1, 2, 3, 4].map((p) {
                    final isSelected = _priority == p;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: p < 4 ? 8 : 0),
                        child: Tactile(
                          onTap: () => setState(() => _priority = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.surfaceElevated : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppColors.accentWarm : AppColors.surfaceBorder,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'P$p',
                                style: AppTypography.cardTitle(
                                  color: isSelected ? AppColors.accentWarm : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── Preferred Time Window (Affinity) ─────
                Text('TIME-OF-DAY PREFERENCE', style: AppTypography.overline(color: AppColors.textTertiary)),
                const SizedBox(height: 8),
                Column(
                  children: [
                    _buildAffinityOption(
                      title: 'Morning Window',
                      subtitle: '7:30 AM – 12:00 PM',
                      affinity: TimeAffinity.morning,
                      icon: Icons.wb_sunny_outlined,
                    ),
                    const SizedBox(height: 6),
                    _buildAffinityOption(
                      title: 'Afternoon Window',
                      subtitle: '12:00 PM – 7:00 PM',
                      affinity: TimeAffinity.afternoon,
                      icon: Icons.wb_twilight_outlined,
                    ),
                    const SizedBox(height: 6),
                    _buildAffinityOption(
                      title: 'Late Night Window',
                      subtitle: '9:30 PM – 12:00 AM',
                      affinity: TimeAffinity.lateNight,
                      icon: Icons.nightlight_outlined,
                    ),
                    const SizedBox(height: 6),
                    _buildAffinityOption(
                      title: 'Flexible Window',
                      subtitle: 'Fits freely anywhere in open slots',
                      affinity: TimeAffinity.flexible,
                      icon: Icons.all_inclusive,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Daily Cap Hours ──────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DAILY CAP (OPTIONAL)', style: AppTypography.overline(color: AppColors.textTertiary)),
                    Text(
                      '${_dailyCapHours.toStringAsFixed(1)} hrs/day',
                      style: AppTypography.monoNumber(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStepperBtn(
                      label: '-0.5h',
                      onTap: () => _adjustDailyCap(-0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Center(
                          child: Text(
                            'Max ${_dailyCapHours.toStringAsFixed(1)}h/day',
                            style: AppTypography.caption(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStepperBtn(
                      label: '+0.5h',
                      onTap: () => _adjustDailyCap(0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Save Button ──────────────────────────
                Tactile(
                  onTap: _isSaving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.accentWarm,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2),
                            )
                          : Text(
                              _isEditing ? 'Save Changes' : 'Create Goal Target',
                              style: AppTypography.cardTitle(color: AppColors.background),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepperBtn({required String label, required VoidCallback onTap}) {
    return Tactile(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(
          label,
          style: AppTypography.monoNumber(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildAffinityOption({
    required String title,
    required String subtitle,
    required TimeAffinity affinity,
    required IconData icon,
  }) {
    final isSelected = _affinity == affinity;

    return Tactile(
      onTap: () => setState(() => _affinity = affinity),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accentWarm : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.accentWarm : AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.caption(
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption(color: AppColors.textDisabled).copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 16, color: AppColors.accentWarm),
          ],
        ),
      ),
    );
  }
}
