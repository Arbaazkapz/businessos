/// A deliberately simple, dependency-free translation system.
///
/// Why not Flutter's official `gen-l10n`? That requires its own code
/// generation step in the build pipeline (similar to build_runner for
/// Drift) - given how many real, unrelated build failures we've already
/// hit getting this app's Android build pipeline stable, adding a second
/// code-generation mechanism is not worth the risk right now. This plain
/// Dart map achieves the same practical result (a working EN/Hindi toggle)
/// with zero new build machinery.
///
/// Coverage note: this currently translates the bottom navigation, the
/// dashboard, and common action words (Save/Cancel/Delete/etc.) - the
/// highest-traffic surfaces. Screen-by-screen forms (Add Customer, Add
/// Product, invoices...) still show English. Extending coverage to any
/// screen is just adding more key/value pairs below and calling
/// `strings.t('your_key')` in that screen - no architecture change needed.
library;

enum AppLocale { en, hi }

class AppStrings {
  AppStrings(this.locale);
  final AppLocale locale;

  String t(String key) {
    final table = locale == AppLocale.hi ? _hi : _en;
    return table[key] ?? _en[key] ?? key;
  }

  static const Map<String, String> _en = {
    // Navigation
    'nav_home': 'Home',
    'nav_customers': 'Customers',
    'nav_products': 'Products',
    'nav_invoices': 'Invoices',
    'nav_settings': 'Settings',

    // Dashboard
    'dashboard_today': 'Today',
    'dashboard_collections': "Today's Collections",
    'dashboard_money_to_receive': 'Money to Receive',
    'dashboard_credit_given': "Today's Credit Given",
    'dashboard_low_stock': 'Low Stock Items',
    'dashboard_quick_actions': 'Quick actions',
    'dashboard_add_customer': 'Add Customer',
    'dashboard_new_invoice': 'New Invoice',
    'dashboard_new_entry': 'New Entry',
    'dashboard_backup': 'Backup',
    'dashboard_low_stock_alerts': 'Low stock alerts',
    'dashboard_recent_customers': 'Recent customers',
    'dashboard_welcome': 'Welcome to',
    'greeting_morning': 'Good Morning',
    'greeting_afternoon': 'Good Afternoon',
    'greeting_evening': 'Good Evening',

    // Notifications
    'notifications_title': 'Needs Attention',
    'notifications_customers_pending': 'Customers with dues pending',
    'notifications_low_stock': 'Products low on stock',
    'notifications_overdue': 'Invoices overdue',
    'notifications_backup': 'Backup reminder',
    'notifications_backup_never': "You haven't backed up yet",
    'notifications_backup_old': "Your last backup was a while ago",
    'notifications_all_clear': "All clear",
    'notifications_all_clear_msg': 'Nothing needs your attention right now.',

    // Common actions
    'action_save': 'Save',
    'action_cancel': 'Cancel',
    'action_delete': 'Delete',
    'action_edit': 'Edit',
    'action_add': 'Add',

    // Notepad / Calculator
    'quick_add_title': 'Quick tools',
    'notepad_title': 'Notepad',
    'notepad_empty_title': 'No notes yet',
    'notepad_empty_msg': 'Jot down anything you need to remember.',
    'notepad_add': 'Add note',
    'calculator_title': 'Calculator',
  };

  static const Map<String, String> _hi = {
    'nav_home': 'होम',
    'nav_customers': 'ग्राहक',
    'nav_products': 'उत्पाद',
    'nav_invoices': 'चालान',
    'nav_settings': 'सेटिंग्स',

    'dashboard_today': 'आज',
    'dashboard_collections': 'आज की वसूली',
    'dashboard_money_to_receive': 'प्राप्त करने योग्य राशि',
    'dashboard_credit_given': 'आज दिया गया उधार',
    'dashboard_low_stock': 'कम स्टॉक वाले आइटम',
    'dashboard_quick_actions': 'त्वरित कार्य',
    'dashboard_add_customer': 'ग्राहक जोड़ें',
    'dashboard_new_invoice': 'नया चालान',
    'dashboard_new_entry': 'नई प्रविष्टि',
    'dashboard_backup': 'बैकअप',
    'dashboard_low_stock_alerts': 'कम स्टॉक चेतावनी',
    'dashboard_recent_customers': 'हाल के ग्राहक',
    'dashboard_welcome': 'आपका स्वागत है',
    'greeting_morning': 'सुप्रभात',
    'greeting_afternoon': 'नमस्कार',
    'greeting_evening': 'शुभ संध्या',

    'notifications_title': 'ध्यान देने योग्य',
    'notifications_customers_pending': 'बकाया वाले ग्राहक',
    'notifications_low_stock': 'कम स्टॉक वाले उत्पाद',
    'notifications_overdue': 'अतिदेय चालान',
    'notifications_backup': 'बैकअप अनुस्मारक',
    'notifications_backup_never': 'आपने अभी तक बैकअप नहीं लिया है',
    'notifications_backup_old': 'आपका पिछला बैकअप काफी पुराना है',
    'notifications_all_clear': 'सब ठीक है',
    'notifications_all_clear_msg': 'अभी ध्यान देने के लिए कुछ नहीं है।',

    'action_save': 'सहेजें',
    'action_cancel': 'रद्द करें',
    'action_delete': 'हटाएं',
    'action_edit': 'संपादित करें',
    'action_add': 'जोड़ें',

    'quick_add_title': 'त्वरित उपकरण',
    'notepad_title': 'नोटपैड',
    'notepad_empty_title': 'अभी तक कोई नोट नहीं',
    'notepad_empty_msg': 'जो भी याद रखना हो उसे यहाँ लिखें।',
    'notepad_add': 'नोट जोड़ें',
    'calculator_title': 'कैलकुलेटर',
  };
}
