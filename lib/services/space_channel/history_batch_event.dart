import 'space_channel_event.dart';

class HistoryBatchEvent {
  final String session;
  final List<SpaceChannelEvent> events;

  const HistoryBatchEvent({required this.session, required this.events});
}
