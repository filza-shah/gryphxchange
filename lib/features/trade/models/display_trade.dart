import '../../../services/workflow/workflow_state.dart';

class DisplayTrade {
  final String id;
  final String itemTitle;
  final String otherUserName;
  final String otherUserInitial;
  final TransactionMode mode;
  final WorkflowTradeStatus workflowStatus;

  DisplayTrade({
    required this.id,
    required this.itemTitle,
    required this.otherUserName,
    required this.otherUserInitial,
    required this.mode,
    required this.workflowStatus,
  });

  String get flowText => mode == TransactionMode.trade ? 'Trade Flow' : 'Sale Flow';
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
