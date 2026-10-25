import 'package:flutter/material.dart';

import '../../models/chat.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/safe_network_image.dart';
import 'chat_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  late Future<List<ChatInboxItem>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ChatService().getInbox();
  }

  Future<void> _refresh() async {
    setState(() {
      _load();
    });
    await _future;
  }

  String _when(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(local));
    }
    return MaterialLocalizations.of(context).formatShortDate(local);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Messages'),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Refresh messages',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<ChatInboxItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TkoiLoadingView(
            message: 'Opening your conversations...',
          );
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!, onRetry: _refresh);
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.forum_outlined,
            title: 'No messages yet',
            message: 'Open a fish or order to start chatting with a seller.',
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(indent: 76),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                minVerticalPadding: 12,
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SafeNetworkImage(
                      url: item.otherAvatar,
                      width: 52,
                      height: 52,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    if (item.unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.vermilion,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            item.unreadCount > 99
                                ? '99+'
                                : '${item.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.otherName,
                        style: TextStyle(
                          fontWeight: item.unreadCount > 0
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _when(context, item.lastMessageAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.softGray,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: item.unreadCount > 0
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      item.productName ?? item.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.pondBlue,
                      ),
                    ),
                  ],
                ),
                onTap: () async {
                  await ChatService().markRead(item.conversationId);
                  if (!context.mounted) return;
                  setState(() => _load());
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: item.conversationId,
                        initialContext: item,
                      ),
                    ),
                  );
                  if (mounted) await _refresh();
                },
              );
            },
          ),
        );
      },
    ),
  );
}
