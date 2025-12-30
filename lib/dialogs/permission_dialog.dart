import 'package:flutter/material.dart';
import '../models/permission_request.dart';
import '../theme/spacenotes_theme.dart';

/// Dialog for requesting user permission for potentially dangerous operations
class PermissionDialog extends StatelessWidget {
  final PermissionRequest permission;

  const PermissionDialog({
    super.key,
    required this.permission,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SpaceNotesTheme.dialogSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: permission.isDangerous ? SpaceNotesTheme.error : SpaceNotesTheme.primaryMuted,
          width: 1,
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildDescription(),
            const SizedBox(height: 24),
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          permission.isDangerous ? Icons.warning_amber_rounded : Icons.lock_outline,
          color: permission.isDangerous ? SpaceNotesTheme.error : SpaceNotesTheme.primary,
          size: 28,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Permission Required',
            style: TextStyle(
              color: SpaceNotesTheme.text,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          permission.title,
          style: const TextStyle(
            color: SpaceNotesTheme.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          permission.description,
          style: const TextStyle(
            color: SpaceNotesTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        if (permission.isDangerous) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SpaceNotesTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: SpaceNotesTheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: SpaceNotesTheme.error,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This operation may modify or delete files. Please review carefully.',
                    style: TextStyle(
                      color: SpaceNotesTheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Permission Type: ${_formatPermissionType(permission.type)}',
          style: const TextStyle(
            color: SpaceNotesTheme.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildButton(
                context,
                label: 'Deny',
                response: PermissionResponse.reject,
                icon: Icons.block,
                color: SpaceNotesTheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildButton(
                context,
                label: 'Allow Once',
                response: PermissionResponse.once,
                icon: Icons.check,
                color: SpaceNotesTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildButton(
          context,
          label: 'Always Allow',
          response: PermissionResponse.always,
          icon: Icons.check_circle,
          color: SpaceNotesTheme.success,
          secondary: true,
        ),
      ],
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String label,
    required PermissionResponse response,
    required IconData icon,
    required Color color,
    bool secondary = false,
  }) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pop(response),
      style: ElevatedButton.styleFrom(
        backgroundColor: secondary ? color.withValues(alpha: 0.1) : color,
        foregroundColor: secondary ? color : SpaceNotesTheme.background,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: secondary
              ? BorderSide(color: color, width: 1.5)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPermissionType(String type) {
    switch (type) {
      case 'bash':
        return 'Shell Command';
      case 'edit':
        return 'File Edit';
      case 'write':
        return 'File Write';
      case 'webfetch':
        return 'Web Request';
      case 'doom_loop':
        return 'Loop Protection';
      case 'external_directory':
        return 'External Directory Access';
      default:
        return type;
    }
  }

  /// Show the permission dialog and return the user's response
  static Future<PermissionResponse?> show(
    BuildContext context,
    PermissionRequest permission,
  ) {
    return showDialog<PermissionResponse>(
      context: context,
      barrierDismissible: false, // User must explicitly choose
      builder: (context) => PermissionDialog(permission: permission),
    );
  }
}
