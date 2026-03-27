import 'package:flutter_bloc/flutter_bloc.dart';
import '../../interfaces/chat_interface.dart';
import '../../interfaces/claudecode_chat_interface.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatInterface _interface;

  ChatBloc() : _interface = ClaudeCodeChatInterface(), super(ChatInitial()) {
    on<LoadMessagesForCurrentSession>((e, emit) => _interface.onLoadMessages(emit));
    on<SendChatMessage>((e, emit) => _interface.onSendMessage(e, emit));
    on<CancelCurrentOperation>((e, emit) => _interface.onCancelOperation(emit));
    on<ClearMessages>((e, emit) => _interface.onClearMessages(emit));
    on<ClearChat>((e, emit) => _interface.onClearChat(emit));
    on<RetryMessage>((e, emit) => _interface.onRetryMessage(e, emit));
    on<DeleteQueuedMessage>((e, emit) => _interface.onDeleteQueuedMessage(e, emit));
    on<MessageStatusChanged>((e, emit) => _interface.onMessageStatusChanged(e, emit));
    on<RespondToPermission>((e, emit) => _interface.onRespondToPermission(e, emit));
    on<SessionErrorReceived>((e, emit) => emit(ChatError(e.error)));
    on<RefreshChatStateEvent>((e, emit) => _interface.onRefreshState(emit));
    on<SSEEventReceived>((e, emit) {});
    on<AddUserMessage>((e, emit) {});
    on<SetTargetSession>((e, emit) => _interface.onSetTargetSession(e, emit));

    _interface.setAddEvent(add);
    _interface.initialize();
    add(LoadMessagesForCurrentSession());
  }

  @override
  Future<void> close() {
    _interface.dispose();
    return super.close();
  }
}
