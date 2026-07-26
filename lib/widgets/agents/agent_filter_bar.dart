import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_providers.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';

class AgentFilterBar extends ConsumerStatefulWidget {
  const AgentFilterBar({super.key});

  @override
  ConsumerState<AgentFilterBar> createState() => _AgentFilterBarState();
}

class _AgentFilterBarState extends ConsumerState<AgentFilterBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(agentFilterProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: SpaceNotesTheme.hairline, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                cursorColor: SpaceNotesTheme.accent,
                cursorWidth: 1.5,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontMono,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: SpaceNotesTheme.fg,
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: 'filter agents',
                  hintStyle: TextStyle(
                    fontFamily: SpaceNotesTheme.fontMono,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: SpaceNotesTheme.dim,
                  ),
                ),
                onChanged: (v) =>
                    ref.read(agentFilterProvider.notifier).state = v,
              ),
            ),
            if (query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  ref.read(agentFilterProvider.notifier).state = '';
                  _focusNode.requestFocus();
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: SnMicroLabel('clear', fontSize: 9),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
