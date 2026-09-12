import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/ai_service.dart';
import 'package:nusa_kasir/core/agent/agent_tools.dart';
import 'package:nusa_kasir/core/agent/agent_harness.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:nusa_kasir/data/database/app_database.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});
  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final _messages = <ChatMessage>[];
  bool _loading = false;
  String? _storeName;
  int? _activeSessionId;
  List<ChatSession> _sessions = [];
  bool _showSessions = false;

  // Drawer Animation (Modern Sidebar)
  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;

  // Agent Execution & Proposal Subscriptions
  List<AgentExecutionStep> _executionSteps = [];
  AgentActionProposal? _currentProposal;
  StreamSubscription<List<AgentExecutionStep>>? _stepSub;
  StreamSubscription<AgentActionProposal?>? _proposalSub;

  // Antigravity / Codex AI Agent Mode Toggle
  bool _isAgentActive = true;
  AgentOperatingMode _operatingMode = AgentOperatingMode.askBeforeAction;

  // Mention (@) & Slash Command (/) Autocomplete Trigger State
  String? _popupTrigger; // '@' or '/' or null
  List<Map<String, String>> _filteredSuggestions = [];

  final List<Map<String, String>> _slashCommands = [
    {'title': '/cari_produk', 'desc': 'Cari produk & harga di web internet', 'icon': 'search'},
    {'title': '/tambah_produk', 'desc': 'Tambah produk baru otomatis via AI', 'icon': 'add_box'},
    {'title': '/analisis_laba', 'desc': 'Analisis keuntungan dan performa toko', 'icon': 'analytics'},
    {'title': '/cek_stok', 'desc': 'Periksa produk yang menipis dan perlu restock', 'icon': 'inventory_2'},
    {'title': '/ringkasan_hari_ini', 'desc': 'Ringkasan transaksi kasir hari ini', 'icon': 'receipt_long'},
  ];

  final List<Map<String, String>> _contextMentions = [
    {'title': '@stok', 'desc': 'Konteks seluruh inventori & stok toko', 'icon': 'inventory'},
    {'title': '@penjualan', 'desc': 'Konteks histori transaksi & laporan penjualan', 'icon': 'point_of_sale'},
    {'title': '@pelanggan', 'desc': 'Konteks daftar pelanggan dan riwayat piutang', 'icon': 'group'},
    {'title': '@pengeluaran', 'desc': 'Konteks riwayat biaya operasional', 'icon': 'payments'},
  ];

  @override
  void initState() {
    super.initState();
    _operatingMode = AgentHarness.I.mode;

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
      duration: const Duration(milliseconds: 260),
    );
    _drawerAnim = CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOutQuart);

    _inputCtrl.addListener(_handleInputChanged);
    _loadStoreName();
    _loadSessions();

    _messages.add(ChatMessage(
      role: 'assistant',
      content: 'Selamat datang. Saya asisten cerdas toko Anda. Ketik pesan, gunakan `/` untuk perintah cepat, atau `@` untuk melampirkan konteks bisnis.',
    ));
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _proposalSub?.cancel();
    _inputCtrl.removeListener(_handleInputChanged);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _drawerCtrl.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    final text = _inputCtrl.text;
    final selection = _inputCtrl.selection;
    if (!selection.isValid || selection.baseOffset <= 0) {
      if (_popupTrigger != null) setState(() => _popupTrigger = null);
      return;
    }

    final upToCursor = text.substring(0, selection.baseOffset);
    final lastWord = upToCursor.split(RegExp(r'\s+')).lastOrNull ?? '';

    if (lastWord.startsWith('/')) {
      final query = lastWord.substring(1).toLowerCase();
      setState(() {
        _popupTrigger = '/';
        _filteredSuggestions = _slashCommands
            .where((c) => c['title']!.toLowerCase().contains(query) || c['desc']!.toLowerCase().contains(query))
            .toList();
      });
    } else if (lastWord.startsWith('@')) {
      final query = lastWord.substring(1).toLowerCase();
      setState(() {
        _popupTrigger = '@';
        _filteredSuggestions = _contextMentions
            .where((m) => m['title']!.toLowerCase().contains(query) || m['desc']!.toLowerCase().contains(query))
            .toList();
      });
    } else {
      if (_popupTrigger != null) setState(() => _popupTrigger = null);
    }
  }

  void _applySuggestion(String itemTitle) {
    final text = _inputCtrl.text;
    final selection = _inputCtrl.selection;
    final upToCursor = text.substring(0, selection.baseOffset);
    final lastSpaceIdx = upToCursor.lastIndexOf(RegExp(r'\s'));
    final prefix = lastSpaceIdx >= 0 ? upToCursor.substring(0, lastSpaceIdx + 1) : '';
    final remainder = text.substring(selection.baseOffset);

    final newText = '$prefix$itemTitle $remainder';
    _inputCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: prefix.length + itemTitle.length + 1),
    );
    setState(() => _popupTrigger = null);
    _focusNode.requestFocus();
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
        content: 'Sesi baru dimulai. Apa yang ingin Anda kerjakan sekarang?',
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

  String _autoTitle() {
    final firstUser = _visibleMessages.where((m) => m.role == 'user').firstOrNull;
    if (firstUser == null) return 'Sesi Baru';
    final words = firstUser.content.split(' ');
    return words.take(5).join(' ') + (words.length > 5 ? '...' : '');
  }

  Future<void> _loadStoreName() async {
    final name = await ref.read(settingsRepoProvider).getStoreName();
    if (mounted && name.isNotEmpty) setState(() => _storeName = name);
  }

  Future<void> _pickFileAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'txt', 'jpg', 'png', 'pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final fileName = result.files.single.name;
        setState(() {
          _inputCtrl.text = '${_inputCtrl.text} [File: $fileName] '.trimLeft();
        });
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    final owner = await AiService.ownerId();
    final db = ref.read(databaseProvider);
    final tools = _isAgentActive ? AgentToolRegistry.forVariant() : <AgentTool>[];
    final toolDefs = tools.map((t) => t.toOpenAiTool()).toList();

    AgentHarness.I.clearSteps();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
      _popupTrigger = null;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    final visible = _visibleMessages;
    final recent = visible.length > 6
        ? visible.sublist(visible.length - 6)
        : List<ChatMessage>.from(visible);

    try {
      for (int round = 0; round < 3; round++) {
        final buffer = StringBuffer();
        final streamMsg = ChatMessage(role: 'assistant', content: '');
        if (mounted) setState(() => _messages.add(streamMsg));
        _scrollToBottom();

        final toolCalls = await AiService.chatStream(
          messages: recent,
          tools: toolDefs.isNotEmpty ? toolDefs : null,
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

        if (toolCalls != null && toolCalls.isNotEmpty && _isAgentActive) {
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
            _scrollToBottom();

            try {
              final rawResult = await tool.execute(db, tc.arguments);
              final truncated = rawResult.length > 2000;
              final result = truncated
                  ? '${rawResult.substring(0, 2000)}\n...(dipotong ${rawResult.length} karakter)'
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
          if (mounted) setState(() => _loading = false);
          return;
        }
      }

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Eksekusi selesai.',
          ));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: 'Terjadi kendala: $e'));
          _loading = false;
        });
      }
    }
  }

  String _getToolFriendlyName(String toolName) {
    switch (toolName) {
      case 'web_search_product':
        return 'Mencari Info & Harga di Web';
      case 'create_product':
        return 'Menambahkan Produk ke Database';
      case 'update_stock':
        return 'Memperbarui Stok Barang';
      case 'create_customer':
        return 'Mendaftarkan Pelanggan Baru';
      case 'get_products':
        return 'Mengambil Data Produk';
      case 'get_low_stock':
        return 'Memeriksa Stok Menipis';
      case 'get_summary':
        return 'Menghitung Ringkasan Penjualan';
      default:
        return 'Menjalankan $toolName';
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(_showSessions ? Icons.menu_open_rounded : Icons.history_rounded, size: 22),
          onPressed: _toggleDrawer,
          tooltip: 'Riwayat Sesi',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Assistant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
            Text(
              _storeName != null ? 'Toko $_storeName' : 'Asisten Operasional',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 24),
            tooltip: 'Sesi Baru',
            onPressed: _newChat,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Main Chat Stream ──
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _visibleMessages.length +
                      (_executionSteps.isNotEmpty ? 1 : 0) +
                      (_currentProposal != null ? 1 : 0) +
                      (_loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i < _visibleMessages.length) {
                      return _buildMessageItem(_visibleMessages[i], isDark);
                    }
                    int nextIdx = i - _visibleMessages.length;
                    if (_executionSteps.isNotEmpty && nextIdx == 0) {
                      return _buildExecutionAccordion(isDark);
                    }
                    if (_currentProposal != null && (_executionSteps.isEmpty ? nextIdx == 0 : nextIdx == 1)) {
                      return _buildActionProposalCard(_currentProposal!, isDark);
                    }
                    return _buildThinkingState(isDark);
                  },
                ),
              ),

              // ── Autocomplete Overlay Box (@ & /) ──
              if (_popupTrigger != null && _filteredSuggestions.isNotEmpty)
                _buildAutocompleteBox(isDark),

              // ── Modern Floating Antigravity Prompt Console ──
              _buildConsoleBar(isDark),
            ],
          ),

          // ── Minimalist Clean Slide-out History Drawer ──
          if (_showSessions) ...[
            FadeTransition(
              opacity: _drawerAnim,
              child: GestureDetector(
                onTap: _toggleDrawer,
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            AnimatedBuilder(
              animation: _drawerAnim,
              builder: (_, child) {
                return Positioned(
                  left: -(300 * (1 - _drawerAnim.value)),
                  top: 0,
                  bottom: 0,
                  width: 300,
                  child: _buildHistorySidebar(isDark),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── History Sidebar (Slide-out) ──
  Widget _buildHistorySidebar(bool isDark) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Riwayat Percakapan',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _toggleDrawer,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Text('Belum ada riwayat',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
                    )
                  : ListView.builder(
                      itemCount: _sessions.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemBuilder: (_, idx) {
                        final s = _sessions[idx];
                        final active = s.id == _activeSessionId;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            title: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${s.updatedAt.day}/${s.updatedAt.month}/${s.updatedAt.year}',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              onPressed: () => _deleteSession(s),
                            ),
                            onTap: () => _loadSession(s),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Autocomplete Trigger Box (@ & /) ──
  Widget _buildAutocompleteBox(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _filteredSuggestions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, idx) {
          final item = _filteredSuggestions[idx];
          return InkWell(
            onTap: () => _applySuggestion(item['title']!),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _popupTrigger == '/' ? Icons.terminal_rounded : Icons.alternate_email_rounded,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(item['desc']!,
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Antigravity / Codex Console & Bottom Bar ──
  Widget _buildConsoleBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Control Ribbon (Agent Mode Toggle & Mode Chips)
            Row(
              children: [
                // Agent Master Toggle
                InkWell(
                  onTap: () {
                    setState(() => _isAgentActive = !_isAgentActive);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isAgentActive
                          ? NusaConfig.activePrimary.withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isAgentActive
                            ? NusaConfig.activePrimary
                            : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: _isAgentActive ? NusaConfig.activePrimary : (isDark ? Colors.white54 : Colors.black54),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Agent Mode',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _isAgentActive ? NusaConfig.activePrimary : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sub-mode pills (Active only when Agent Mode is ON)
                if (_isAgentActive) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      final newMode = _operatingMode == AgentOperatingMode.askBeforeAction
                          ? AgentOperatingMode.fullAccess
                          : AgentOperatingMode.askBeforeAction;
                      setState(() {
                        _operatingMode = newMode;
                        AgentHarness.I.setMode(newMode);
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _operatingMode == AgentOperatingMode.fullAccess ? Icons.bolt_rounded : Icons.shield_rounded,
                            size: 14,
                            color: _operatingMode == AgentOperatingMode.fullAccess ? Colors.orange : NusaConfig.accentGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _operatingMode == AgentOperatingMode.fullAccess ? 'Full Access' : 'Ask Before Action',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Quick Short Helper Icons
                IconButton(
                  icon: const Icon(Icons.alternate_email_rounded, size: 18),
                  tooltip: 'Sebut Konteks (@)',
                  onPressed: () {
                    _inputCtrl.text = '${_inputCtrl.text}@';
                    _focusNode.requestFocus();
                  },
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.terminal_rounded, size: 18),
                  tooltip: 'Perintah Cepat (/)',
                  onPressed: () {
                    _inputCtrl.text = '${_inputCtrl.text}/';
                    _focusNode.requestFocus();
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Input Row (+ button, TextField, Send button)
            Row(
              children: [
                // Plus (+) Attachment Button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                  tooltip: 'Lampirkan Berkas',
                  onPressed: _pickFileAttachment,
                ),
                const SizedBox(width: 4),

                // TextField Console
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: _isAgentActive
                            ? 'Instruksikan agent (ketik @ atau /)...'
                            : 'Tanya asisten...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Submit Button
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _loading
                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                        : NusaConfig.activePrimary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _loading ? null : _send,
                    icon: Icon(
                      _loading ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat Bubble Message ──
  Widget _buildMessageItem(ChatMessage msg, bool isDark) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 15, color: NusaConfig.activePrimary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? NusaConfig.activePrimary
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: isUser
                    ? null
                    : Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    msg.content,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: isUser ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isUser ? Colors.white60 : (isDark ? Colors.white38 : Colors.black38),
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

  // ── Codex / Antigravity Execution Stepper Accordion ──
  Widget _buildExecutionAccordion(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline_rounded, size: 16, color: NusaConfig.activePrimary),
              const SizedBox(width: 8),
              const Text('Alur Eksekusi Agent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ..._executionSteps.map((step) {
            final isRunning = step.status == AgentStepStatus.running;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isRunning
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : Icon(
                          step.status == AgentStepStatus.success ? Icons.check_circle_rounded : Icons.error_rounded,
                          size: 14,
                          color: step.status == AgentStepStatus.success ? NusaConfig.accentGreen : Colors.red,
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        if (step.detail != null)
                          Text(
                            step.detail!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontFamily: 'monospace',
                            ),
                          ),
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

  // ── Diff Proposal Card (Guardrail Approval) ──
  Widget _buildActionProposalCard(AgentActionProposal prop, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prop.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              jsonEncode(prop.arguments),
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => prop.reject(),
                child: const Text('Tolak', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => prop.approve(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NusaConfig.activePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Izinkan Eksekusi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Thinking State ──
  Widget _buildThinkingState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 15, color: NusaConfig.activePrimary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                const Text('Memproses...', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
