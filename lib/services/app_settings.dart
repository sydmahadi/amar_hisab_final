import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  SharedPreferences? _prefs;

  // Default settings
  // First time app opens:
  // Language = Bangla
  // Theme = Light Mode
  bool _isDarkMode = false;
  String _language = 'bn';

  bool get isDarkMode => _isDarkMode;

  bool get darkMode => _isDarkMode;

  String get language => _language;

  bool get isBangla => _language == 'bn';

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();

    // Light mode is the default
    _isDarkMode = _prefs?.getBool('dark_mode') ?? false;

    // Bangla is the default language
    _language = _prefs?.getString('language') ?? 'bn';
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;

    await _prefs?.setBool(
      'dark_mode',
      value,
    );

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setDarkMode(!_isDarkMode);
  }

  Future<void> setLanguage(String language) async {
    if (language != 'bn' && language != 'en') {
      return;
    }

    _language = language;

    await _prefs?.setString(
      'language',
      language,
    );

    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    await setLanguage(
      _language == 'bn' ? 'en' : 'bn',
    );
  }

  String t(String key) {
    final Map<String, Map<String, String>> translations = {
      // App
      'appName': {
        'bn': 'আমার হিসাব',
        'en': 'Amar Hisab',
      },
      'appTagline': {
        'bn': 'সহজে আপনার হিসাব রাখুন',
        'en': 'Manage your money easily',
      },

      // Main menu
      'moneyManager': {
        'bn': 'মানি ম্যানেজার',
        'en': 'Money Manager',
      },
      'transactions': {
        'bn': 'লেনদেন',
        'en': 'Transactions',
      },
      'accounts': {
        'bn': 'অ্যাকাউন্ট',
        'en': 'Accounts',
      },
      'categories': {
        'bn': 'খাত',
        'en': 'Categories',
      },
      'statistics': {
        'bn': 'পরিসংখ্যান',
        'en': 'Statistics',
      },
      'report': {
        'bn': 'রিপোর্ট',
        'en': 'Report',
      },
      'settings': {
        'bn': 'সেটিংস',
        'en': 'Settings',
      },
      'about': {
        'bn': 'অ্যাপ সম্পর্কে',
        'en': 'About',
      },

      // Transaction
      'addTransaction': {
        'bn': 'লেনদেন যোগ করুন',
        'en': 'Add Transaction',
      },
      'editTransaction': {
        'bn': 'লেনদেন সম্পাদনা',
        'en': 'Edit Transaction',
      },
      'income': {
        'bn': 'আয়',
        'en': 'Income',
      },
      'expense': {
        'bn': 'ব্যয়',
        'en': 'Expense',
      },
      'transfer': {
        'bn': 'ট্রান্সফার',
        'en': 'Transfer',
      },
      'amount': {
        'bn': 'পরিমাণ',
        'en': 'Amount',
      },
      'date': {
        'bn': 'তারিখ',
        'en': 'Date',
      },
      'time': {
        'bn': 'সময়',
        'en': 'Time',
      },
      'note': {
        'bn': 'নোট',
        'en': 'Note',
      },
      'description': {
        'bn': 'বিবরণ',
        'en': 'Description',
      },
      'save': {
        'bn': 'সংরক্ষণ',
        'en': 'Save',
      },
      'update': {
        'bn': 'আপডেট',
        'en': 'Update',
      },
      'cancel': {
        'bn': 'বাতিল',
        'en': 'Cancel',
      },
      'delete': {
        'bn': 'মুছে ফেলুন',
        'en': 'Delete',
      },
      'edit': {
        'bn': 'সম্পাদনা',
        'en': 'Edit',
      },
      'search': {
        'bn': 'খুঁজুন',
        'en': 'Search',
      },
      'noTransactions': {
        'bn': 'কোনো লেনদেন পাওয়া যায়নি',
        'en': 'No transactions found',
      },

      // Accounts
      'addAccount': {
        'bn': 'অ্যাকাউন্ট যোগ করুন',
        'en': 'Add Account',
      },
      'accountName': {
        'bn': 'অ্যাকাউন্টের নাম',
        'en': 'Account Name',
      },
      'cash': {
        'bn': 'নগদ',
        'en': 'Cash',
      },
      'bkash': {
        'bn': 'বিকাশ',
        'en': 'Bkash',
      },
      'nagad': {
        'bn': 'নগদ',
        'en': 'Nagad',
      },
      'bankAccount': {
        'bn': 'ব্যাংক অ্যাকাউন্ট',
        'en': 'Bank Account',
      },
      'card': {
        'bn': 'কার্ড',
        'en': 'Card',
      },
      'balance': {
        'bn': 'ব্যালেন্স',
        'en': 'Balance',
      },
      'totalBalance': {
        'bn': 'মোট ব্যালেন্স',
        'en': 'Total Balance',
      },

      // Categories
      'addCategory': {
        'bn': 'খাত যোগ করুন',
        'en': 'Add Category',
      },
      'categoryName': {
        'bn': 'খাতের নাম',
        'en': 'Category Name',
      },
      'incomeCategories': {
        'bn': 'আয়ের খাত',
        'en': 'Income Categories',
      },
      'expenseCategories': {
        'bn': 'ব্যয়ের খাত',
        'en': 'Expense Categories',
      },
      'noCategories': {
        'bn': 'কোনো খাত নেই',
        'en': 'No categories',
      },
      'categoryAdded': {
        'bn': 'খাত যোগ হয়েছে',
        'en': 'Category added',
      },
      'categoryDeleted': {
        'bn': 'খাত মুছে ফেলা হয়েছে',
        'en': 'Category deleted',
      },

      // Totals
      'incomeTotal': {
        'bn': 'মোট আয়',
        'en': 'Total Income',
      },
      'expenseTotal': {
        'bn': 'মোট ব্যয়',
        'en': 'Total Expense',
      },
      'surplus': {
        'bn': 'উদ্বৃত্ত',
        'en': 'Surplus',
      },
      'deficit': {
        'bn': 'ঘাটতি',
        'en': 'Deficit',
      },

      // Periods
      'daily': {
        'bn': 'দৈনিক',
        'en': 'Daily',
      },
      'weekly': {
        'bn': 'সাপ্তাহিক',
        'en': 'Weekly',
      },
      'monthly': {
        'bn': 'মাসিক',
        'en': 'Monthly',
      },
      'yearly': {
        'bn': 'বার্ষিক',
        'en': 'Yearly',
      },
      'today': {
        'bn': 'আজ',
        'en': 'Today',
      },
      'thisWeek': {
        'bn': 'এই সপ্তাহ',
        'en': 'This Week',
      },
      'thisMonth': {
        'bn': 'এই মাস',
        'en': 'This Month',
      },
      'thisYear': {
        'bn': 'এই বছর',
        'en': 'This Year',
      },

      // Transfer
      'fromAccount': {
        'bn': 'যে অ্যাকাউন্ট থেকে',
        'en': 'From Account',
      },
      'toAccount': {
        'bn': 'যে অ্যাকাউন্টে',
        'en': 'To Account',
      },
      'transferAmount': {
        'bn': 'ট্রান্সফারের পরিমাণ',
        'en': 'Transfer Amount',
      },

      // Report
      'generateReport': {
        'bn': 'রিপোর্ট তৈরি করুন',
        'en': 'Generate Report',
      },
      'monthlyReport': {
        'bn': 'মাসিক রিপোর্ট',
        'en': 'Monthly Report',
      },
      'incomeReport': {
        'bn': 'আয়ের রিপোর্ট',
        'en': 'Income Report',
      },
      'expenseReport': {
        'bn': 'ব্যয়ের রিপোর্ট',
        'en': 'Expense Report',
      },
      'downloadPdf': {
        'bn': 'PDF সংরক্ষণ',
        'en': 'Save PDF',
      },
      'downloadJpg': {
        'bn': 'JPG সংরক্ষণ',
        'en': 'Save JPG',
      },
      'reportSaved': {
        'bn': 'রিপোর্ট তৈরি হয়েছে',
        'en': 'Report created successfully',
      },

      // Settings
      'language': {
        'bn': 'ভাষা',
        'en': 'Language',
      },
      'bangla': {
        'bn': 'বাংলা',
        'en': 'Bangla',
      },
      'english': {
        'bn': 'ইংরেজি',
        'en': 'English',
      },
      'theme': {
        'bn': 'থিম',
        'en': 'Theme',
      },
      'darkTheme': {
        'bn': 'ডার্ক মোড',
        'en': 'Dark Mode',
      },
      'lightTheme': {
        'bn': 'লাইট মোড',
        'en': 'Light Mode',
      },

      // About
      'aboutApp': {
        'bn': 'আমার হিসাব সম্পর্কে',
        'en': 'About Amar Hisab',
      },
      'appDescription': {
        'bn':
            'আমার হিসাব একটি সহজ ও ব্যবহারবান্ধব ব্যক্তিগত অর্থ ব্যবস্থাপনা অ্যাপ।',
        'en':
            'Amar Hisab is a simple and user-friendly personal money management app.',
      },
      'features': {
        'bn': 'অ্যাপের সুবিধাসমূহ',
        'en': 'Features',
      },
      'developerInfo': {
        'bn': 'ডেভেলপার তথ্য',
        'en': 'Developer Information',
      },
      'developedBy': {
        'bn': 'ডেভেলপ করেছেন',
        'en': 'Developed by',
      },
      'contact': {
        'bn': 'যোগাযোগ',
        'en': 'Contact',
      },

      // Common
      'yes': {
        'bn': 'হ্যাঁ',
        'en': 'Yes',
      },
      'no': {
        'bn': 'না',
        'en': 'No',
      },
      'close': {
        'bn': 'বন্ধ করুন',
        'en': 'Close',
      },
      'confirm': {
        'bn': 'নিশ্চিত করুন',
        'en': 'Confirm',
      },
      'warning': {
        'bn': 'সতর্কতা',
        'en': 'Warning',
      },
      'success': {
        'bn': 'সফল',
        'en': 'Success',
      },
      'error': {
        'bn': 'ত্রুটি',
        'en': 'Error',
      },
      'loading': {
        'bn': 'লোড হচ্ছে...',
        'en': 'Loading...',
      },
      'noData': {
        'bn': 'কোনো তথ্য পাওয়া যায়নি',
        'en': 'No data found',
      },
      'deleteConfirmation': {
        'bn': 'আপনি কি এটি মুছে ফেলতে চান?',
        'en': 'Do you want to delete this?',
      },
      'enterAmount': {
        'bn': 'পরিমাণ লিখুন',
        'en': 'Enter amount',
      },
      'enterName': {
        'bn': 'নাম লিখুন',
        'en': 'Enter name',
      },
      'requiredField': {
        'bn': 'এই ঘরটি পূরণ করুন',
        'en': 'This field is required',
      },
    };

    return translations[key]?[_language] ?? key;
  }
}
