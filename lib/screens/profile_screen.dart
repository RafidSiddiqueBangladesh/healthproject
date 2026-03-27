import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../services/health_result_service.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  final ImagePicker _imagePicker = ImagePicker();
  String? _profileAvatarUrl;
  bool _isEditing = false;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _discoverUsers = [];
  bool _isLoadingFriends = true;
  bool _isLoadingRequests = true;
  bool _isLoadingMessages = true;
  bool _isLoadingDiscoverUsers = true;
  String _userRole = 'patient';
  bool _isSavingUserRole = false;

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );
  static const String _chatImageMarker = '[image]';

  String _messageSenderId(Map<String, dynamic> msg) {
    final sender = (msg['sender'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return (sender['_id'] ?? sender['id'] ?? '').toString();
  }

  bool _isMyMessage(Map<String, dynamic> msg) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (currentUserId.isEmpty) return false;
    return _messageSenderId(msg) == currentUserId;
  }

  String? _extractImageUrlFromMessageText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final lines = trimmed.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    for (final line in lines) {
      if (line.startsWith(_chatImageMarker)) {
        final candidate = line.substring(_chatImageMarker.length).trim();
        if (candidate.startsWith('http://') || candidate.startsWith('https://')) return candidate;
      }
    }

    if ((trimmed.startsWith('http://') || trimmed.startsWith('https://')) &&
        RegExp(r'\.(jpg|jpeg|png|gif|webp)(\?.*)?$', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  String _extractCaptionFromMessageText(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith(_chatImageMarker))
        .toList();
    return lines.join('\n').trim();
  }

  Future<String?> _pickAndUploadChatImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return null;

    final extMatch = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(picked.name);
    final ext = (extMatch?.group(1) ?? 'jpg').toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = '$uid/messages/$fileName';
    final contentType = (ext == 'png')
        ? 'image/png'
        : (ext == 'webp')
            ? 'image/webp'
            : 'image/jpeg';

    await Supabase.instance.client.storage
        .from('chat-images')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );

    return Supabase.instance.client.storage.from('chat-images').getPublicUrl(path);
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserProvider>().fetchUserProfile();
      _loadUserRole();
    });
    _fetchAllData();
  }

  Future<void> _loadUserRole() async {
    try {
      final role = await HealthResultService.fetchUserRole();
      if (!mounted) return;
      _safeSetState(() {
        _userRole = role == 'doctor' ? 'doctor' : 'patient';
      });
    } catch (_) {}
  }

  Future<void> _saveUserRole(String role) async {
    if (_isSavingUserRole) return;
    if (_userRole == 'patient' && role == 'doctor') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient role is locked and cannot be changed to Doctor.')),
      );
      return;
    }
    final normalized = role == 'doctor' ? 'doctor' : 'patient';
    _safeSetState(() {
      _isSavingUserRole = true;
    });
    try {
      await HealthResultService.saveUserRole(normalized);
      if (!mounted) return;
      _safeSetState(() {
        _userRole = normalized;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role updated to ${normalized == 'doctor' ? 'Doctor' : 'Patient'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role update failed: $e')));
    } finally {
      if (mounted) {
        _safeSetState(() {
          _isSavingUserRole = false;
        });
      }
    }
  }

  Future<void> _fetchProfileAvatar() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/me'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data['success'] != true) return;
      final avatar = (data['data']?['avatar'] ?? '').toString();
      if (avatar.isNotEmpty) {
        _safeSetState(() {
          _profileAvatarUrl = avatar;
        });
        context.read<UserProvider>().setAvatar(avatar);
      }
    } catch (_) {}
  }

  Future<void> _fetchAllData() async {
    await _fetchProfileAvatar();
    await _fetchFriends();
    await Future.wait([
      _fetchFriendRequests(),
      _fetchMessages(),
      _fetchDiscoverUsers(),
    ]);
  }

  Future<void> _uploadProfilePhoto() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) return;

      final extMatch = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(picked.name);
      final ext = (extMatch?.group(1) ?? 'jpg').toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final contentType = (ext == 'png')
          ? 'image/png'
          : (ext == 'webp')
            ? 'image/webp'
            : 'image/jpeg';

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;
        final response = await http.post(
          Uri.parse('$_apiBaseUrl/api/profile/upload-profile-image'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
          body: jsonEncode({
            'base64Image': base64Encode(bytes),
            'mimeType': contentType,
            'fileName': fileName,
          }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body);
          final imageUrl = ((body['data'] ?? const {})['avatar'] ?? '').toString();
        _safeSetState(() {
            _profileAvatarUrl = imageUrl.isNotEmpty ? imageUrl : _profileAvatarUrl;
        });
        if (imageUrl.isNotEmpty) {
          context.read<UserProvider>().setAvatar(imageUrl);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save profile photo (${response.statusCode})')),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo upload failed: $e'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await http.post(
          Uri.parse('$_apiBaseUrl/api/auth/logout'),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
        );
      }
    } catch (_) {
      // Continue with client logout even if backend logout call fails.
    } finally {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AuthScreen()),
        (route) => false,
      );
    }
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
    String? uploadedImageUrl;
    bool isUploadingImage = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Message $recipientName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'Type your message...'),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: isUploadingImage
                          ? null
                          : () async {
                              try {
                                setDialogState(() => isUploadingImage = true);
                                final url = await _pickAndUploadChatImage();
                                setDialogState(() {
                                  uploadedImageUrl = url;
                                  isUploadingImage = false;
                                });
                              } catch (e) {
                                setDialogState(() => isUploadingImage = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Image upload failed: $e'),
                                      duration: const Duration(seconds: 6),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.image),
                      label: Text(isUploadingImage ? 'Uploading...' : 'Add Image'),
                    ),
                  ],
                ),
                if (uploadedImageUrl != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(uploadedImageUrl!, height: 120, width: 120, fit: BoxFit.cover),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final message = controller.text.trim();
                  if (message.isEmpty && (uploadedImageUrl == null || uploadedImageUrl!.isEmpty)) {
                    return;
                  }
                  Navigator.of(context).pop();
                  await _sendMessage(recipientId, message, imageUrl: uploadedImageUrl);
                },
                child: const Text('Send'),
              )
            ],
          );
        });
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

  Future<void> _sendMessage(String recipientId, String text, {String? imageUrl}) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final normalizedText = text.trim();
      final payloadText = imageUrl != null && imageUrl.isNotEmpty
          ? (normalizedText.isEmpty ? '$_chatImageMarker$imageUrl' : '$normalizedText\n$_chatImageMarker$imageUrl')
          : normalizedText;

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/profile/messages'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipientId': recipientId,
          'text': payloadText,
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

    final effectiveAvatar = (_profileAvatarUrl != null && _profileAvatarUrl!.isNotEmpty)
      ? _profileAvatarUrl!
      : userProvider.user.avatar;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Profile',
          icon: Icons.person,
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
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
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0x39FFFFFF),
                                backgroundImage: effectiveAvatar.isNotEmpty
                                  ? NetworkImage(effectiveAvatar)
                                    : null,
                                child: effectiveAvatar.isEmpty
                                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: InkWell(
                                  onTap: _uploadProfilePhoto,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xCC4C8CFF),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white70),
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
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

                LiquidGlassCard(
                  tint: const Color(0xFFE8E2FF),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Role',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(value: 'patient', label: Text('Patient / Parent'), icon: Icon(Icons.person)),
                          ButtonSegment<String>(value: 'doctor', label: Text('Doctor'), icon: Icon(Icons.medical_services)),
                        ],
                        selected: <String>{_userRole},
                        onSelectionChanged: _isSavingUserRole
                            ? null
                            : (selection) {
                                final nextRole = selection.isEmpty ? 'patient' : selection.first;
                                _saveUserRole(nextRole);
                              },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSavingUserRole
                            ? 'Saving role...'
                            : _userRole == 'patient'
                                ? 'Patient role is permanent for this account. Doctor mode is disabled.'
                                : 'Doctor role active. If changed to patient, it cannot be changed back.',
                        style: const TextStyle(color: Color(0xFFE3F2FD), fontSize: 13),
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
                        ..._messages.take(8).map((msg) {
                          final isMine = _isMyMessage(msg);
                          final sender = (msg['sender'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
                          final senderName = (sender['name'] ?? 'Unknown').toString();
                          final messageText = (msg['text'] ?? '').toString();
                          final imageUrl = _extractImageUrlFromMessageText(messageText);
                          final caption = _extractCaptionFromMessageText(messageText);

                          final avatarUrl = (sender['avatar'] ?? '').toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMine) ...[
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0x35FFFFFF),
                                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl.isEmpty
                                        ? Text(
                                            senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 280),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: isMine ? const Color(0xFF4C8CFF) : const Color(0x30FFFFFF),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isMine ? 16 : 4),
                                        bottomRight: Radius.circular(isMine ? 4 : 16),
                                      ),
                                      border: Border.all(
                                        color: isMine ? const Color(0x80A5C7FF) : const Color(0x35FFFFFF),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (imageUrl != null) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.network(
                                              imageUrl,
                                              height: 150,
                                              width: 220,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          if (caption.isNotEmpty) const SizedBox(height: 6),
                                        ],
                                        if (caption.isNotEmpty || imageUrl == null)
                                          Text(
                                            caption.isEmpty ? messageText : caption,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white,
                                              height: 1.25,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
