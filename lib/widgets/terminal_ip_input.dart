import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

/// Terminal-styled input for IP address and port with a connect button.
class TerminalIPInput extends StatelessWidget {
  final TextEditingController ipController;
  final TextEditingController portController;
  final VoidCallback? onConnect;
  final String ipHint;
  final String portHint;
  final bool isConnecting;
  final double? maxWidth;

  const TerminalIPInput({
    super.key,
    required this.ipController,
    required this.portController,
    this.onConnect,
    this.ipHint = 'IP Address',
    this.portHint = 'Port',
    this.isConnecting = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : null,
      child: Row(
        children: [
          Expanded(child: _buildTerminalInput()),
          const SizedBox(width: 12),
          _buildConnectButton(),
        ],
      ),
    );
  }

  Widget _buildTerminalInput() {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: SpaceNotesTheme.primary,
            width: 2,
          ),
          right: BorderSide(
            color: SpaceNotesTheme.primary,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 12, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '❯',
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildEditableFields()),
        ],
      ),
    );
  }

  Widget _buildEditableFields() {
    return Row(
      children: [
        Flexible(
          flex: 3,
          child: TextField(
            controller: ipController,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.text,
              height: 1.4,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false,
              hintText: ipHint,
              hintStyle: const TextStyle(
                color: SpaceNotesTheme.textSecondary,
              ),
            ),
            maxLines: 1,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            ':',
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: TextField(
            controller: portController,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.text,
              height: 1.4,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false,
              hintText: portHint,
              hintStyle: const TextStyle(
                color: SpaceNotesTheme.textSecondary,
              ),
            ),
            maxLines: 1,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onConnect?.call(),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: SpaceNotesTheme.background,
        border: Border.all(
          color: SpaceNotesTheme.primary.withValues(alpha: 0.35),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: SpaceNotesTheme.primary.withValues(alpha: 0.1),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isConnecting ? null : onConnect,
          borderRadius: BorderRadius.circular(4),
          splashColor: SpaceNotesTheme.primary.withValues(alpha: 0.1),
          highlightColor: SpaceNotesTheme.primary.withValues(alpha: 0.05),
          child: Center(
            child: isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        SpaceNotesTheme.primary,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.link,
                    size: 18,
                    color: SpaceNotesTheme.primary,
                  ),
          ),
        ),
      ),
    );
  }
}
