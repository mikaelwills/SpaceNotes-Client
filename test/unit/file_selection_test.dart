import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/providers/file_selection_provider.dart';

void main() {
  late FileSelectionNotifier notifier;

  setUp(() => notifier = FileSelectionNotifier());

  test('starts inactive with nothing selected', () {
    expect(notifier.state.active, isFalse);
    expect(notifier.state.count, 0);
    expect(notifier.state.hasSelection, isFalse);
  });

  test('toggling mode on and off clears the ticks', () {
    notifier.toggleMode();
    notifier.toggle('a');
    notifier.toggle('b');
    expect(notifier.state.count, 2);

    notifier.toggleMode();
    expect(notifier.state.active, isFalse);
    expect(notifier.state.count, 0,
        reason: 'leaving select mode must not keep a hidden selection');

    notifier.toggleMode();
    expect(notifier.state.active, isTrue);
    expect(notifier.state.count, 0, reason: 're-entering starts clean');
  });

  test('tapping the same file twice deselects it', () {
    notifier.toggleMode();
    notifier.toggle('a');
    expect(notifier.state.isSelected('a'), isTrue);

    notifier.toggle('a');
    expect(notifier.state.isSelected('a'), isFalse);
    expect(notifier.state.count, 0);
  });

  test('select all then clear', () {
    notifier.toggleMode();
    notifier.selectAll(['a', 'b', 'c']);
    expect(notifier.state.count, 3);

    notifier.clearSelection();
    expect(notifier.state.count, 0);
    expect(notifier.state.active, isTrue,
        reason: 'clearing ticks must not drop out of select mode');
  });

  test('exit leaves select mode and clears', () {
    notifier.toggleMode();
    notifier.selectAll(['a', 'b']);
    notifier.exit();

    expect(notifier.state.active, isFalse);
    expect(notifier.state.count, 0);
  });

  test('selectAll replaces rather than adds to the selection', () {
    notifier.toggleMode();
    notifier.toggle('x');
    notifier.selectAll(['a', 'b']);

    expect(notifier.state.count, 2);
    expect(notifier.state.isSelected('x'), isFalse);
  });
}
