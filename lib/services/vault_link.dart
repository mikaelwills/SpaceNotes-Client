sealed class VaultLink {
  const VaultLink();
}

class FileLink extends VaultLink {
  const FileLink(this.id);
  final String id;
}

class FolderLink extends VaultLink {
  const FolderLink(this.path);
  final String path;
}

class WebLink extends VaultLink {
  const WebLink(this.uri);
  final Uri uri;
}

class UnknownLink extends VaultLink {
  const UnknownLink();
}

const vaultLinkScheme = 'spacenotes';

VaultLink parseVaultLink(String href) {
  final uri = Uri.tryParse(href.trim());
  if (uri == null) return const UnknownLink();

  if (uri.scheme == vaultLinkScheme) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return const UnknownLink();
    switch (uri.host) {
      case 'file':
        return segments.length == 1 ? FileLink(segments.single) : const UnknownLink();
      case 'folder':
        return FolderLink(segments.join('/'));
    }
    return const UnknownLink();
  }

  if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
    return WebLink(uri);
  }
  return const UnknownLink();
}
