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
        return 'Ready to Verify';
      case WorkflowTradeStatus.accepted:
        return 'Accepted';
      case WorkflowTradeStatus.pending:
        return 'Pending';
      case WorkflowTradeStatus.scheduled:
        return 'Scheduled';
      case WorkflowTradeStatus.completed:
        return 'Completed';
    }
  }

  String get fullStatus => '$flowText • $statusText';
}
