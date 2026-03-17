// Whether a transaction is a direct sale (money) or a swap (item for item)
enum TransactionMode { sale, trade }

// The life-cycle statge a trade moves through from creation to completion 
// Flow: pending-> acceppted -> scheduled -> ready -> completed
enum WorkflowTradeStatus { pending, accepted, scheduled, ready, completed }

// An in-app notification tied to a workflow event(eg: a new trade match)
/// Notifications are immutable — use [copyWith] to mark one as read.
class WorkflowNotification {
  const WorkflowNotification({
    required this.id,
    required this.title,
    required this.message,
    this.tradeId,
    required this.read,
  });

  // identifier for for the notification 
  final String id;
  // headline showin in the notitifcation list
  final String title;
  // full body text of the notification
  final String message;
  // the trade this notification relates to (not required bcus not everything is at trade)
  final String? tradeId;
  // wether the user has already seen/dismissed this notification
  final bool read;

  //// Returns a copy with [read] optionally overidden 
  // all other fields are immmutable
  WorkflowNotification copyWith({bool? read}) {
    return WorkflowNotification(
      id: id,
      title: title,
      message: message,
      tradeId: tradeId,
      read: read ?? this.read,
    );
  }

  // Just Converts the workflow notifiaction into a dart map 
  // Allows for notitifcation to be encoded to JSON 
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'message': message,
      'tradeId': tradeId,
      'read': read,
    };
  }

  // Takes the map and create a WorklflowNotification object from it
  // defaults to empty strigns for any missing fields
  static WorkflowNotification fromJson(Map<String, dynamic> json) {
    return WorkflowNotification(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      tradeId: json['tradeId'] as String?,
      read: (json['read'] as bool?) ?? false,
    );
  }
}

// The local storage for a single trade and its progess and metup details
// This is stored per-trade insdie of  [WorkflowState.tradeStates] keyed by tradeId
class WorkflowTradeState {
  const WorkflowTradeState({
    required this.tradeId,
    required this.mode,
    required this.status,
    required this.meetupLocation,
    required this.meetupTime,
    required this.matchesFound,
  });

  // The ID of the trade this sate belongs to
  final String tradeId;
  // whether this is a cash sale or an item swap
  final TransactionMode mode;
  //Current lifecycle stage of this trade
  final WorkflowTradeStatus status;
  //Were the two parties have agreed to meet. Null until scheduled 
  final String? meetupLocation;
  //The agreed meetup time as a string. Null until scheduled.
  final String? meetupTime;
  //How many potential matches the algorithm has foud for this trade
  final int matchesFound;

  //// Returns a new [WorkflowTradeState] with any of the fields updated/replaced
  /// Use [clearMeetupLocation] or [clearMeetupTime] to say if you want the meetup location and time to be null (avoids null ambiguity )
  /// passing null just keeps the current value (if there is a new value given use it, if not keep the old one)
  WorkflowTradeState copyWith({
    TransactionMode? mode,
    WorkflowTradeStatus? status,
    String? meetupLocation,
    bool clearMeetupLocation = false,
    String? meetupTime,
    bool clearMeetupTime = false,
    int? matchesFound,
  }) {
    return WorkflowTradeState(
      tradeId: tradeId,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      meetupLocation: clearMeetupLocation
          ? null
          : meetupLocation ?? this.meetupLocation,
      meetupTime: clearMeetupTime ? null : meetupTime ?? this.meetupTime,
      matchesFound: matchesFound ?? this.matchesFound,
    );
  }

