import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/supabase_provider.dart';
import '../../tasks/presentation/providers/suggestion_provider.dart';

// ── Providers ─────────────────────────────────────────────────
class ChatMessage {
  final String id, content;
  final bool isUser, isLoading;
  ChatMessage({required this.id, required this.content,
    required this.isUser, this.isLoading = false});
  ChatMessage copyWith({String? content, bool? isLoading}) =>
      ChatMessage(id: id, content: content ?? this.content,
          isUser: isUser, isLoading: isLoading ?? this.isLoading);
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  String? _conversationId;

  ChatNotifier(this._ref) : super([
    ChatMessage(
      id: 'welcome',
      content: "Hi! I'm Luna 🌙 I'm here to help you understand your wellness, manage your tasks, and thrive through every phase. What's on your mind?",
      isUser: false,
    ),
  ]);

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    final sb = _ref.read(supabaseProvider);

    state = [
      ...state,
      ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: text, isUser: true),
      ChatMessage(id: 'loading', content: '', isUser: false, isLoading: true),
    ];

    try {
      final res = await sb.functions.invoke('chat', body: {
        'message': text,
        if (_conversationId != null) 'conversation_id': _conversationId,
      });
      final data = res.data as Map<String, dynamic>;
      _conversationId = data['conversation_id'];

      state = [
        ...state.where((m) => m.id != 'loading'),
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: data['message'] as String? ?? '...',
          isUser: false,
        ),
      ];
    } catch (e) {
      state = [
        ...state.where((m) => m.id != 'loading'),
        ChatMessage(
          id: 'err${DateTime.now().millisecondsSinceEpoch}',
          content: 'Sorry, something went wrong. Please try again.',
          isUser: false,
        ),
      ];
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref);
});

// ── Screen ────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl     = TextEditingController();
  final _scroll   = ScrollController();
  final _stt      = SpeechToText();
  bool _listening = false;
  bool _sttReady  = false;

  @override
  void initState() {
    super.initState();
    _initStt();
  }

  Future<void> _initStt() async {
    _sttReady = await _stt.initialize();
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await ref.read(chatProvider.notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _toggleListening() async {
    if (!_sttReady) return;
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
    } else {
      setState(() => _listening = true);
      await _stt.listen(
        onResult: (r) {
          _ctrl.text = r.recognizedWords;
          if (r.finalResult) {
            setState(() => _listening = false);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose(); _scroll.dispose(); _stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final pendingCount = ref.watch(pendingSuggestionsCountProvider);

    // Auto scroll when new messages arrive
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppTheme.primary.withOpacity(0.5), AppTheme.primaryDeep.withOpacity(0.2)],
              ),
            ),
            child: const Center(child: Text('🌙', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Luna', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
            Text('Your wellness copilot',
                style: TextStyle(fontSize: 11, color: AppTheme.textSub.withOpacity(0.7))),
          ]),
        ]),
        actions: [
          if (pendingCount > 0)
            GestureDetector(
              onTap: () => context.go(RouteNames.suggestions),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.task_alt, color: AppTheme.accent, size: 14),
                  const SizedBox(width: 4),
                  Text('$pendingCount tasks', style: const TextStyle(
                      color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Suggestions banner
          if (pendingCount > 0)
            GestureDetector(
              onTap: () => context.go(RouteNames.suggestions),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppTheme.accent.withOpacity(0.1),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Luna suggested $pendingCount task${pendingCount > 1 ? 's' : ''} — tap to review',
                    style: const TextStyle(color: AppTheme.accent, fontSize: 13),
                  )),
                  const Icon(Icons.chevron_right, color: AppTheme.accent, size: 18),
                ]),
              ),
            ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, i) => _MessageBubble(msg: messages[i]),
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                // Voice button
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _listening
                          ? AppTheme.accent.withOpacity(0.2)
                          : AppTheme.bgCardLight,
                      border: Border.all(
                        color: _listening ? AppTheme.accent : AppTheme.border,
                      ),
                    ),
                    child: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: _listening ? AppTheme.accent : AppTheme.textSub,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Text input
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: _listening ? 'Listening...' : 'Message Luna...',
                      hintStyle: TextStyle(color: AppTheme.textSub.withOpacity(0.5),
                          fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.bgCardLight,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [
                        AppTheme.primary, AppTheme.primaryDeep,
                      ]),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4), topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(delay: 0), _Dot(delay: 300), _Dot(delay: 600),
          ]),
        ),
      );
    }

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: msg.isUser ? 60 : 0,
          right: msg.isUser ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser
              ? AppTheme.primaryDeep.withOpacity(0.5)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(msg.isUser ? 16 : 4),
            topRight: Radius.circular(msg.isUser ? 4 : 16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
          border: Border.all(
            color: msg.isUser
                ? AppTheme.primary.withOpacity(0.3)
                : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: Text(msg.content, style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 14, height: 1.5)),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      width: 7, height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primary.withOpacity(_a.value),
      ),
    ),
  );
}