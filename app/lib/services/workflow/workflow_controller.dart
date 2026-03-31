import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workflow_state.dart';

/// Manages all workflow state for the app.
///
/// Extends [ChangeNotifier] so any widget watching this controller
/// automatically rebuilds when state changes.
///
/// Responsibilities:
/// - Loading and persisting state to [SharedPreferences]
/// - Exposing named action methods the UI can call
/// - Keeping state immutable — every change produces a new [WorkflowState]
///
/// Must call [init] once at startup before using any other methods.

class WorkflowController extends ChangeNotifier {
  // one key for all local workflow state, keeps storage simple.
  static const String _storageKey = 'gryphx-workflow-v2';

  
  /// The current state. Always replaced wholesale via [copyWith] — never mutated.
  WorkflowState _state = WorkflowState.defaults();
  SharedPreferences? _prefs;

  /// The current workflow state. Read-only — changes only happen through
  /// the action methods on this controller.
  WorkflowState get state => _state;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final String? raw = _prefs?.getString(_storageKey);

    // no saved state yet?  start from defaults.
    if (raw == null || raw.trim().isEmpty) {
      _state = WorkflowState.defaults();
      unawaited(_persist());
      return;
    }

    try {
      // Decode the JSON string back into a map and rebuild state from it.
      // mergeWithDefaults handles any missing fields from older app versions.
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        jsonDecode(raw) as Map,
      );
      _state = WorkflowState.mergeWithDefaults(decoded);
    } catch (_) {
      // Saved data was unreadable so we reset to defaults rather than crashing.
      // This can happen if storage was corrupted or the schema changed too drastically.
      _state = WorkflowState.defaults();
      unawaited(_persist());
    }
  }

  /// Saves the user's verified email address to state.
  /// Lowercased for consistency before storing.
  void setVerifiedEmail(String email) {
    _state = _state.copyWith(verifiedEmail: email.toLowerCase());
    _notifyAndSave();
  }

  /// Marks a single notification as read by its [notificationId].
  /// Maps over the full notifications list and replaces the matching entry
  /// with a copy where [WorkflowNotification.read] is true. All other
  /// notifications are left unchanged.
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

  /// Schedules a meetup for the given trade, advancing its status to [WorkflowTradeStatus.scheduled].
  ///
  /// Silently does nothing if [tradeId] doesn't exist in state LOL 
  /// this guard is used throughout the controller to avoid acting on stale IDs.
  void scheduleMeetup(String tradeId, String location, String meetupTime) {
    final WorkflowTradeState? tradeState = _state.tradeStates[tradeId];
    if (tradeState == null) {
      return;
    }
    // Spread existing trade states, then overwrite just the one being updated.
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

  /// Advances a trade's status to [WorkflowTradeStatus.ready].
  ///
  /// Called when both parties have confirmed they are ready to complete
  /// the exchange at the scheduled meetup.
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

   
  /// Updates how many potential matches were found for a trade.
  ///
  /// Called when the matching algorithm returns results for a given [tradeId].
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

  /// Adds a newly accepted trade to workflow state, if it does not already exist.
  void addAcceptedTrade(String tradeId, TransactionMode mode) {
    if (_state.tradeStates.containsKey(tradeId)) {
      return;
    }

    _state = _state.copyWith(
      tradeStates: <String, WorkflowTradeState>{
        ..._state.tradeStates,
        tradeId: WorkflowTradeState(
          tradeId: tradeId,
          mode: mode,
          status: WorkflowTradeStatus.accepted,
          meetupLocation: null,
          meetupTime: null,
          matchesFound: 0,
        ),
      },
    );
    _notifyAndSave();
  }
  /// Marks a transaction as fully complete, updating all related state in one atomic step.
  ///
  /// Does four things at once:
  /// 1. Advances the trade status to [WorkflowTradeStatus.completed]
  /// 2. Hides the listing from the browse UI via [WorkflowState.hiddenListingIds]
  /// 3. Records the outcome ('sold' or 'traded') in [WorkflowState.listingOutcome]
  /// 4. Awards trust score points (+6 for a sale, +8 for a trade)
  void completeTransaction(
    String tradeId,
    String listingId,
    TransactionMode mode,
  ) {
    final WorkflowTradeState? tradeState = _state.tradeStates[tradeId];

    // Step 1: mark the trade as completed.
    // Uses a mutable copy here (rather than spread) because we need to conditionally update it 
    final Map<String, WorkflowTradeState> nextTradeStates =
        Map<String, WorkflowTradeState>.from(_state.tradeStates);
    if (tradeState != null) {
      nextTradeStates[tradeId] = tradeState.copyWith(
        status: WorkflowTradeStatus.completed,
      );
    } else {
      nextTradeStates[tradeId] = WorkflowTradeState(
        tradeId: tradeId,
        mode: mode,
        status: WorkflowTradeStatus.completed,
        meetupLocation: null,
        meetupTime: null,
        matchesFound: 0,
      );
    }

    // Step 2: hide the listing from the browse UI.
    // Guard against duplicates in case completeTransaction is called twice.
    final List<String> nextHiddenListingIds = List<String>.from(
      _state.hiddenListingIds,
    );
    if (!nextHiddenListingIds.contains(listingId)) {
      nextHiddenListingIds.add(listingId);
    }

    
    // Step 3: record whether the listing was sold or traded.
    // The .. (cascade) operator lets us add the new entry and return the map in one expression.
    // Yes I forgot what cascade does so im explaining it here so no one else does :)
    final Map<String, String> nextListingOutcome = Map<String, String>.from(
      _state.listingOutcome,
    )..[listingId] = mode == TransactionMode.sale ? 'sold' : 'traded';

    // Step 4: apply all changes and award trust score points.
    // Trades are rewarded more than sales to incentivise swapping.
    _state = _state.copyWith(
      trustScore: _state.trustScore + (mode == TransactionMode.sale ? 6 : 8),
      tradeStates: nextTradeStates,
      hiddenListingIds: nextHiddenListingIds,
      listingOutcome: nextListingOutcome,
    );
    _notifyAndSave();
  }

  /// Resets all workflow state back to [WorkflowState.defaults].
  /// Useful for testing or if the user signs out.
  void resetWorkflowState() {
    _state = WorkflowState.defaults();
    _notifyAndSave();
  }

  /// Adds an item to the user's wishlist if it doesn't already exist.
  /// Trims whitespace and does a case-insensitive duplicate check before adding
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

  
  /// Removes an item from the wishlist by value (case-insensitive).
  void removeWishlistItem(String item) {
    _state = _state.copyWith(
      wishlist: _state.wishlist
          .where((String entry) => entry.toLowerCase() != item.toLowerCase())
          .toList(growable: false),
    );
    _notifyAndSave();
  }

  /// Notifies all listeners and persists the new state to storage.
  /// Always notifies first so the UI updates immediately, then persists
  /// in the background
  void _notifyAndSave() {
    notifyListeners();
    unawaited(_persist());
  }

  /// Saves the current state to the device so it survives the app closing.
  // converts the worflow satate object to JSON string to be saved
  /// Next time the app opens, [init] reads it back.
  /// THIS SHOULD ONLY BE CALLED BY _notifyAndSave
  Future<void> _persist() async {
    await _prefs?.setString(_storageKey, jsonEncode(_state.toJson()));
  }
}
