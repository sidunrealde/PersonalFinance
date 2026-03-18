abstract final class SupabaseTables {
  // Phase 1 active tables
  static const String profiles = 'profiles';
  static const String households = 'households';
  static const String householdMembers = 'household_members';
  static const String householdInvites = 'household_invites';
  static const String wallets = 'wallets';
  static const String walletCategories = 'wallet_categories';

  // Future-feature tables
  static const String transactions = 'transactions';
  static const String transactionTags = 'transaction_tags';
  static const String tags = 'tags';
  static const String recurringRules = 'recurring_rules';
  static const String budgets = 'budgets';
  static const String budgetCategories = 'budget_categories';
  static const String goals = 'goals';
  static const String goalContributions = 'goal_contributions';
  static const String investments = 'investments';
  static const String investmentSnapshots = 'investment_snapshots';
  static const String documents = 'documents';
  static const String reminders = 'reminders';
  static const String auditLog = 'audit_log';
  static const String syncQueue = 'sync_queue';
}
