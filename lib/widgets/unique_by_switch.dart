// lib/widgets/unique_by_switch.dart
import 'package:flutter/material.dart';

enum UniqueBy { user, comment, both }

class UniqueBySwitch extends StatelessWidget {
  final UniqueBy value;
  final ValueChanged<UniqueBy> onChanged;

  const UniqueBySwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _chip(context, UniqueBy.user, 'User'),
        _chip(context, UniqueBy.comment, 'Comment'),
        _chip(context, UniqueBy.both, 'Both'),
      ],
    );
  }

  Widget _chip(BuildContext context, UniqueBy me, String label) {
    final selected = value == me;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(me),
    );
  }
}
