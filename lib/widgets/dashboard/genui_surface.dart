import 'package:flutter/material.dart';
import '../../services/genui_note_parser.dart';
import '../../services/json_pointer.dart';
import '../../theme/spacenotes_theme.dart';
import '../adaptive/platform_utils.dart';
import '../primitives/primitives.dart';
import '../quill_note_editor.dart';
import 'action_widgets.dart';
import 'chart_widgets.dart';
import 'input_widgets.dart';
import 'kpi_widgets.dart';
import 'layout_widgets.dart';
import 'list_widgets.dart';
import 'status_widgets.dart';

/// Renders a generative-UI note body.
///
/// Takes the full note body string (which must contain a `genui` fenced block
/// at the top) and an `onBodyChanged` callback. Owns the parsed schema +
/// markdown in memory; mutations from interactive widgets route back through
/// the callback as a freshly-serialized body. Persistence/debounce belongs
/// to the parent (NoteScreen).
///
/// Supports both schema shapes:
///   * Flat A2UI-style (components keyed by `id`, `rootId` entry point,
///     `{"path": "/..."}` JSON Pointer bindings)
///   * Legacy nested (components with inline children, `valueBinding: "key"`
///     bindings against `data` map)
class GenuiSurface extends StatefulWidget {
  final String body;
  final ValueChanged<String> onBodyChanged;

  const GenuiSurface({
    super.key,
    required this.body,
    required this.onBodyChanged,
  });

  @override
  State<GenuiSurface> createState() => _GenuiSurfaceState();
}

