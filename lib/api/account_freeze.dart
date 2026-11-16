import '../i18n/i18n.dart';

/// An account frozen for deletion, as the app sees it (backend v1.12.35).
///
/// Asking to delete an account (Profile > Delete my account, or the residents'
/// site) freezes it for 30 days: the server refuses its sign-ins and requests
/// with 403 `account_pending_deletion` and the day it goes
/// (`details.delete_after`). Within the 30 days, signing in offers Restore my
/// account (POST /auth/restore); after them the account is gone.
///
/// A request refused mid-session (frozen from another phone or the website)
/// trips [onTrip], which main.dart sets: signed out, back at Sign in with the
/// day it goes. Kept free of widgets so the API layer can trip it.
class AccountFreeze {
  AccountFreeze._();

  /// The backend's error code for "this account is frozen for deletion".
  static const String errorCode = 'account_pending_deletion';

  /// Signs out to Sign in, saying when the account goes. Set in main.dart.
  static void Function(String? deleteAfter)? onTrip;

  /// A request was refused because the account is frozen.
  static void trip(String? deleteAfter) => onTrip?.call(deleteAfter);

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// "16 December 2026" (in Tagalog: "16 Disyembre 2026"), in Philippine
  /// time, from the server's `delete_after`; null when there is none.
  static String? day(String? deleteAfter) {
    final at = deleteAfter == null ? null : DateTime.tryParse(deleteAfter);
    if (at == null) return null;
    final manila = at.toUtc().add(const Duration(hours: 8));
    return '${manila.day} ${t(_months[manila.month - 1])} ${manila.year}';
  }

  /// What Sign in says to a frozen account's owner.
  static String notice(String? deleteAfter) {
    final when = day(deleteAfter);
    return when == null
        ? t(
            'This account is set to be deleted. To keep it, sign in and '
            'choose Restore my account.',
          )
        : t(
            'This account is set to be deleted on {date}. To keep it, sign in '
            'and choose Restore my account.',
            {'date': when},
          );
  }
}
