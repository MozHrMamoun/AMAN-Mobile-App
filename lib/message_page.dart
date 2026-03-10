import 'package:flutter/material.dart';

import 'add_property_page.dart';
import 'chat_detail_page.dart';
import 'core/app_session.dart';
import 'features/chat/state/chat_list_controller.dart';
import 'follow_up_property_page.dart';
import 'owner_home_page.dart';
import 'recommendation_page.dart';
import 'search_property_page.dart';
import 'seeker_home_page.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final ChatListController _controller = ChatListController();

  bool _isLoading = true;
  String? _errorMessage;
  String _currentRole = 'seeker';
  List<ChatThreadItem> _threads = const [];

  @override
  void initState() {
    super.initState();
    if (AppSession.isGuestMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to use this feature.')),
        );
        Navigator.of(context).maybePop();
      });
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _controller.loadChats();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage = result.success ? null : result.errorMessage;
      _threads = result.items;
      _currentRole = result.currentRole ?? 'seeker';
    });
  }

  void _goBack() {
    if (_currentRole == 'owner') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OwnerHomePage()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SeekerHomePage()),
    );
  }

  void _onNavTap(int index) {
    if (_currentRole == 'owner') {
      switch (index) {
        case 0:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OwnerHomePage()),
          );
          break;
        case 1:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AddPropertyPage()),
          );
          break;
        case 2:
          break;
        case 3:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const FollowUpPropertyPage()),
          );
          break;
      }
      return;
    }

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SeekerHomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SearchPropertyPage()),
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RecommendationPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFE9EAEC);

    return Scaffold(
      backgroundColor: primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Message',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 37 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: page,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFF1F2430),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _threads.isEmpty
                            ? const Center(
                                child: Text(
                                  'No chats yet.',
                                  style: TextStyle(
                                    color: Color(0xFF1F2430),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    12,
                                  ),
                                  itemCount: _threads.length,
                                  itemBuilder: (context, index) {
                                    final thread = _threads[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Material(
                                        color: const Color(0xFFF2F2F3),
                                        borderRadius: BorderRadius.circular(10),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChatDetailPage(
                                                  chatId: thread.chatId,
                                                  peerName: thread.peerName,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFE0E2E5),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.account_circle_rounded,
                                                  size: 34,
                                                  color: Color(0xFF1C2A4A),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        thread.peerName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xFF1F2430),
                                                          fontSize: 18 / 1.2,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        thread.lastMessageText,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xFF4A5160),
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(
          height: 72,
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: Colors.white, size: 30),
          ),
        ),
        child: NavigationBar(
          backgroundColor: primary,
          selectedIndex: 2,
          onDestinationSelected: _onNavTap,
          destinations: _currentRole == 'owner'
              ? const [
                  NavigationDestination(
                    icon: Icon(Icons.home_rounded),
                    label: 'HOME',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.add_circle_rounded),
                    label: 'Add',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.send_rounded),
                    label: 'Message',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded),
                    label: 'More',
                  ),
                ]
              : const [
                  NavigationDestination(
                    icon: Icon(Icons.home_rounded),
                    label: 'HOME',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_rounded),
                    label: 'SEARCH',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.send_rounded),
                    label: 'MESSAGE',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded),
                    label: 'MORE',
                  ),
                ],
        ),
      ),
    );
  }
}
