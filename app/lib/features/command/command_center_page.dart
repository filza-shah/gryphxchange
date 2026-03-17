import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_bottom_nav.dart';
import '../../models/mock_data.dart';
import '../../services/workflow/workflow_controller.dart';
import '../../services/workflow/workflow_state.dart';

class CommandCenterPage extends StatefulWidget {
  const CommandCenterPage({
    super.key,
    required this.tradeId,
    required this.workflowController,
  });

  final String tradeId;
  final WorkflowController workflowController;

  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  // meetup picks from user flow.
  String _selectedZone = '';
  String _meetupTime = '2026-03-08 14:00';
  final TextEditingController _meetupTimeController = TextEditingController();

  // chat is mock for now, but keeps the command center feeling alive.
  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      id: 'msg-1',
      sender: ChatSender.them,
      text: 'Hey! Condition is great. Can we meet near University Centre?',
    ),
    const _ChatMessage(
      id: 'msg-2',
      sender: ChatSender.me,
      text: 'Works for me. I can do 2:00 PM.',
    ),
  ];

  Trade get _trade {
    // if the id is weird/missing, just fall back to first trade so page still works.
    return mockTrades
            .where((Trade item) => item.id == widget.tradeId)
            .fold<Trade?>(null, (Trade? _, Trade item) => item) ??
        mockTrades.first;
  }

  @override
  void initState() {
    super.initState();

    final WorkflowState state = widget.workflowController.state;
    final WorkflowTradeState? workflowTrade = state.tradeStates[_trade.id];

    _selectedZone = workflowTrade?.meetupLocation ?? '';
    _meetupTime = workflowTrade?.meetupTime ?? '2026-03-08 14:00';
    _meetupTimeController.text = _meetupTime;

    // super important: mark reads after first frame to avoid build-time notifier issues.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final WorkflowState latestState = widget.workflowController.state;
      for (final WorkflowNotification notification
          in latestState.notifications.where(
            (WorkflowNotification n) => n.tradeId == _trade.id && !n.read,
          )) {
        widget.workflowController.markNotificationRead(notification.id);
      }
    });
  }

  WorkflowTradeState? _workflowTrade(WorkflowState state) {
    // local helper so build stays cleaner.
    return state.tradeStates[_trade.id];
  }

  String _statusLabel(WorkflowTradeState? workflowTrade) {
    // map enum to short UI label.
    if (workflowTrade == null) {
      return 'Accepted';
    }

    switch (workflowTrade.status) {
      case WorkflowTradeStatus.scheduled:
        return 'Scheduled';
      case WorkflowTradeStatus.ready:
        return 'Ready';
      case WorkflowTradeStatus.completed:
        return 'Completed';
      case WorkflowTradeStatus.pending:
        return 'Pending';
      case WorkflowTradeStatus.accepted:
        return 'Accepted';
    }
  }

  TransactionMode _transactionMode(WorkflowTradeState? workflowTrade) {
    // fallback uses trade offer type from mock trade itself.
    if (workflowTrade != null) {
      return workflowTrade.mode;
    }

    return _trade.offerType == OfferType.trade
        ? TransactionMode.trade
        : TransactionMode.sale;
  }

  Future<void> _pickDateTime() async {
    final DateTime now = DateTime.now();

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _meetupTime =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      _meetupTimeController.text = _meetupTime;
    });
  }

  void _acceptMeetup() {
    // basic guard if picker not done yet.
    if (_selectedZone.isEmpty || _meetupTime.isEmpty) {
      return;
    }

    widget.workflowController.scheduleMeetup(
      _trade.id,
      _selectedZone,
      _meetupTime,
    );

    final String zoneName =
        campusSafeZones
            .where((SafeZone zone) => zone.id.toString() == _selectedZone)
            .fold<SafeZone?>(null, (SafeZone? _, SafeZone item) => item)
            ?.name ??
        'Selected Safe Zone';

    setState(() {
      _messages.add(
        _ChatMessage(
          id: 'sys-${DateTime.now().millisecondsSinceEpoch}',
          sender: ChatSender.system,
          text: 'Meetup accepted at $zoneName. Status moved to Scheduled.',
        ),
      );
    });
  }

  void _continueToVerification() {
    // no dedicated verify/qr route wired on this branch yet, so we mark ready + toast.
    widget.workflowController.setTradeReady(_trade.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Trade marked as Ready. QR verify screen can plug in next.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _meetupTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.workflowController,
      builder: (BuildContext context, Widget? child) {
        // read live workflow each frame so status chip updates instantly.
        final WorkflowState state = widget.workflowController.state;
        final WorkflowTradeState? workflowTrade = _workflowTrade(state);
        final String statusLabel = _statusLabel(workflowTrade);
        final TransactionMode mode = _transactionMode(workflowTrade);
        final bool canContinueToVerify =
            statusLabel == 'Scheduled' || statusLabel == 'Ready';

        return Scaffold(
          // keep nav highlighted on trades since command center sits in that flow.
          bottomNavigationBar: const AppBottomNav(currentRoute: '/trades'),
          body: Column(
            children: <Widget>[
              // top command header.
              Container(
                color: const Color(0xFF8B0000),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => context.go('/trades'),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Transaction Command Center',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(statusLabel),
                        backgroundColor: const Color(0xFFFFD700),
                        labelStyle: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    // summary card of what trade this command center is about.
                    Card(
                      child: ListTile(
                        title: Text(
                          _trade.listing.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          mode == TransactionMode.trade
                              ? 'Mode: Trade Handshake'
                              : 'Mode: Sale Handshake',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // live chat block from the prototype.
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Live Chat',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            for (final _ChatMessage message in _messages)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: message.sender == ChatSender.me
                                      ? const Color(0x148B0000)
                                      : message.sender == ChatSender.system
                                      ? const Color(0x1A22C55E)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    CircleAvatar(
                                      radius: 11,
                                      child: Text(
                                        message.sender == ChatSender.me
                                            ? 'A'
                                            : message.sender == ChatSender.them
                                            ? 'B'
                                            : '!',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(message.text)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // meetup scheduler block (safe zone + time).
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Location Picker Widget',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedZone.isEmpty
                                  ? null
                                  : _selectedZone,
                              decoration: const InputDecoration(
                                labelText: 'Safe Zone',
                                border: OutlineInputBorder(),
                              ),
                              items: campusSafeZones
                                  .map(
                                    (SafeZone zone) => DropdownMenuItem<String>(
                                      value: zone.id.toString(),
                                      child: Text(zone.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedZone = value ?? '';
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              readOnly: true,
                              onTap: _pickDateTime,
                              controller: _meetupTimeController,
                              decoration: const InputDecoration(
                                labelText: 'Meetup Time',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_month),
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed:
                                  _selectedZone.isEmpty || _meetupTime.isEmpty
                                  ? null
                                  : _acceptMeetup,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF8B0000),
                              ),
                              child: const Text('Accept Meetup'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: canContinueToVerify
                                  ? _continueToVerification
                                  : null,
                              child: const Text('Continue to Verification'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum ChatSender { me, them, system }

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
  });

  final String id;
  final ChatSender sender;
  final String text;
}
