import 'package:flutter/material.dart';
import '../theme/spacenotes_theme.dart';

class InstanceListItem extends StatelessWidget {
  final String name;
  final String ip;
  final String port;
  final bool isConnected;
  final VoidCallback onTap;
  final VoidCallback onConnectionTap;

  const InstanceListItem({
    super.key,
    required this.name,
    required this.ip,
    required this.port,
    required this.isConnected,
    required this.onTap,
    required this.onConnectionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: SpaceNotesTheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: SpaceNotesTheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'FiraCode',
                      fontSize: 14,
                      color: SpaceNotesTheme.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '$ip:$port',
                  style: const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 12,
                    color: SpaceNotesTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onConnectionTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isConnected
                              ? SpaceNotesTheme.primary
                              : SpaceNotesTheme.textSecondary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        isConnected ? Icons.link : Icons.link_off,
                        color: isConnected
                            ? SpaceNotesTheme.primary
                            : SpaceNotesTheme.textSecondary,
                        size: 20,
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
}

