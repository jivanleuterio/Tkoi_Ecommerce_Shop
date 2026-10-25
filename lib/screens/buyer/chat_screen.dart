import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';
import '../../widgets/safe_network_image.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final ChatContext? initialContext;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.initialContext,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  final _service = ChatService();
  late Future<ChatContext> _contextFuture;
  late Stream<List<ChatMessage>> _messageStream;
  bool _sending = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _contextFuture = widget.initialContext == null
        ? _service.getContext(widget.conversationId)
        : Future.value(widget.initialContext);
    _messageStream = _service.watchMessages(widget.conversationId);
    unawaited(_service.markRead(widget.conversationId));
  }

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(ChatContext chatContext) async {
    final body = _message.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        conversationId: widget.conversationId,
        body: body,
        productId: chatContext.productId,
        orderId: chatContext.orderId,
      );
      _message.clear();
      _scrollToLatest();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.minScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _canPop) return;
      try {
        await _service.markRead(widget.conversationId);
      } catch (_) {
        // A read-receipt failure should never trap the user in the chat.
      }
      if (!mounted) return;
      setState(() => _canPop = true);
      Navigator.pop(this.context, result);
    },
    child: FutureBuilder<ChatContext>(
      future: _contextFuture,
      builder: (context, contextSnapshot) {
        if (contextSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Conversation')),
            body: ErrorView(
              error: contextSnapshot.error!,
              onRetry: () => setState(() {
                _contextFuture = _service.getContext(widget.conversationId);
              }),
            ),
          );
        }
        final chatContext = contextSnapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: chatContext == null
                ? const Text('Conversation')
                : Row(
                    children: [
                      SafeNetworkImage(
                        url: chatContext.otherAvatar,
                        width: 38,
                        height: 38,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chatContext.otherName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              chatContext.shopName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.softGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          body: Column(
            children: [
              if (chatContext != null &&
                  (chatContext.productId != null ||
                      chatContext.orderId != null))
                _ContextCard(chatContext: chatContext),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _messageStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ErrorView(error: snapshot.error!);
                    }
                    final messages = snapshot.data ?? const [];
                    unawaited(_service.markRead(widget.conversationId));
                    if (messages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'Start the conversation about this fish or order.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.softGray),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - 1 - index];
                        return _MessageBubble(
                          message: message,
                          isMine: message.senderId == _service.currentUserId,
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _message,
                          enabled: !_sending && chatContext != null,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          buildCounter: (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Write a message...',
                            prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send message',
                        onPressed: _sending || chatContext == null
                            ? null
                            : () => _send(chatContext),
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ContextCard extends StatelessWidget {
  final ChatContext chatContext;

  const _ContextCard({required this.chatContext});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        if (chatContext.productId != null)
          SafeNetworkImage(url: chatContext.productImage, width: 48, height: 48)
        else
          const CircleAvatar(
            backgroundColor: AppColors.mist,
            child: Icon(Icons.receipt_long_rounded, color: AppColors.pondBlue),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chatContext.productName ?? 'Order conversation',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (chatContext.orderId case final orderId?)
                Text(
                  'Order ${orderId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.softGray,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) => Align(
    alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 310),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 7),
      decoration: BoxDecoration(
        color: isMine ? AppColors.koiOrange : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
        border: isMine ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message.body,
              style: TextStyle(color: isMine ? Colors.white : AppColors.sumi),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(message.createdAt.toLocal()),
            ),
            style: TextStyle(
              fontSize: 10,
              color: isMine
                  ? Colors.white.withValues(alpha: .75)
                  : AppColors.softGray,
            ),
          ),
        ],
      ),
    ),
  );
}
