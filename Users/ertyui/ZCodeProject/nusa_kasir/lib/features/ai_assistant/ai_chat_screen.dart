import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/ai_service.dart';
import 'package:nusa_kasir/core/agent/agent_tools.dart';
import 'package:nusa_kasir/core/agent/agent_harness.dart';
import 'package:nusa_kasir/core/agent/agent_action_controller.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:nusa_kasir/data/database/app_database.dart';

int _maxContextChars = 4000;

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});
  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <ChatMessage>[];
  bool _loading = false;
  String? _storeName;
  int? _activeSessionId;
  List<ChatSession> _sessions = [];
  bool _showSessions = false;

  // Drawer animation
  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;

  // Agent thinking & execution tracking
  String _thinkingLabel = '';
  List<AgentExecutionStep> _executionSteps = [];
  AgentActionProposal? _currentProposal;

  final List<String> _hints = [
    "Produk hampir habis",
    "Analisis penjualan bulan ini",
    "Top produk terlaris",
    "Cari harga indomie di web",
    "Ringkasan keuangan hari ini",
    "Siapa pelanggan saya?",
    "Promo yang aktif",
  ];

  // Agent Operating Mode (Full Access vs Ask Before Action)
  AgentOperatingMode _operatingMode = AgentOperatingMode.askBeforeAction;
  AgentActionEvent? _currentAgentAction;
  StreamSubscription<AgentActionEvent>? _agentSub;
  StreamSubscription<List<AgentExecutionStep>>? _stepSub;
  StreamSubscription<AgentActionProposal?>? _proposalSub;

  @override
  void initState() {
    super.initState();
    _operatingMode = AgentHarness.I.mode;

    _agentSub = AgentActionController.I.stream.listen((ev) {
      if (!mounted) return;
      setState(() {
        _currentAgentAction = ev.isFinished ? null : ev;
      });
    });

    _stepSub = AgentHarness.I.stepStream.listen((steps) {
      if (!mounted) return;
      setState(() => _executionSteps = steps);
      _scrollToBottom();
    });

    _proposalSub = AgentHarness.I.proposalStream.listen((prop) {
      if (!mounted) return;
      setState(() => _currentProposal = prop);
      _scrollToBottom();
    });

    _drawerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _drawerAnim = CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOutCubic);
    _loadStoreName();
    _loadSessions();
    _messages.add(ChatMessage(
      role: 'assistant',
      content: 'Halo! Saya Nusa AI Agent POS ⚡ Saya bisa membantu analisis bisnis, scrape info produk dari web, mengunduh foto otomatis, hingga eksekusi perubahan data langsung.',
    ));
  }

  @override
  void dispose() {
    _agentSub?.cancel();
    _stepSub?.cancel();
    _proposalSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _drawerCtrl.dispose();
    super.dispose();
  }

  void _switchOperatingMode(AgentOperatingMode mode) {
    setState(() {
      _operatingMode = mode;
      AgentHarness.I.setMode(mode);
    });
  }

  void _toggleDrawer() {
    setState(() => _showSessions = !_showSessions);
    if (_showSessions) {
      _drawerCtrl.forward();
    } else {
      _drawerCtrl.reverse();
    }
  }

  Future<void> _loadSessions() async {
    final db = ref.read(databaseProvider);
    final list = await (db.select(db.chatSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    if (mounted) setState(() => _sessions = list);
  }

  Future<void> _saveCurrentSession() async {
    if (_visibleMessages.length <= 1) return;
    final db = ref.read(databaseProvider);
    final title = _autoTitle();
    final jsonStr = jsonEncode(_visibleMessages.map((m) => m.toJson()).toList());

    if (_activeSessionId == null) {
      final id = await db.into(db.chatSessions).insert(ChatSessionsCompanion.insert(
            title: title,
            messagesJson: jsonStr,
          ));
      _activeSessionId = id;
    } else {
      await (db.update(db.chatSessions)..where((t) => t.id.equals(_activeSessionId!)))
          .write(ChatSessionsCompanion(
        title: Value(title),
        messagesJson: Value(jsonStr),
        updatedAt: Value(DateTime.now()),
      ));
    }
    _loadSessions();
  }

  void _newChat() {
    _saveCurrentSession();
    setState(() {
      _messages.clear();
      _activeSessionId = null;
      _executionSteps.clear();
      AgentHarness.I.clearSteps();
      _messages.add(ChatMessage(
        role: 'assistant',
        content: 'Sesi baru dimulai. Ada yang bisa dibantu hari ini?',
      ));
    });
    if (_showSessions) _toggleDrawer();
  }

  void _loadSession(ChatSession s) {
    try {
      final list = (jsonDecode(s.messagesJson) as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
      setState(() {
        _activeSessionId = s.id;
        _messages.clear();
        _messages.addAll(list);
        _executionSteps.clear();
        AgentHarness.I.clearSteps();
      });
      _scrollToBottom();
    } catch (_) {}
    if (_showSessions) _toggleDrawer();
  }

  Future<void> _deleteSession(ChatSession s) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.chatSessions)..where((t) => t.id.equals(s.id))).go();
    if (_activeSessionId == s.id) _newChat();
    _loadSessions();
  }

  List<ChatMessage> get _visibleMessages =>
      _messages.where((m) => m.role != 'tool').toList();

  double get _contextUsage {
    final total = _visibleMessages.fold<int>(0, (sum, m) => sum + m.content.length);
    return (total / _maxContextChars).clamp(0.0, 1.0);
  }

  String _autoTitle() {
    final firstUser = _visibleMessages.where((m) => m.role == 'user').firstOrNull;
    if (firstUser == null) return 'Chat Baru';
    final words = firstUser.content.split(' ');
    return words.take(6).join(' ') + (words.length > 6 ? '...' : '');
  }

  Future<void> _loadStoreName() async {
    final name = await ref.read(settingsRepoProvider).getStoreName();
    if (mounted && name.isNotEmpty) setState(() => _storeName = name);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    final owner = await AiService.ownerId();
    final db = ref.read(databaseProvider);
    final tools = AgentToolRegistry.forVariant();
    final toolDefs = tools.map((t) => t.toOpenAiTool()).toList();

    AgentHarness.I.clearSteps();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
      _thinkingLabel = 'Memulai proses harness...';
    });
    _inputCtrl.clear();
    _scrollToBottom();

    final visible = _visibleMessages;
    final recent = visible.length > 6
        ? visible.sublist(visible.length - 6)
        : List<ChatMessage>.from(visible);

    final settings = await AiService.getSettings(owner);
    if (mounted) {
      setState(() {
        _thinkingLabel = settings?.isCustom == true
            ? 'Model: ${settings?.model ?? 'default'} (custom)'
            : 'Model: ${settings?.model ?? 'default'}';
      });
    }

    try {
      for (int round = 0; round < 3; round++) {
        final buffer = StringBuffer();
        final streamMsg = ChatMessage(role: 'assistant', content: '');
        if (mounted) setState(() => _messages.add(streamMsg));
        _scrollToBottom();

        final toolCalls = await AiService.chatStream(
          messages: recent,
          tools: toolDefs,
          storeName: _storeName,
          owner: owner,
          onEvent: (ev) {
            if (ev.delta != null && mounted) {
              buffer.write(ev.delta);
              final idx = _indexOfMessage(streamMsg);
              setState(() {
                if (idx >= 0) {
                  _messages[idx] = ChatMessage(
                    role: 'assistant',
                    content: buffer.toString(),
                  );
                }
              });
              _scrollToBottom();
            }
          },
        );

        if (!mounted) return;

        if (toolCalls != null && toolCalls.isNotEmpty) {
          final tc = toolCalls.last;
          final tool = tools.where((t) => t.name == tc.name).firstOrNull;
          if (tool != null) {
            final stepId = 'step_${DateTime.now().millisecondsSinceEpoch}';
            AgentHarness.I.addStep(AgentExecutionStep(
              id: stepId,
              title: _getToolFriendlyName(tc.name),
              detail: tc.arguments.toString(),
              status: AgentStepStatus.running,
              toolName: tc.name,
              toolArgs: tc.arguments,
            ));

            setState(() => _thinkingLabel = 'Menjalankan: ${tc.name}...');
            _scrollToBottom();

            try {
              final rawResult = await tool.execute(db, tc.arguments);
              final truncated = rawResult.length > 2000;
              final result = truncated
                  ? '${rawResult.substring(0, 2000)}\n...(hasil dipotong, ${rawResult.length} karakter)'
                  : rawResult;

              AgentHarness.I.updateStep(stepId, status: AgentStepStatus.success, output: result);

              _messages.add(ChatMessage(
                role: 'assistant',
                content: buffer.toString(),
                toolCallId: tc.id,
                toolName: tc.name,
                toolArgs: tc.arguments,
              ));
              final toolMsg = ChatMessage(
                role: 'tool',
                content: result,
                toolCallId: tc.id,
                toolName: tc.name,
              );
              _messages.add(toolMsg);
              recent.add(ChatMessage(
                role: 'assistant',
                content: buffer.toString(),
                toolCallId: tc.id,
                toolName: tc.name,
                toolArgs: tc.arguments,
              ));
              recent.add(toolMsg);
            } catch (e) {
              AgentHarness.I.updateStep(stepId, status: AgentStepStatus.failed, output: e.toString());
              _messages.add(ChatMessage(
                role: 'tool',
                content: '{"error": "$e"}',
                toolCallId: tc.id,
                toolName: tc.name,
              ));
            }
            continue;
          }
        }

        if (buffer.isNotEmpty) {
          _saveCurrentSession();
          if (mounted) {
            setState(() {
              _loading = false;
              _thinkingLabel = '';
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Proses selesai dijalankan.',
          ));
          _loading = false;
          _thinkingLabel = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: 'Gagal: $e'));
          _loading = false;
          _thinkingLabel = '';
        });
      }
    }
  }

  String _getToolFriendlyName(String toolName) {
    switch (toolName) {
      case 'web_search_product':
        return '🔍 Mencari Info & Harga di Web';
      case 'create_product':
        return '📦 Menambah Produk ke Database';
      case 'update_stock':
        return '📊 Menyesuaikan Stok Barang';
      case 'create_customer':
        return '👤 Mendaftarkan Pelanggan Baru';
      case 'get_products':
        return '📋 Mengambil Data Produk';
      case 'get_low_stock':
        return '⚠️ Memeriksa Stok Menipis';
      case 'get_summary':
        return '📈 Menghitung Ringkasan Penjualan';
      default:
        return '⚡ Menjalankan $toolName';
    }
  }

  int _indexOfMessage(ChatMessage needle) {
    for (int i = 0; i < _messages.length; i++) {
      if (identical(_messages[i], needle)) return i;
    }
    return -1;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [NusaConfig.activePrimary, NusaConfig.activePrimary.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: NusaConfig.activePrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nusa AI Agent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                  _operatingMode == AgentOperatingMode.fullAccess ? '⚡ Full Access' : '🛡️ Ask Before Action',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _operatingMode == AgentOperatingMode.fullAccess ? Colors.orange : NusaConfig.accentGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(_showSessions ? Icons.close_rounded : Icons.history_rounded),
          onPressed: _toggleDrawer,
        ),
        actions: [
          // Mode Switcher Dropdown / Toggle
          PopupMenuButton<AgentOperatingMode>(
            icon: Icon(
              _operatingMode == AgentOperatingMode.fullAccess ? Icons.bolt_rounded : Icons.shield_rounded,
              color: _operatingMode == AgentOperatingMode.fullAccess ? Colors.orange : NusaConfig.activePrimary,
            ),
            tooltip: 'Ganti Mode Agent',
            onSelected: _switchOperatingMode,
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: AgentOperatingMode.askBeforeAction,
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: NusaConfig.accentGreen, size: 20),
                    const SizedBox(width: 10),
                    const Text('Ask Before Action (Aman)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AgentOperatingMode.fullAccess,
                child: Row(
                  children: const [
                    Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Text('Full Access (Autonomous)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Chat Baru',
            onPressed: _newChat,
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildChatArea(isDark),

          // Live Ghost Virtual Typing Pointer Overlay
          if (_currentAgentAction != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xE61E293B) : const Color(0xF2FFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NusaConfig.activePrimary.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: NusaConfig.activePrimary.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: NusaConfig.activePrimary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                _currentAgentAction!.action,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              if (_currentAgentAction!.isTyping) ...[
                                const SizedBox(width: 4),
                                const Text('▋', style: TextStyle(color: Colors.blue, fontSize: 12)),
                              ],
                            ],
                          ),
                          if (_currentAgentAction!.typedText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '"${_currentAgentAction!.typedText}"',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            )
                          else if (_currentAgentAction!.detail != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _currentAgentAction!.detail!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Drawer
          if (_showSessions) ...[
            FadeTransition(
              opacity: _drawerAnim,
              child: GestureDetector(
                onTap: _toggleDrawer,
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
            AnimatedBuilder(
              animation: _drawerAnim,
              builder: (_, child) {
                return Positioned(
                  left: -(280 * (1 - _drawerAnim.value)),
                  top: 0,
                  bottom: 0,
                  width: 280,
                  child: _buildSessionDrawer(isDark),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionDrawer(bool isDark) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : Colors.white,
        border: Border(
          right: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Riwayat Sesi Agent',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
            ),
          ),
          const Divider(),
          Expanded(
            child: _sessions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Belum ada riwayat',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13,
                              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                    ),
                  )
                : ListView(
                    children: _sessions.map((s) {
                      final active = s.id == _activeSessionId;
                      return ListTile(
                        dense: true,
                        selected: active,
                        selectedTileColor: NusaConfig.activePrimary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        title: Text(s.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          _formatDate(s.updatedAt),
                          style: TextStyle(fontSize: 11,
                              color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () => _deleteSession(s),
                        ),
                        onTap: () => _loadSession(s),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea(bool isDark) {
    return Column(
      children: [
        // Status Top Sub-bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          color: NusaConfig.activePrimary.withValues(alpha: 0.05),
          child: Row(
            children: [
              Icon(Icons.circle, size: 7, color: _operatingMode == AgentOperatingMode.fullAccess ? Colors.orange : NusaConfig.accentGreen),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _storeName != null ? 'Toko: $_storeName' : 'Toko Aktif',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (_visibleMessages.length > 2) ...[
                Text('Context: ${(_contextUsage * 100).toInt()}%',
                    style: TextStyle(fontSize: 9.5, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('CLOUD AI',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: NusaConfig.accentGreen)),
              ),
            ],
          ),
        ),

        // Chat Feed & Step Visualizer
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _visibleMessages.length + (_executionSteps.isNotEmpty ? 1 : 0) + (_currentProposal != null ? 1 : 0) + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i < _visibleMessages.length) {
                return _bubble(_visibleMessages[i], isDark);
              }
              int nextIndex = i - _visibleMessages.length;
              if (_executionSteps.isNotEmpty && nextIndex == 0) {
                return _buildStepperAccordion(isDark);
              }
              if (_currentProposal != null && (_executionSteps.isEmpty ? nextIndex == 0 : nextIndex == 1)) {
                return _buildProposalCard(_currentProposal!, isDark);
              }
              return _thinkingBubble(isDark);
            },
          ),
        ),

        // Quick hints
        if (_hints.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _hints.map((hint) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(hint, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                      onPressed: _loading ? null : () {
                        _inputCtrl.text = hint;
                        _send();
                      },
                      backgroundColor: isDark
                          ? NusaConfig.darkSurface2
                          : NusaConfig.backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        // Floating Input Island
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : Colors.white,
            border: Border(
              top: BorderSide(
                  color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Perintahkan AI (tanya, tambah produk, cari web)...',
                      hintStyle: TextStyle(fontSize: 13,
                          color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                      filled: true,
                      fillColor: isDark
                          ? NusaConfig.darkSurface2
                          : NusaConfig.backgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _loading
                        ? NusaConfig.activePrimary.withValues(alpha: 0.3)
                        : NusaConfig.activePrimary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _loading ? null : _send,
                    icon: Icon(_loading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepperAccordion(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? NusaConfig.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, size: 16, color: NusaConfig.accentGreen),
              const SizedBox(width: 8),
              const Text('Alur Eksekusi Harness (Codex Engine)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ..._executionSteps.map((s) {
            final isRunning = s.status == AgentStepStatus.running;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isRunning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          s.status == AgentStepStatus.success
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 15,
                          color: s.status == AgentStepStatus.success ? NusaConfig.accentGreen : Colors.red,
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        if (s.detail != null)
                          Text(s.detail!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProposalCard(AgentActionProposal prop, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.orange, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Konfirmasi Aksi Data',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange)),
                    Text(prop.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              jsonEncode(prop.arguments),
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => prop.reject(),
                child: const Text('Batalkan', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => prop.approve(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NusaConfig.activePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Izinkan & Eksekusi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage msg, bool isDark) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: NusaConfig.activePrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 15, color: NusaConfig.activePrimary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? NusaConfig.activePrimary
                    : (isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: isUser
                          ? Colors.white
                          : (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.timestamp),
                    style: TextStyle(
                      fontSize: 9,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.55)
                          : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thinkingBubble(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: NusaConfig.activePrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 15, color: NusaConfig.activePrimary),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                  color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dot(isDark: isDark),
                    const SizedBox(width: 3),
                    _dot(delay: 200, isDark: isDark),
                    const SizedBox(width: 3),
                    _dot(delay: 400, isDark: isDark),
                  ],
                ),
                if (_thinkingLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _thinkingLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot({int delay = 0, required bool isDark}) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
        shape: BoxShape.circle,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