class _GenuiSurfaceState extends State<GenuiSurface> {
  late Map<String, dynamic> _schema;
  late String _markdown;
  final GlobalKey<QuillNoteEditorState> _markdownEditorKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ingest(widget.body);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GenuiSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      final reSerialized = GenuiNoteParser.serialize(
        GenuiNote(schema: _schema, markdown: _markdown),
      );
      if (reSerialized != widget.body) {
        _ingest(widget.body);
        _markdownEditorKey.currentState?.updateContent(_markdown);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = _renderRootChildren();
    final isDesktop = PlatformUtils.isDesktopLayout(context);
    final sidePad = isDesktop ? 32.0 : 16.0;
    final topPad = isDesktop ? 32.0 : 16.0;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (children.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(sidePad, topPad, sidePad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final child in children) ...[
                    child,
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 12),
                  const SnHairline(),
                ],
              ),
            ),
          QuillNoteEditor(
            key: _markdownEditorKey,
            initialContent: _markdown,
            showToolbar: false,
            scrollable: false,
            onContentChanged: _onMarkdownChanged,
          ),
        ],
      ),
    );
  }

  List<Widget> _renderRootChildren() {
    final components = _schema['components'];
    if (components is! List) return const [];

    if (GenuiNoteParser.isFlat(_schema)) {
      final rootId = _schema['rootId'];
      Map<String, dynamic>? root;
      if (rootId is String) {
        root = _findById(components, rootId);
      } else {
        final first = components.isNotEmpty ? components.first : null;
        if (first is Map) {
          root = Map<String, dynamic>.from(first);
        }
      }
      if (root == null) return const [];
      final childIds = root['children'];
      if (childIds is! List) {
        return [_renderById(_idOf(root))];
      }
      return [
        for (final id in childIds)
          if (id is String) _renderById(id),
      ];
    }

    final out = <Widget>[];
    for (var i = 0; i < components.length; i++) {
      final c = components[i];
      if (c is Map) out.add(_renderLegacy(c, legacyIndex: i));
    }
    return out;
  }

  Map<String, dynamic>? _findById(List components, String id) {
    for (final c in components) {
      if (c is Map && c['id'] == id) {
        return Map<String, dynamic>.from(c);
      }
    }
    return null;
  }

  String _idOf(Map component) {
    final id = component['id'];
    return id is String ? id : '';
  }

  Widget _renderById(String id) {
    final components = _schema['components'];
    if (components is! List) return _unknown('no components list');
    final found = _findById(components, id);
    if (found == null) return _unknown('component id "$id" not found');
    return _renderComponent(found, id: id, isFlat: true);
  }

  Widget _renderLegacy(Map raw, {required int legacyIndex}) {
    return _renderComponent(raw, legacyIndex: legacyIndex, isFlat: false);
  }

  /// Single component renderer. In flat mode children are ID strings;
  /// in legacy mode children are inline objects.
  Widget _renderComponent(
    Map raw, {
    String? id,
    int? legacyIndex,
    required bool isFlat,
  }) {
    final typeRaw = raw['component'];
    if (typeRaw is! String) return _unknown('missing "component" key');
    final type = typeRaw;

    String str(String k, [String fallback = '']) {
      final v = raw[k];
      return v is String ? v : fallback;
    }

    String? strOrNull(String k) {
      final v = raw[k];
      return v is String ? v : null;
    }

    bool flag(String k, [bool fallback = false]) {
      final v = raw[k];
      return v is bool ? v : fallback;
    }

    double? numOrNull(String k) {
      final v = raw[k];
      return v is num ? v.toDouble() : null;
    }

    /// Read a field that may be a literal or a binding `{"path": "/..."}`.
    /// In legacy mode the field is always a literal.
    String boundString(String k, [String fallback = '']) {
      final v = raw[k];
      if (v is String) return v;
      if (isFlat && v is Map) {
        final path = v['path'];
        if (path is String) {
          final resolved = JsonPointer.read(_schema['data'], path);
          if (resolved is String) return resolved;
          if (resolved != null) return resolved.toString();
        }
      }
      return fallback;
    }

    DashTrend trendOf(String? t) => switch (t) {
          'up' => DashTrend.up,
          'down' => DashTrend.down,
          _ => DashTrend.flat,
        };
    DashStatusTone toneOf(String? t) => switch (t) {
          'success' => DashStatusTone.success,
          'warning' => DashStatusTone.warning,
          'error' => DashStatusTone.error,
          'info' => DashStatusTone.info,
          _ => DashStatusTone.neutral,
        };

    switch (type) {
      case 'TextField':
        return _renderTextField(raw, isFlat: isFlat);

      case 'KpiCard':
        return DashKpiCard(
          label: boundString('label'),
          value: boundString('value'),
          delta: strOrNull('delta'),
          trend: trendOf(strOrNull('trend')),
          unit: strOrNull('unit'),
        );
      case 'StatBlock':
        return DashStatBlock(
          label: boundString('label'),
          value: boundString('value'),
        );
      case 'MetricRow':
        return DashMetricRow(
          label: boundString('label'),
          value: boundString('value'),
          delta: strOrNull('delta'),
          trend: trendOf(strOrNull('trend')),
          last: flag('last'),
        );

      case 'ProgressBar':
        return DashProgressBar(
          label: boundString('label'),
          value: numOrNull('value') ?? 0,
          trailing: strOrNull('trailing'),
        );
      case 'Sparkline':
        final valuesRaw = raw['values'];
        final values = valuesRaw is List
            ? valuesRaw.whereType<num>().map((n) => n.toDouble()).toList()
            : const <double>[];
        return DashSparkline(values: values);
      case 'BarChart':
        final dataRaw = raw['data'];
        final data = dataRaw is List
            ? dataRaw.whereType<Map>().map((m) {
                final lbl = m['label'];
                final val = m['value'];
                return (
                  label: lbl is String ? lbl : '',
                  value: val is num ? val.toDouble() : 0.0,
                );
              }).toList()
            : const <({String label, double value})>[];
        return DashBarChart(data: data);
      case 'LineChart':
        final seriesRaw = raw['series'];
        final seriesList = seriesRaw is List
            ? seriesRaw.whereType<Map>().map((m) {
                final label = m['label'];
                final dataRaw = m['data'];
                final points = dataRaw is List
                    ? dataRaw.whereType<Map>().map((p) {
                        final x = p['x'];
                        final y = p['y'];
                        return (
                          x: x is String ? x : '',
                          y: y is num ? y.toDouble() : 0.0,
                        );
                      }).toList()
                    : const <({String x, double y})>[];
                return DashLineSeries(
                  label: label is String ? label : '',
                  data: points,
                );
              }).toList()
            : const <DashLineSeries>[];
        final stride = numOrNull('xLabelStride')?.toInt() ?? 1;
        return DashLineChart(
          series: seriesList,
          xLabelStride: stride < 1 ? 1 : stride,
        );

      case 'ListItem':
        return DashListItem(
          title: boundString('title'),
          subtitle: strOrNull('subtitle'),
          trailing: strOrNull('trailing'),
        );
      case 'PropertyCard':
        final metaRaw = raw['meta'];
        final meta = metaRaw is List
            ? metaRaw.whereType<Map>().map((m) {
                final lbl = m['label'];
                final val = m['value'];
                return (
                  label: lbl is String ? lbl : '',
                  value: val is String ? val : '',
                );
              }).toList()
            : const <({String label, String value})>[];
        final statusRaw = raw['status'];
        DashStatusBadge? status;
        if (statusRaw is Map) {
          final lbl = statusRaw['label'];
          final tone = statusRaw['tone'];
          status = DashStatusBadge(
            label: lbl is String ? lbl : '',
            tone: toneOf(tone is String ? tone : null),
          );
        }
        return DashPropertyCard(
          title: boundString('title'),
          subtitle: strOrNull('subtitle'),
          body: strOrNull('body'),
          status: status,
          meta: meta,
        );
      case 'TimelineEntry':
        return DashTimelineEntry(
          timestamp: str('timestamp'),
          text: boundString('text'),
          last: flag('last'),
        );
      case 'CountdownItem':
        return DashCountdownItem(
          title: boundString('title'),
          due: str('due'),
          relative: str('relative'),
        );

      case 'StatusBadge':
        return DashStatusBadge(
          label: boundString('label'),
          tone: toneOf(strOrNull('tone')),
        );
      case 'TagChip':
        return DashTagChip(label: boundString('label'));

      case 'ActionButton':
        return DashActionButton(
          label: boundString('label'),
          onPressed: () {},
        );
      case 'LinkRow':
        return DashLinkRow(
          label: boundString('label'),
          trailing: strOrNull('trailing'),
        );

      case 'Markdown':
        return DashMarkdown(
          text: str('text'),
          onChanged: _markdownEditor(id: id, legacyIndex: legacyIndex),
        );
      case 'SectionHeader':
        return DashSectionHeader(
          title: boundString('title'),
          subtitle: strOrNull('subtitle'),
        );
      case 'Surface':
      case 'Column':
        return _renderContainer(raw,
            isFlat: isFlat, padding: type == 'Surface', column: true);
      case 'Row':
        return _renderContainer(raw,
            isFlat: isFlat, padding: false, column: false);

      default:
        return _unknown('unknown component "$type"');
    }
  }

  Widget _renderTextField(Map raw, {required bool isFlat}) {
    final label = raw['label'];
    final hint = raw['hint'];

    if (isFlat) {
      final valueField = raw['value'];
      String? path;
      String current = '';

      if (valueField is Map) {
        final p = valueField['path'];
        if (p is String) {
          path = p;
          final resolved = JsonPointer.read(_schema['data'], p);
          if (resolved is String) current = resolved;
        }
      } else if (valueField is String) {
        current = valueField;
      }

      return DashTextField(
        label: label is String ? label : (path ?? ''),
        value: current,
        hint: hint is String ? hint : null,
        multiline: _flagOf(raw['multiline'], fallback: true),
        onChanged: path == null ? (_) {} : (v) => _onPathWrite(path!, v),
      );
    }

    final key = raw['valueBinding'];
    if (key is! String || key.isEmpty) {
      return _unknown('TextField missing valueBinding');
    }
    final readValue = GenuiNoteParser.readData(_schema, key);
    final current = readValue is String ? readValue : '';
    return DashTextField(
      label: label is String ? label : key,
      value: current,
      hint: hint is String ? hint : null,
      multiline: _flagOf(raw['multiline'], fallback: true),
      onChanged: (v) => _onDataChange(key, v),
    );
  }

  Widget _renderContainer(
    Map raw, {
    required bool isFlat,
    required bool padding,
    required bool column,
  }) {
    final childrenRaw = raw['children'];
    final children = <Widget>[];

    if (childrenRaw is List) {
      for (final ch in childrenRaw) {
        if (isFlat && ch is String) {
          children.add(_renderById(ch));
        } else if (!isFlat && ch is Map) {
          children.add(_renderComponent(ch, isFlat: false));
        }
      }
    }

    Widget inner;
    if (column) {
      inner = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in children) ...[
            c,
            const SizedBox(height: 8),
          ],
        ],
      );
    } else {
      const stackBelow = 480.0;
      const perItemMin = 180.0;
      inner = LayoutBuilder(
        builder: (context, constraints) {
          final shouldStack = constraints.maxWidth < stackBelow ||
              constraints.maxWidth < perItemMin * children.length;
          if (shouldStack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in children) ...[
                  c,
                  const SizedBox(height: 12),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i != children.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        },
      );
    }

    if (padding) {
      return DashSurface(
        padding: const EdgeInsets.all(16),
        child: inner,
      );
    }
    return inner;
  }

  ValueChanged<String>? _markdownEditor({String? id, int? legacyIndex}) {
    if (id != null) {
      return (v) => _onFlatComponentFieldChange(id, 'text', v);
    }
    if (legacyIndex != null) {
      return (v) => _onLegacyComponentFieldChange(legacyIndex, 'text', v);
    }
    return null;
  }

  Widget _unknown(String reason) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: SpaceNotesTheme.offline.withValues(alpha: 0.08),
        border: Border.all(
          color: SpaceNotesTheme.offline.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        'genui: $reason',
        style: const TextStyle(
          fontFamily: SpaceNotesTheme.fontMono,
          fontSize: 11,
          color: SpaceNotesTheme.offline,
        ),
      ),
    );
  }

  void _ingest(String body) {
    final parsed = GenuiNoteParser.parse(body);
    if (parsed == null) {
      _schema = const {'data': <String, dynamic>{}};
      _markdown = '';
      return;
    }
    _schema = parsed.schema;
    _markdown = parsed.markdown;
  }

  void _onDataChange(String key, dynamic value) {
    setState(() {
      _schema = GenuiNoteParser.writeData(_schema, key, value);
    });
    _pushBody();
  }

  void _onPathWrite(String path, dynamic value) {
    setState(() {
      final currentData = _schema['data'];
      final newData = JsonPointer.write(
        currentData is Map<String, dynamic> ? currentData : <String, dynamic>{},
        path,
        value,
      );
      _schema = {..._schema, 'data': newData};
    });
    _pushBody();
  }

  void _onMarkdownChanged(String markdown) {
    _markdown = markdown;
    _pushBody();
  }

  void _onLegacyComponentFieldChange(int index, String field, dynamic value) {
    final components = _schema['components'];
    if (components is! List) return;
    if (index < 0 || index >= components.length) return;
    final component = components[index];
    if (component is! Map) return;
    final updated = Map<String, dynamic>.from(component);
    updated[field] = value;
    final newComponents = List<dynamic>.from(components);
    newComponents[index] = updated;
    _schema = {..._schema, 'components': newComponents};
    _pushBody();
  }

  void _onFlatComponentFieldChange(String id, String field, dynamic value) {
    final components = _schema['components'];
    if (components is! List) return;
    final newComponents = <dynamic>[];
    for (final c in components) {
      if (c is Map && c['id'] == id) {
        final updated = Map<String, dynamic>.from(c);
        updated[field] = value;
        newComponents.add(updated);
      } else {
        newComponents.add(c);
      }
    }
    _schema = {..._schema, 'components': newComponents};
    _pushBody();
  }

  void _pushBody() {
    widget.onBodyChanged(GenuiNoteParser.serialize(
      GenuiNote(schema: _schema, markdown: _markdown),
    ));
  }

  bool _flagOf(dynamic v, {required bool fallback}) {
    return v is bool ? v : fallback;
  }
}
