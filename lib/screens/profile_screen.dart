import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  bool _isEditing = false;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _discoverUsers = [];
  bool _isLoadingFriends = true;
  bool _isLoadingRequests = true;
  bool _isLoadingMessages = true;
  bool _isLoadingDiscoverUsers = true;

  static const String _apiBaseUrl = 'http://localhost:5000';

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: Provider.of<UserProvider>(context, listen: false).user.name,
    );
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    await _fetchFriends();
    await Future.wait([
      _fetchFriendRequests(),
      _fetchMessages(),
      _fetchDiscoverUsers(),
    ]);
  }

  Future<void> _fetchDiscoverUsers() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _safeSetState(() => _isLoadingDiscoverUsers = false);
        return;
      }

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/discover-users?limit=30'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _safeSetState(() {
            _discoverUsers = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _isLoadingDiscoverUsers = false;
          });
        } else {
          _safeSetState(() => _isLoadingDiscoverUsers = false);
        }
      } else {
        _safeSetState(() => _isLoadingDiscoverUsers = false);
      }
    } catch (e) {
      print('Error fetching discover users: $e');
      _safeSetState(() => _isLoadingDiscoverUsers = false);
    }
  }

  Future<void> _fetchFriends() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _safeSetState(() => _isLoadingFriends = false);
        return;
      }

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/friends'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _safeSetState(() {
            _friends = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _isLoadingFriends = false;
          });
        } else {
          _safeSetState(() => _isLoadingFriends = false);
        }
      } else {
        _safeSetState(() => _isLoadingFriends = false);
      }
    } catch (e) {
      print('Error fetching friends: $e');
      _safeSetState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _fetchFriendRequests() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _safeSetState(() => _isLoadingRequests = false);
        return;
      }

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/friend-requests'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _safeSetState(() {
            _friendRequests = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _isLoadingRequests = false;
          });
        } else {
          _safeSetState(() => _isLoadingRequests = false);
        }
      } else {
        _safeSetState(() => _isLoadingRequests = false);
      }
    } catch (e) {
      print('Error fetching friend requests: $e');
      _safeSetState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _safeSetState(() => _isLoadingMessages = false);
        return;
      }

      if (_friends.isEmpty) {
        _safeSetState(() => _isLoadingMessages = false);
        return;
      }

      final friendId = _friends[0]['_id'] ?? _friends[0]['id'];
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/messages/$friendId?limit=20'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _safeSetState(() {
            _messages = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _isLoadingMessages = false;
          });
        } else {
          _safeSetState(() => _isLoadingMessages = false);
        }
      } else {
        _safeSetState(() => _isLoadingMessages = false);
      }
    } catch (e) {
      print('Error fetching messages: $e');
      _safeSetState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _sendFriendRequest(String recipientId) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/profile/friend-request'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'recipientId': recipientId}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _fetchFriendRequests();
        await _fetchDiscoverUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Friend request sent!')),
          );
        }
      } else {
        final body = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['message'] ?? 'Failed to send friend request')),
          );
        }
      }
    } catch (e) {
      print('Error sending friend request: $e');
    }
  }

  Future<void> _openSendMessageDialog(String recipientId, String recipientName) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Message $recipientName'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Type your message...'),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final message = controller.text.trim();
                if (message.isEmpty) return;
                Navigator.of(context).pop();
                await _sendMessage(recipientId, message);
              },
              child: const Text('Send'),
            )
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await http.put(
        Uri.parse('$_apiBaseUrl/api/profile/friend-request/$requestId/accept'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _fetchFriendRequests();
        await _fetchFriends();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Friend request accepted!')),
          );
        }
      }
    } catch (e) {
      print('Error accepting request: $e');
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await http.delete(
        Uri.parse('$_apiBaseUrl/api/profile/friend-request/$requestId'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _fetchFriendRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Friend request rejected')),
          );
        }
      }
    } catch (e) {
      print('Error rejecting request: $e');
    }
  }

  Future<void> _sendMessage(String recipientId, String text) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/profile/messages'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipientId': recipientId,
          'text': text,
        }),
      );

      if (response.statusCode == 201) {
        await _fetchMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message sent!')),
          );
        }
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final palette = _ProfilePalette(
      headerTint: Color.alphaBlend(themeProvider.accent.withValues(alpha: 0.34), const Color(0xFFE4D8FF)),
      requestTint: Color.alphaBlend(themeProvider.primary.withValues(alpha: 0.32), const Color(0xFFFFD6E6)),
      friendsTint: Color.alphaBlend(themeProvider.primary.withValues(alpha: 0.28), const Color(0xFFD3DDFF)),
      messagesTint: Color.alphaBlend(themeProvider.accent.withValues(alpha: 0.24), const Color(0xFFC6FFEF)),
      accent: themeProvider.accent,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Profile',
          icon: Icons.person,
        ),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                LiquidGlassCard(
                  tint: palette.headerTint,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0x39FFFFFF),
                            child: const Icon(Icons.person, size: 50, color: Colors.white),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProvider.user.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  Supabase.instance.client.auth.currentUser?.email ?? 'user@example.com',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFE3F2FD),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Color(0xFFFFF1A3), size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${userProvider.user.points} Points',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFC8FFE9),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Discover People Section
                LiquidGlassCard(
                  tint: const Color(0xFFD9F0FF),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.travel_explore, color: Color(0xFFBDE4FF), size: 24),
                          const SizedBox(width: 10),
                          const Text('Discover People', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Spacer(),
                          Text('${_discoverUsers.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFBDE4FF))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingDiscoverUsers)
                        const CircularProgressIndicator()
                      else if (_discoverUsers.isEmpty)
                        const Text('No new people found', style: TextStyle(color: Color(0xFFE3F2FD)))
                      else
                        ..._discoverUsers.take(8).map((person) {
                          final status = (person['friendshipStatus'] ?? 'none').toString();
                          final personId = (person['_id'] ?? person['id'] ?? '').toString();
                          final canAdd = status == 'none' && personId.isNotEmpty;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 20, backgroundColor: const Color(0x39FFFFFF), child: const Icon(Icons.person, size: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(person['name'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                      Text(person['email'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFFE3F2FD))),
                                    ],
                                  ),
                                ),
                                if (canAdd)
                                  ElevatedButton(
                                    onPressed: () => _sendFriendRequest(personId),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      backgroundColor: palette.accent,
                                      foregroundColor: Colors.black87,
                                    ),
                                    child: const Text('Add', style: TextStyle(fontSize: 12)),
                                  )
                                else
                                  Text(
                                    status == 'pending' ? 'Pending' : 'Connected',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFE3F2FD)),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Friend Requests Section
                LiquidGlassCard(
                  tint: palette.requestTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_add, color: Color(0xFFFFE8F2), size: 24),
                          const SizedBox(width: 10),
                          const Text('Friend Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Spacer(),
                          Text('${_friendRequests.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFFFE8F2))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingRequests)
                        const Center(child: CircularProgressIndicator())
                      else if (_friendRequests.isEmpty)
                        const Text('No friend requests', style: TextStyle(color: Color(0xFFE3F2FD)))
                      else
                        ...(_friendRequests).map((request) {
                          final requester = request['requester'] ?? {};
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 20, backgroundColor: const Color(0x39FFFFFF), child: const Icon(Icons.person, size: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(requester['name'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                      Text(requester['email'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFFE3F2FD))),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _acceptFriendRequest(request['_id']),
                                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), backgroundColor: palette.accent, foregroundColor: Colors.black87),
                                  child: const Text('Accept', style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _rejectFriendRequest(request['_id']),
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Friends List Section
                LiquidGlassCard(
                  tint: palette.friendsTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people, color: Color(0xFFB0C9FF), size: 24),
                          const SizedBox(width: 10),
                          const Text('Friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Spacer(),
                          Text('${_friends.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFB0C9FF))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingFriends)
                        const CircularProgressIndicator()
                      else if (_friends.isEmpty)
                        const Text('No friends yet', style: TextStyle(color: Color(0xFFE3F2FD)))
                      else
                        ..._friends.map((friend) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 20, backgroundColor: const Color(0x39FFFFFF), child: const Icon(Icons.person, size: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(friend['name'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                      Text(friend['email'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFFE3F2FD))),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    final friendId = (friend['_id'] ?? friend['id'] ?? '').toString();
                                    final friendName = (friend['name'] ?? 'Friend').toString();
                                    if (friendId.isEmpty) return;
                                    _openSendMessageDialog(friendId, friendName);
                                  },
                                  icon: const Icon(Icons.message, color: Colors.white),
                                ),
                                const Icon(Icons.circle, color: Color(0xFF4ADE80), size: 12),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Messages Section
                LiquidGlassCard(
                  tint: palette.messagesTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.message, color: Color(0xFFB0E9FF), size: 24),
                          const SizedBox(width: 10),
                          const Text('Messages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingMessages)
                        const CircularProgressIndicator()
                      else if (_messages.isEmpty)
                        const Text('No messages yet', style: TextStyle(color: Color(0xFFE3F2FD)))
                      else
                        ..._messages.take(5).map((msg) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0x20FFFFFF), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(msg['sender']['name'] ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(msg['text'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFFE3F2FD)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePalette {
  final Color headerTint;
  final Color requestTint;
  final Color friendsTint;
  final Color messagesTint;
  final Color accent;

  _ProfilePalette({
    required this.headerTint,
    required this.requestTint,
    required this.friendsTint,
    required this.messagesTint,
    required this.accent,
  });
}
