import 'package:flutter/material.dart';
import '../../services/genui_note_parser.dart';
import '../../theme/spacenotes_theme.dart';
import '../primitives/primitives.dart';
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

  @override
  void initState() {
    super.initState();
    _ingest(widget.body);
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final components = _schema['components'];
    final componentList = components is List ? components : const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in componentList) ...[
              _renderComponent(c),
              const SizedBox(height: 12),
            ],
            if (_markdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SnHairline(),
              const SizedBox(height: 16),
              Text(
                _markdown,
                style: const TextStyle(
                  fontFamily: SpaceNotesTheme.fontSans,
                  fontSize: 14,
                  color: SpaceNotesTheme.fg,
                  height: 1.55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _renderComponent(Object? raw) {
    if (raw is! Map) return _unknown('not a component object');
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
      // Inputs
      case 'TextField':
        final key = str('valueBinding');
        if (key.isEmpty) return _unknown('TextField missing valueBinding');
        final readValue = GenuiNoteParser.readData(_schema, key);
        final current = readValue is String ? readValue : '';
        return DashTextField(
          label: str('label', key),
          value: current,
          hint: strOrNull('hint'),
          multiline: flag('multiline', true),
          onChanged: (v) => _onDataChange(key, v),
        );

      // KPI / Metric
      case 'KpiCard':
        return DashKpiCard(
          label: str('label'),
          value: str('value'),
          delta: strOrNull('delta'),
          trend: trendOf(strOrNull('trend')),
          unit: strOrNull('unit'),
        );
      case 'StatBlock':
        return DashStatBlock(label: str('label'), value: str('value'));
      case 'MetricRow':
        return DashMetricRow(
          label: str('label'),
          value: str('value'),
          delta: strOrNull('delta'),
          trend: trendOf(strOrNull('trend')),
        );

      // Charts
      case 'ProgressBar':
        return DashProgressBar(
          label: str('label'),
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

      // Lists
      case 'ListItem':
        return DashListItem(
          title: str('title'),
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
          title: str('title'),
          subtitle: strOrNull('subtitle'),
          body: strOrNull('body'),
          status: status,
          meta: meta,
        );
      case 'TimelineEntry':
        return DashTimelineEntry(
          timestamp: str('timestamp'),
          text: str('text'),
          last: flag('last'),
        );
      case 'CountdownItem':
        return DashCountdownItem(
          title: str('title'),
          due: str('due'),
          relative: str('relative'),
        );

      // Status
      case 'StatusBadge':
        return DashStatusBadge(
            label: str('label'), tone: toneOf(strOrNull('tone')));
      case 'TagChip':
        return DashTagChip(label: str('label'));

      // Actions
      case 'ActionButton':
        return DashActionButton(label: str('label'), onPressed: () {});
      case 'LinkRow':
        return DashLinkRow(
            label: str('label'), trailing: strOrNull('trailing'));

      // Layout
      case 'Markdown':
        return DashMarkdown(text: str('text'));
      case 'SectionHeader':
        return DashSectionHeader(
            title: str('title'), subtitle: strOrNull('subtitle'));
      case 'Surface':
        final childrenRaw = raw['children'];
        final children =
            childrenRaw is List ? childrenRaw : const <Object?>[];
        return DashSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final ch in children) ...[
                _renderComponent(ch),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );

      default:
        return _unknown('unknown component "$type"');
    }
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
    widget.onBodyChanged(GenuiNoteParser.serialize(
      GenuiNote(schema: _schema, markdown: _markdown),
    ));
  }
}
