import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spacenotes_theme.dart';

class CredentialField extends StatefulWidget {
  const CredentialField({
    super.key,
    required this.label,
    required this.controller,
    required this.editing,
    this.editable = true,
    this.obscurable = false,
    this.height = 48,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool editing;
  final bool editable;
  final bool obscurable;
  final double height;
  final VoidCallback? onChanged;

  @override
  State<CredentialField> createState() => _CredentialFieldState();
}

class _CredentialFieldState extends State<CredentialField> {
  late bool _hidden = widget.obscurable;

  @override
  Widget build(BuildContext context) {
    final active = widget.editing && widget.editable;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceNotesTheme.hairlineStrong),
      ),
      child: SizedBox(
        height: widget.height,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: SpaceNotesTheme.dim,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: widget.controller,
                    readOnly: !active,
                    obscureText: widget.obscurable && _hidden,
                    onChanged: (_) => widget.onChanged?.call(),
                    style: const TextStyle(
                      color: SpaceNotesTheme.fg,
                      fontSize: 14,
                      fontFamily: SpaceNotesTheme.fontMono,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.obscurable)
              _action(
                icon: _hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            if (!widget.editing)
              _action(
                icon: Icons.copy_outlined,
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: widget.controller.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.label} copied')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _action({required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, size: 18, color: SpaceNotesTheme.dim),
      onPressed: onPressed,
    );
  }
}
