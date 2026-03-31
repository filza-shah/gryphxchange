import '../../../services/workflow/workflow_state.dart';

class DisplayTrade {
  const DisplayTrade({
    required this.id,
    required this.listingId,
    required this.itemTitle,
    required this.otherUserName,
    required this.otherUserInitial,
    required this.mode,
    required this.workflowStatus,
  });

  final String id;
  final String listingId;
  final String itemTitle;
  final String otherUserName;
  final String otherUserInitial;
  final TransactionMode mode;
  final WorkflowTradeStatus workflowStatus;

  bool get isTradeMode => mode == TransactionMode.trade;

  bool get isPending => workflowStatus == WorkflowTradeStatus.pending;

  bool get isCompleted => workflowStatus == WorkflowTradeStatus.completed;

  bool get isActive {
    switch (workflowStatus) {
      case WorkflowTradeStatus.accepted:
      case WorkflowTradeStatus.scheduled:
      case WorkflowTradeStatus.ready:
        return true;
      case WorkflowTradeStatus.pending:
      case WorkflowTradeStatus.completed:
        return false;
    }
  }

  String get flowText => isTradeMode ? 'Trade Flow' : 'Sale Flow';

  String get statusText {
    switch (workflowStatus) {
      case WorkflowTradeStatus.ready:
        return 'Ready to complete';
      case WorkflowTradeStatus.accepted:
        return 'Offer accepted';
      case WorkflowTradeStatus.pending:
        return 'Awaiting response';
      case WorkflowTradeStatus.scheduled:
        return 'Meetup scheduled';
      case WorkflowTradeStatus.completed:
        return 'Completed';
    }
  }

  String get statusDescription {
    switch (workflowStatus) {
      case WorkflowTradeStatus.ready:
        return 'Everything is confirmed. Finish the exchange when you meet.';
      case WorkflowTradeStatus.accepted:
        return 'Your offer was accepted and the trade is now active.';
      case WorkflowTradeStatus.pending:
        return 'This trade is still waiting on the next response.';
      case WorkflowTradeStatus.scheduled:
        return 'The trade is active and the meetup has been arranged.';
      case WorkflowTradeStatus.completed:
        return 'This transaction has already been completed.';
    }
  }

  String get primaryActionLabel {
    switch (workflowStatus) {
      case WorkflowTradeStatus.ready:
        return 'Complete Trade';
      case WorkflowTradeStatus.accepted:
      case WorkflowTradeStatus.scheduled:
        return 'Open Active Trade';
      case WorkflowTradeStatus.pending:
        return 'Review Trade';
      case WorkflowTradeStatus.completed:
        return 'View Trade Details';
    }
  }

  String get fullStatus => '$flowText • $statusText';
}
