import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workflow_state.dart';

class WorkflowController extends ChangeNotifier {
  // one key for all local workflow state, keeps storage simple.
  static const String _storageKey = 'gryphx-workflow-v2';

  WorkflowState _state = WorkflowState.defaults();
  SharedPreferences? _prefs;

  WorkflowState get state => _state;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final String? raw = _prefs?.getString(_storageKey);

    // no saved state yet? cool, start from defaults.
    if (raw == null || raw.trim().isEmpty) {
      _state = WorkflowState.defaults();
      unawaited(_persist());
      return;
    }

    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        jsonDecode(raw) as Map,
      );
      _state = WorkflowState.mergeWithDefaults(decoded);
    } catch (_) {
      _state = WorkflowState.defaults();
      unawaited(_persist());
    }
  }

  void setVerifiedEmail(String email) {
    _state = _state.copyWith(verifiedEmail: email.toLowerCase());
    _notifyAndSave();
  }

  void markNotificationRead(String notificationId) {
    _state = _state.copyWith(
      notifications: _state.notifications
          .map(
            (WorkflowNotification notification) =>
                notification.id == notificationId
                ? notification.copyWith(read: true)
                : notification,
          )
          .toList(growable: false),
    );
    _notifyAndSave();
  }

  void scheduleMeetup(String tradeId, String location, String meetupTime) {
    final WorkflowTradeState? tradeState = _state.tradeStates[tradeId];
    if (tradeState == null) {
      return;
    }

    _state = _state.copyWith(
      tradeStates: <String, WorkflowTradeState>{
        ..._state.tradeStates,
        tradeId: tradeState.copyWith(
          status: WorkflowTradeStatus.scheduled,
          meetupLocation: location,
          meetupTime: meetupTime,
        ),
      },
    );
    _notifyAndSave();
  }

  void setTradeReady(String tradeId) {
    final WorkflowTradeState? tradeState = _state.tradeStates[tradeId];
    if (tradeState == null) {
      return;
    }

    _state = _state.copyWith(
      tradeStates: <String, WorkflowTradeState>{
        ..._state.tradeStates,
        tradeId: tradeState.copyWith(status: WorkflowTradeStatus.ready),
      },
    );
    _notifyAndSave();
  }

  void updateTradeMatches(String tradeId, int matchesFound) {
    final WorkflowTradeState? tradeState = _state.tradeStates[tradeId];
    if (tradeState == null) {
      return;
    }

    _state = _state.copyWith(
      tradeStates: <String, WorkflowTradeState>{
        ..._state.tradeStates,
        tradeId: tradeState.copyWith(matchesFound: matchesFound),
      },
    );
    _notifyAndSave();
  }

  void completeTransaction(
    String tradeId,
    String listingId,
    TransactionMode mode,
  ) {
    final WorkflowTradeState? tradeState = _state.tradeStates[tradeId];

    final Map<String, WorkflowTradeState> nextTradeStates =
        Map<String, WorkflowTradeState>.from(_state.tradeStates);
    if (tradeState != null) {
      nextTradeStates[tradeId] = tradeState.copyWith(
        status: WorkflowTradeStatus.completed,
      );
    }

    final List<String> nextHiddenListingIds = List<String>.from(
      _state.hiddenListingIds,
    );
    if (!nextHiddenListingIds.contains(listingId)) {
      nextHiddenListingIds.add(listingId);
    }

    final Map<String, String> nextListingOutcome = Map<String, String>.from(
      _state.listingOutcome,
    )..[listingId] = mode == TransactionMode.sale ? 'sold' : 'traded';

    _state = _state.copyWith(
      trustScore: _state.trustScore + (mode == TransactionMode.sale ? 6 : 8),
      tradeStates: nextTradeStates,
      hiddenListingIds: nextHiddenListingIds,
      listingOutcome: nextListingOutcome,
    );
    _notifyAndSave();
  }

  void resetWorkflowState() {
    _state = WorkflowState.defaults();
    _notifyAndSave();
  }

  void addWishlistItem(String item) {
    final String normalized = item.trim();
    if (normalized.isEmpty) {
      return;
    }

    final bool exists = _state.wishlist.any(
      (String entry) => entry.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) {
      return;
    }

    _state = _state.copyWith(
      wishlist: <String>[..._state.wishlist, normalized],
    );
    _notifyAndSave();
  }

  void removeWishlistItem(String item) {
    _state = _state.copyWith(
      wishlist: _state.wishlist
          .where((String entry) => entry.toLowerCase() != item.toLowerCase())
          .toList(growable: false),
    );
    _notifyAndSave();
  }

  void _notifyAndSave() {
    // notify first so ui updates right away, then persist in background.
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    await _prefs?.setString(_storageKey, jsonEncode(_state.toJson()));
  }
}
