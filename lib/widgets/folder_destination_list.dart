import 'package:flutter/material.dart';

import '../search/file_search.dart';
import '../theme/spacenotes_theme.dart';

/// One selectable destination in a move dialog.
class FolderDestination {
  const FolderDestination({
    required this.path,
    required this.label,
    required this.onTap,
    this.isCurrent = false,
    this.currentLabel,
    this.icon,
    this.currentIcon,
  });

  /// The path matched against the search query. A destination that stands for
  /// somewhere other than a folder row (the top level) can use any stable
  /// string; it is what the user types to find it.
  final String path;
  final String label;
  final VoidCallback onTap;

  /// Where the moved item already lives. Shown, but not selectable.
  final bool isCurrent;
  final String? currentLabel;
  final IconData? icon;
  final IconData? currentIcon;
}

/// The destination list shared by the move-note and move-folder dialogs.
///
/// Both dialogs previously carried their own copy of this list, which is how
/// the credential filter ended up applied to neither.
class FolderDestinationList extends StatefulWidget {
  const FolderDestinationList({super.key, required this.destinations});

  final List<FolderDestination> destinations;

  @override
  State<FolderDestinationList> createState() => _FolderDestinationListState();
}

class _FolderDestinationListState extends State<FolderDestinationList> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = searchAndRankFolderPaths(
      widget.destinations,
      searchTerms(_query),
      (d) => d.path,
      (d) => d.label,
    );

    return SizedBox(
      width: double.maxFinite,
      height: MediaQuery.sizeOf(context).height * 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: matches.isEmpty
                ? const Center(
                    child: Text(
                      'No folders match',
                      style: TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 13,
                        color: SpaceNotesTheme.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) =>
                        _DestinationTile(destination: matches[index]),
                  ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('folder-search'),
            controller: _controller,
            autofocus: true,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: SpaceNotesTheme.text,
            ),
            decoration: InputDecoration(
              hintText: 'Search folders',
              hintStyle: const TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 14,
                color: SpaceNotesTheme.textSecondary,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: SpaceNotesTheme.textSecondary,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 0,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : GestureDetector(
                      key: const ValueKey('folder-search-clear'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: SpaceNotesTheme.textSecondary,
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 0,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination});

  final FolderDestination destination;

  @override
  Widget build(BuildContext context) {
    final isCurrent = destination.isCurrent;
    // A folder's own name is rarely unique - "Masters" exists under several
    // parents - so the parent path is shown whenever there is one.
    final parent = destination.path.contains('/')
        ? destination.path.substring(0, destination.path.lastIndexOf('/'))
        : null;
    final subtitle = isCurrent ? destination.currentLabel : parent;

    return ListTile(
      dense: true,
      leading: Icon(
        isCurrent
            ? (destination.currentIcon ?? Icons.folder)
            : (destination.icon ?? Icons.folder_outlined),
        color: isCurrent ? SpaceNotesTheme.textSecondary : SpaceNotesTheme.text,
      ),
      title: Text(
        destination.label,
        style: TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 14,
          color:
              isCurrent ? SpaceNotesTheme.textSecondary : SpaceNotesTheme.text,
          fontStyle: isCurrent ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 11,
                color: SpaceNotesTheme.textSecondary,
              ),
            ),
      enabled: !isCurrent,
      onTap: isCurrent ? null : destination.onTap,
    );
  }
}