  //converts the trade state to a JSON-compatible map
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tradeId': tradeId,
      'mode': mode.name,
      'status': status.name,
      'meetupLocation': meetupLocation,
      'meetupTime': meetupTime,
      'matchesFound': matchesFound,
    };
  }

  //Takes the map and create a worfklow trade stae object from it
  ////unknown values fall bactk to save defaults through [_parseMode] / [_parseStatus].
  static WorkflowTradeState fromJson(Map<String, dynamic> json) {
    return WorkflowTradeState(
      tradeId: (json['tradeId'] as String?) ?? '',
      mode: _parseMode(json['mode'] as String?),
      status: _parseStatus(json['status'] as String?),
      meetupLocation: json['meetupLocation'] as String?,
      meetupTime: json['meetupTime'] as String?,
      matchesFound: (json['matchesFound'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The root state object for the entire workflow feature.
///
/// Holds all user-facing data that needs to persist across sessions:
/// identity, trust score, wishlist, notifications, and per-trade progress.
///
/// This class is immutable — every mutation returns a new instance via [copyWith].
/// Serialisation (object converting) is handled by [toJson] / [mergeWithDefaults].
class WorkflowState {
  const WorkflowState({
    required this.verifiedEmail,
    required this.trustScore,
    required this.wishlist,
    required this.notifications,
    required this.tradeStates,
    required this.hiddenListingIds,
    required this.listingOutcome,
  });

  // The email address the user has verfied
  final String? verifiedEmail;
  //The user's reputation score
  final int trustScore;
  //Items user is looking to get
  final List<String> wishlist;
  //All in app notifications for this user, int the order they were recieved 
  final List<WorkflowNotification> notifications;
  // Per-trade stae(keyed by trade Id)
  final Map<String, WorkflowTradeState> tradeStates;
  //IDs of lisitngs that should no longer appear itn the browse UI
  //Listings are hidden once transaction is completed 
  //NOTE THIS IS JUST A TEMP UI FIX AS ONCE THE BACKEND IS IMPLEMENTED THIS STUFF WILL BE DELETED
  final List<String> hiddenListingIds;
  //This records the listing outcome locally (also temporary)
  final Map<String, String> listingOutcome;

  /// Returns the initial state used for a brand-new user (or after a reset).
  /// 
  /// Seeds two demo trades and a wishlist so screens aren't empty on first run.
  static WorkflowState defaults() {
    // starter seed data so wishlist/trade screens aren't empty on first run.
    return WorkflowState(
      verifiedEmail: null,
      trustScore: 72,
      wishlist: <String>['Data Structures Textbook', 'Chemistry Lab Kit'],
      notifications: const <WorkflowNotification>[
        WorkflowNotification(
          id: 'notif-match-1',
          title: 'Potential Swap Found',
          message:
              'We found a potential Swap! Alex has your book and wants your lab kit.',
          tradeId: 'trade-1',
          read: false,
        ),
      ],
      tradeStates: const <String, WorkflowTradeState>{
        'trade-1': WorkflowTradeState(
          tradeId: 'trade-1',
          mode: TransactionMode.trade,
          status: WorkflowTradeStatus.accepted,
          meetupLocation: null,
          meetupTime: null,
          matchesFound: 0,
        ),
        'trade-2': WorkflowTradeState(
          tradeId: 'trade-2',
          mode: TransactionMode.sale,
          status: WorkflowTradeStatus.accepted,
          meetupLocation: null,
          meetupTime: null,
          matchesFound: 0,
        ),
      },
      hiddenListingIds: const <String>[],
      listingOutcome: const <String, String>{},
    );
  }

  /// Returns a new [WorkflowState] with any provided fields replaced.
  ///
  /// Pass [clearVerifiedEmail] = true to explicitly set [verifiedEmail] to null —
  /// passing null alone would just preserve the existing value.

  WorkflowState copyWith({
    String? verifiedEmail,
    bool clearVerifiedEmail = false,
    int? trustScore,
    List<String>? wishlist,
    List<WorkflowNotification>? notifications,
    Map<String, WorkflowTradeState>? tradeStates,
    List<String>? hiddenListingIds,
    Map<String, String>? listingOutcome,
  }) {
    return WorkflowState(
      verifiedEmail: clearVerifiedEmail
          ? null
          : verifiedEmail ?? this.verifiedEmail,
      trustScore: trustScore ?? this.trustScore,
      wishlist: wishlist ?? this.wishlist,
      notifications: notifications ?? this.notifications,
      tradeStates: tradeStates ?? this.tradeStates,
      hiddenListingIds: hiddenListingIds ?? this.hiddenListingIds,
      listingOutcome: listingOutcome ?? this.listingOutcome,
    );
  }

  //// Converts the the workflow sate to a JSON style map 
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'verifiedEmail': verifiedEmail,
      'trustScore': trustScore,
      'wishlist': wishlist,
      'notifications': notifications.map((item) => item.toJson()).toList(),
      'tradeStates': tradeStates.map(
        (key, value) => MapEntry<String, dynamic>(key, value.toJson()),
      ),
      'hiddenListingIds': hiddenListingIds,
      'listingOutcome': listingOutcome,
    };
  }

  /// Rebuilds state from a persisted JSON map, filling any missing or
  /// unreadable fields with values from [defaults()].
  ///
  /// This "merge with defaults" strategy keeps the app resilient across
  /// schema changes — if a field is added in a new version, existing users
  /// get a sensible default rather than null / crash.
  ///
  /// For [tradeStates], saved trades are merged on top of the default seed
  /// trades, so demo data is preserved until the user overwrites it.
  static WorkflowState mergeWithDefaults(Map<String, dynamic> json) {
    // Step 1: start with a fully populated fallback so every field has a
    // safe value even if the saved JSON is missing or partially corrupt.
    final WorkflowState fallback = WorkflowState.defaults();

    // Step 2: parse notifications.
    // Pull the raw value out first as dynamic (we can't trust its type yet.)
    final List<WorkflowNotification> notifications;
    final dynamic rawNotifications = json['notifications'];
    if (rawNotifications is List) {
      // It's a list yay, convert each entry into a WorkflowNotification.
      // whereType<Map>() silently skips any entries that aren't maps,
      // so a single corrupt notification won't crash the whole parse.
      notifications = rawNotifications
          .whereType<Map>()
          .map(
            (dynamic item) => WorkflowNotification.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } else {
      // Not a list at all (null, corrupt, etc.) — use the seeded defaults.
      notifications = fallback.notifications;
    }

    // Step 3: parse trade states.
    // Start with an empty map and fill it entry-by-entry so a single
    // malformed trade doesn't prevent the others from loading.
    final Map<String, WorkflowTradeState> parsedTradeStates =
        <String, WorkflowTradeState>{};
    final dynamic rawTradeStates = json['tradeStates'];
    if (rawTradeStates is Map) {
      // Loop through each tradeId → raw trade entry.
      for (final MapEntry<dynamic, dynamic> entry in rawTradeStates.entries) {
        final String key = entry.key.toString();
        final dynamic raw = entry.value;
        // Only parse entries whose value is actually a map (skip anything else.)
        if (raw is Map) {
          parsedTradeStates[key] = WorkflowTradeState.fromJson(
            Map<String, dynamic>.from(raw),
          );
        }
      }
    }

    // Step 4: build and return the final merged state.
    // For each field: use the saved value if it's valid, otherwise fall back
    // to the default.
    return fallback.copyWith(
      // null is a valid value for verifiedEmail (user not yet verified).
      verifiedEmail: json['verifiedEmail'] as String?,
      // Cast via num first since JSON numbers can be int or double.
      trustScore: (json['trustScore'] as num?)?.toInt() ?? fallback.trustScore,
      wishlist:
          ((json['wishlist'] as List?)?.whereType<String>().toList(
            growable: false,
          )) ??
          fallback.wishlist,
      notifications: notifications,
       // Spread defaults first, then saved trades on top
      tradeStates: <String, WorkflowTradeState>{
        ...fallback.tradeStates,
        ...parsedTradeStates,
      },
      hiddenListingIds:
          ((json['hiddenListingIds'] as List?)?.whereType<String>().toList(
            growable: false,
          )) ??
          const <String>[],
      // Re-map every key and value to String to guard against type mismatches.
      listingOutcome:
          ((json['listingOutcome'] as Map?)?.map<String, String>(
            (dynamic key, dynamic value) =>
                MapEntry<String, String>(key.toString(), value.toString()),
          )) ??
          const <String, String>{},
    );
  }
}

/// Parses a [TransactionMode] from its stored string name.
/// Defaults to [TransactionMode.sale] for any unknown/null value.
TransactionMode _parseMode(String? value) {
  if (value == TransactionMode.trade.name) {
    return TransactionMode.trade;
  }
  return TransactionMode.sale;
}

/// Parses a [WorkflowTradeStatus] from its stored string name.
/// Defaults to [WorkflowTradeStatus.accepted] for any unknown/null value,
/// which is the earliest "active" state and the safest fallback.
WorkflowTradeStatus _parseStatus(String? value) {
  switch (value) {
    case 'pending':
      return WorkflowTradeStatus.pending;
    case 'accepted':
      return WorkflowTradeStatus.accepted;
    case 'scheduled':
      return WorkflowTradeStatus.scheduled;
    case 'ready':
      return WorkflowTradeStatus.ready;
    case 'completed':
      return WorkflowTradeStatus.completed;
    default:
      return WorkflowTradeStatus.accepted;
  }
}
