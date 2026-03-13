enum TransactionMode { sale, trade }

enum WorkflowTradeStatus { pending, accepted, scheduled, ready, completed }

class WorkflowNotification {
  const WorkflowNotification({
    required this.id,
    required this.title,
    required this.message,
    this.tradeId,
    required this.read,
  });

  final String id;
  final String title;
  final String message;
  final String? tradeId;
  final bool read;

  WorkflowNotification copyWith({bool? read}) {
    return WorkflowNotification(
      id: id,
      title: title,
      message: message,
      tradeId: tradeId,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'message': message,
      'tradeId': tradeId,
      'read': read,
    };
  }

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

class WorkflowTradeState {
  const WorkflowTradeState({
    required this.tradeId,
    required this.mode,
    required this.status,
    required this.meetupLocation,
    required this.meetupTime,
    required this.matchesFound,
  });

  final String tradeId;
  final TransactionMode mode;
  final WorkflowTradeStatus status;
  final String? meetupLocation;
  final String? meetupTime;
  final int matchesFound;

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

  final String? verifiedEmail;
  final int trustScore;
  final List<String> wishlist;
  final List<WorkflowNotification> notifications;
  final Map<String, WorkflowTradeState> tradeStates;
  final List<String> hiddenListingIds;
  final Map<String, String> listingOutcome;

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

  static WorkflowState mergeWithDefaults(Map<String, dynamic> json) {
    final WorkflowState fallback = WorkflowState.defaults();

    // keep app resilient: parse what we can, fallback for anything weird.
    final List<WorkflowNotification> notifications;
    final dynamic rawNotifications = json['notifications'];
    if (rawNotifications is List) {
      notifications = rawNotifications
          .whereType<Map>()
          .map(
            (dynamic item) => WorkflowNotification.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } else {
      notifications = fallback.notifications;
    }

    final Map<String, WorkflowTradeState> parsedTradeStates =
        <String, WorkflowTradeState>{};
    final dynamic rawTradeStates = json['tradeStates'];
    if (rawTradeStates is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawTradeStates.entries) {
        final String key = entry.key.toString();
        final dynamic raw = entry.value;
        if (raw is Map) {
          parsedTradeStates[key] = WorkflowTradeState.fromJson(
            Map<String, dynamic>.from(raw),
          );
        }
      }
    }

    return fallback.copyWith(
      verifiedEmail: json['verifiedEmail'] as String?,
      trustScore: (json['trustScore'] as num?)?.toInt() ?? fallback.trustScore,
      wishlist:
          ((json['wishlist'] as List?)?.whereType<String>().toList(
            growable: false,
          )) ??
          fallback.wishlist,
      notifications: notifications,
      tradeStates: <String, WorkflowTradeState>{
        ...fallback.tradeStates,
        ...parsedTradeStates,
      },
      hiddenListingIds:
          ((json['hiddenListingIds'] as List?)?.whereType<String>().toList(
            growable: false,
          )) ??
          const <String>[],
      listingOutcome:
          ((json['listingOutcome'] as Map?)?.map<String, String>(
            (dynamic key, dynamic value) =>
                MapEntry<String, String>(key.toString(), value.toString()),
          )) ??
          const <String, String>{},
    );
  }
}

TransactionMode _parseMode(String? value) {
  if (value == TransactionMode.trade.name) {
    return TransactionMode.trade;
  }
  return TransactionMode.sale;
}

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
