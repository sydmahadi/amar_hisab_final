import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  AppSettings get settings => AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    final isBangla = settings.isBangla;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('aboutApp')),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          _buildHero(context),
          const SizedBox(height: 18),
          _buildIntro(context),
          const SizedBox(height: 18),

          _buildFeatureSection(
            context,
            title: isBangla ? 'মানি ম্যানেজমেন্ট' : 'Money Management',
            subtitle: isBangla
                ? 'দৈনন্দিন অর্থের হিসাব সহজভাবে পরিচালনা করুন'
                : 'Manage your daily money easily',
            icon: Icons.account_balance_wallet_rounded,
            features: [
              _FeatureData(
                Icons.add_circle_rounded,
                isBangla ? 'আয় যোগ করুন' : 'Add income',
                isBangla
                    ? 'আপনার সব ধরনের আয়ের হিসাব রাখুন।'
                    : 'Keep track of all your income.',
              ),
              _FeatureData(
                Icons.remove_circle_rounded,
                isBangla ? 'ব্যয় যোগ করুন' : 'Add expenses',
                isBangla
                    ? 'প্রতিদিনের খরচ সুন্দরভাবে সংরক্ষণ করুন।'
                    : 'Record your daily expenses.',
              ),
              _FeatureData(
                Icons.swap_horiz_rounded,
                isBangla ? 'অ্যাকাউন্ট ট্রান্সফার' : 'Account transfer',
                isBangla
                    ? 'এক অ্যাকাউন্ট থেকে অন্য অ্যাকাউন্টে টাকা স্থানান্তর করুন।'
                    : 'Transfer money between your accounts.',
              ),
              _FeatureData(
                Icons.edit_note_rounded,
                isBangla ? 'লেনদেন সম্পাদনা' : 'Edit transactions',
                isBangla
                    ? 'প্রয়োজনে পুরোনো লেনদেন পরিবর্তন বা মুছে ফেলুন।'
                    : 'Edit or delete previous transactions when needed.',
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildFeatureSection(
            context,
            title: isBangla ? 'অ্যাকাউন্ট ও খাত' : 'Accounts & Categories',
            subtitle: isBangla
                ? 'নিজের প্রয়োজন অনুযায়ী হিসাব সাজিয়ে নিন'
                : 'Organize your finances your way',
            icon: Icons.account_tree_rounded,
            features: [
              _FeatureData(
                Icons.account_balance_wallet_rounded,
                isBangla ? 'একাধিক অ্যাকাউন্ট' : 'Multiple accounts',
                isBangla
                    ? 'Cash, bKash, Nagad, Bank, Card সহ বিভিন্ন অ্যাকাউন্ট পরিচালনা করুন।'
                    : 'Manage Cash, bKash, Nagad, Bank, Card and more.',
              ),
              _FeatureData(
                Icons.category_rounded,
                isBangla ? 'নিজের খাত তৈরি করুন' : 'Custom categories',
                isBangla
                    ? 'আপনার প্রয়োজন অনুযায়ী নতুন খাত যোগ করুন।'
                    : 'Create categories according to your needs.',
              ),
              _FeatureData(
                Icons.manage_accounts_rounded,
                isBangla ? 'খাত পরিচালনা' : 'Category management',
                isBangla
                    ? 'নিজের তৈরি খাত সম্পাদনা ও পরিচালনা করুন।'
                    : 'Edit and manage your custom categories.',
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildLoanHighlight(context),

          const SizedBox(height: 16),

          // নতুন ফিচার: সঞ্চয় ও DPS
          _buildFeatureSection(
            context,
            title: isBangla ? 'সঞ্চয় ও DPS' : 'Savings & DPS',
            subtitle: isBangla
                ? 'সঞ্চয় এবং কিস্তির হিসাব গুছিয়ে রাখুন'
                : 'Keep savings and installment records organized',
            icon: Icons.savings_rounded,
            features: [
              _FeatureData(
                Icons.savings_rounded,
                isBangla ? 'সঞ্চয়ের হিসাব' : 'Savings records',
                isBangla
                    ? 'আপনার সঞ্চয়ের তথ্য ও অগ্রগতি সংরক্ষণ করুন।'
                    : 'Keep track of your savings and progress.',
              ),
              _FeatureData(
                Icons.event_repeat_rounded,
                isBangla ? 'DPS কিস্তি' : 'DPS installments',
                isBangla
                    ? 'DPS-এর কিস্তি ও সংশ্লিষ্ট তথ্য গুছিয়ে রাখুন।'
                    : 'Organize your DPS installment records.',
              ),
              _FeatureData(
                Icons.notifications_active_rounded,
                isBangla ? 'কিস্তির রিমাইন্ডার' : 'Installment reminders',
                isBangla
                    ? 'কিস্তির নির্ধারিত তারিখ মনে রাখতে রিমাইন্ডার ব্যবহার করুন।'
                    : 'Use reminders to keep track of installment due dates.',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // নতুন ফিচার: Reminder ও Notifications
          _buildFeatureSection(
            context,
            title: isBangla ? 'রিমাইন্ডার ও নোটিফিকেশন' : 'Reminders & Notifications',
            subtitle: isBangla
                ? 'গুরুত্বপূর্ণ তারিখ ও বকেয়ার কথা মনে রাখুন'
                : 'Keep track of important dates and dues',
            icon: Icons.notifications_active_rounded,
            features: [
              _FeatureData(
                Icons.event_note_rounded,
                isBangla ? 'আগামী ৭ দিনের রিমাইন্ডার' : 'Next 7 days reminders',
                isBangla
                    ? 'আগামী সাত দিনের নির্ধারিত রিমাইন্ডার একসঙ্গে দেখুন।'
                    : 'View scheduled reminders for the next seven days.',
              ),
              _FeatureData(
                Icons.alarm_rounded,
                isBangla ? 'নির্ধারিত রিমাইন্ডার' : 'Scheduled reminders',
                isBangla
                    ? 'প্রয়োজনীয় কাজ বা পেমেন্টের জন্য রিমাইন্ডার নির্ধারণ করুন।'
                    : 'Schedule reminders for important tasks or payments.',
              ),
              _FeatureData(
                Icons.account_balance_rounded,
                isBangla ? 'দেনা-পাওনার স্মরণ' : 'Loan and due reminders',
                isBangla
                    ? 'প্রযোজ্য ক্ষেত্রে দেনা-পাওনা ও বকেয়ার নির্ধারিত তারিখ মনে রাখুন।'
                    : 'Keep track of scheduled loan and outstanding payment dates.',
              ),
              _FeatureData(
                Icons.phone_android_rounded,
                isBangla ? 'ফোনের নোটিফিকেশন' : 'Phone notifications',
                isBangla
                    ? 'নোটিফিকেশন সুবিধা চালু ও অনুমোদিত থাকলে ফোনে রিমাইন্ডার পেতে পারেন।'
                    : 'Receive phone reminders when notifications are enabled and permitted.',
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildFeatureSection(
            context,
            title: isBangla ? 'পরিসংখ্যান ও বিশ্লেষণ' : 'Statistics & Analysis',
            subtitle: isBangla
                ? 'আপনার অর্থের অবস্থার পরিষ্কার চিত্র দেখুন'
                : 'Get a clear picture of your finances',
            icon: Icons.analytics_rounded,
            features: [
              _FeatureData(
                Icons.today_rounded,
                isBangla ? 'দৈনিক হিসাব' : 'Daily overview',
                isBangla
                    ? 'দিনভিত্তিক আয়, ব্যয় ও লেনদেন দেখুন।'
                    : 'View income, expenses and transactions by day.',
              ),
              _FeatureData(
                Icons.date_range_rounded,
                isBangla ? 'সাপ্তাহিক হিসাব' : 'Weekly overview',
                isBangla
                    ? 'সাপ্তাহিক অর্থের হিসাব বিশ্লেষণ করুন।'
                    : 'Analyze your weekly finances.',
              ),
              _FeatureData(
                Icons.calendar_month_rounded,
                isBangla ? 'মাসিক হিসাব' : 'Monthly overview',
                isBangla
                    ? 'মাসভিত্তিক আয় ও ব্যয়ের হিসাব দেখুন।'
                    : 'Review your monthly income and expenses.',
              ),
              _FeatureData(
                Icons.calendar_view_month_rounded,
                isBangla ? 'বার্ষিক হিসাব' : 'Yearly overview',
                isBangla
                    ? 'পুরো বছরের আর্থিক হিসাব পর্যবেক্ষণ করুন।'
                    : 'Review your yearly financial activity.',
              ),
              _FeatureData(
                Icons.pie_chart_rounded,
                isBangla ? 'ক্যাটাগরি বিশ্লেষণ' : 'Category analysis',
                isBangla
                    ? 'কোন খাতে কত আয় বা ব্যয় হচ্ছে তা দেখুন।'
                    : 'See where your income and expenses are going.',
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildReportHighlight(context),

          const SizedBox(height: 16),

          _buildFeatureSection(
            context,
            title: isBangla
                ? 'লেনদেন খুঁজে পাওয়া আরও সহজ'
                : 'Easy Transaction Search',
            subtitle: isBangla
                ? 'প্রয়োজনীয় হিসাব দ্রুত খুঁজে নিন'
                : 'Find the records you need quickly',
            icon: Icons.search_rounded,
            features: [
              _FeatureData(
                Icons.search_rounded,
                isBangla ? 'লেনদেন সার্চ' : 'Transaction search',
                isBangla
                    ? 'নাম, নোট বা অন্যান্য তথ্য দিয়ে লেনদেন খুঁজুন।'
                    : 'Search transactions by name, note and other details.',
              ),
              _FeatureData(
                Icons.filter_alt_rounded,
                isBangla ? 'তারিখ অনুযায়ী ফিল্টার' : 'Date filter',
                isBangla
                    ? 'নির্দিষ্ট দিনের লেনদেন আলাদা করে দেখুন।'
                    : 'View transactions for a specific date.',
              ),
              _FeatureData(
                Icons.calendar_month_rounded,
                isBangla ? 'মাস অনুযায়ী ফিল্টার' : 'Month filter',
                isBangla
                    ? 'নির্দিষ্ট মাসের হিসাব একসঙ্গে দেখুন।'
                    : 'View all transactions from a specific month.',
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildFeatureSection(
            context,
            title: isBangla ? 'অ্যাপের অন্যান্য সুবিধা' : 'Other App Features',
            subtitle: isBangla
                ? 'আপনার ব্যবহারের সুবিধার জন্য প্রয়োজনীয় অপশন'
                : 'Useful options for a better experience',
            icon: Icons.auto_awesome_rounded,
            features: [
              _FeatureData(
                Icons.picture_as_pdf_rounded,
                isBangla ? 'PDF রিপোর্ট' : 'PDF reports',
                isBangla
                    ? 'রিপোর্ট PDF আকারে সংরক্ষণ করুন।'
                    : 'Save your reports as PDF.',
              ),
              _FeatureData(
                Icons.image_rounded,
                isBangla ? 'JPG রিপোর্ট' : 'JPG reports',
                isBangla
                    ? 'পুরো রিপোর্ট JPG ছবি হিসেবে সংরক্ষণ করুন।'
                    : 'Save the complete report as a JPG image.',
              ),
              _FeatureData(
                Icons.dark_mode_rounded,
                isBangla ? 'ডার্ক ও লাইট মোড' : 'Dark & light mode',
                isBangla
                    ? 'আপনার পছন্দ অনুযায়ী অ্যাপের থিম ব্যবহার করুন।'
                    : 'Use the theme you prefer.',
              ),
              _FeatureData(
                Icons.language_rounded,
                isBangla ? 'বাংলা ও ইংরেজি' : 'Bangla & English',
                isBangla
                    ? 'বাংলা অথবা ইংরেজি ভাষায় অ্যাপ ব্যবহার করুন।'
                    : 'Use the app in Bangla or English.',
              ),
              _FeatureData(
                Icons.storage_rounded,
                isBangla ? 'লোকাল ডেটা সংরক্ষণ' : 'Local data storage',
                isBangla
                    ? 'আপনার হিসাব ডিভাইসেই সংরক্ষিত থাকে।'
                    : 'Your financial data is stored locally on your device.',
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildDeveloperCard(context),
          const SizedBox(height: 18),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final isBangla = settings.isBangla;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.darkGreen, AppTheme.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGreen.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.gold,
              size: 45,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'আমার হিসাব',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isBangla
                ? 'আপনার অর্থের হিসাব, আপনার হাতেই'
                : 'Your finances, organized your way',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: AppTheme.gold,
                ),
                const SizedBox(width: 7),
                Text(
                  isBangla
                      ? 'সহজ • ব্যক্তিগত • সুন্দর'
                      : 'Simple • Personal • Beautiful',
                  style: const TextStyle(
                    color: AppTheme.goldLight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final isBangla = settings.isBangla;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppTheme.gold,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBangla ? 'আমার হিসাব কী?' : 'What is Amar Hisab?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  isBangla
                      ? 'আমার হিসাব একটি ব্যক্তিগত Money Manager অ্যাপ। আয়, ব্যয়, অ্যাকাউন্ট, লেনদেন, দেনা-পাওনা, সঞ্চয়, DPS, রিমাইন্ডার, পরিসংখ্যান ও রিপোর্ট—সবকিছু এক জায়গায় সহজভাবে পরিচালনা করার জন্য তৈরি।'
                      : 'Amar Hisab is a personal Money Manager app designed to organize income, expenses, accounts, transactions, loans, savings, DPS, reminders, statistics and reports in one place.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<_FeatureData> features,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.green.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppTheme.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...List.generate(features.length, (index) {
            final feature = features[index];

            return Column(
              children: [
                _featureItem(
                  context,
                  feature.icon,
                  feature.title,
                  feature.description,
                ),
                if (index != features.length - 1)
                  Divider(
                    height: 18,
                    color: Theme.of(context)
                        .dividerColor
                        .withValues(alpha: 0.35),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _featureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: AppTheme.gold),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoanHighlight(BuildContext context) {
    final isBangla = settings.isBangla;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.gold.withValues(alpha: 0.14),
            AppTheme.green.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: AppTheme.gold,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBangla
                          ? 'দেনা-পাওনা ব্যবস্থাপনা'
                          : 'Loan Management',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isBangla
                          ? 'ধার দেওয়া ও নেওয়ার সম্পূর্ণ হিসাব'
                          : 'Complete lending and borrowing records',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _loanItem(
            context,
            Icons.arrow_upward_rounded,
            isBangla ? 'ধার দিয়েছি' : 'Money lent',
            isBangla
                ? 'কে কত টাকা নিয়েছে এবং কত ফেরত দিয়েছে তা দেখুন।'
                : 'Track who owes you and how much has been repaid.',
          ),
          const SizedBox(height: 12),
          _loanItem(
            context,
            Icons.arrow_downward_rounded,
            isBangla ? 'ধার নিয়েছি' : 'Money borrowed',
            isBangla
                ? 'কার কাছ থেকে কত নিয়েছেন এবং কত শোধ করেছেন তা দেখুন।'
                : 'Track what you borrowed and how much you repaid.',
          ),
          const SizedBox(height: 12),
          _loanItem(
            context,
            Icons.person_search_rounded,
            isBangla ? 'ব্যক্তি অনুযায়ী হিসাব' : 'Person-wise records',
            isBangla
                ? 'প্রতিটি ব্যক্তির দেনা-পাওনার আলাদা হিসাব দেখুন।'
                : 'View separate loan records for each person.',
          ),
          const SizedBox(height: 12),
          _loanItem(
            context,
            Icons.filter_alt_rounded,
            isBangla ? 'তারিখ ও মাস অনুযায়ী ফিল্টার' : 'Date & month filters',
            isBangla
                ? 'নির্দিষ্ট সময়ের দেনা-পাওনার তথ্য সহজে খুঁজুন।'
                : 'Find loan activity for a specific date or month.',
          ),
        ],
      ),
    );
  }

  Widget _loanItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportHighlight(BuildContext context) {
    final isBangla = settings.isBangla;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: AppTheme.green.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: AppTheme.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBangla ? 'রিপোর্ট' : 'Reports',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isBangla
                          ? 'আপনার হিসাবের বিস্তারিত রিপোর্ট'
                          : 'Detailed reports of your finances',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _reportItem(
            context,
            Icons.calendar_month_rounded,
            isBangla ? 'মাসিক রিপোর্ট' : 'Monthly report',
            isBangla
                ? 'মাসের আয়, ব্যয় ও উদ্বৃত্ত/ঘাটতির সারসংক্ষেপ।'
                : 'Monthly income, expenses and surplus/deficit.',
          ),
          _reportItem(
            context,
            Icons.category_rounded,
            isBangla ? 'খাতভিত্তিক রিপোর্ট' : 'Category report',
            isBangla
                ? 'প্রতিটি খাতে কত আয় বা ব্যয় হয়েছে তার বিস্তারিত হিসাব।'
                : 'Detailed income and expense breakdown by category.',
          ),
          _reportItem(
            context,
            Icons.handshake_rounded,
            isBangla ? 'দেনা-পাওনা রিপোর্ট' : 'Loan report',
            isBangla
                ? 'ধার দেওয়া, নেওয়া ও ফেরত/শোধের বিস্তারিত তথ্য।'
                : 'Detailed lending, borrowing and repayment records.',
          ),
          _reportItem(
            context,
            Icons.picture_as_pdf_rounded,
            isBangla ? 'PDF ও JPG Export' : 'PDF & JPG export',
            isBangla
                ? 'রিপোর্ট PDF বা JPG আকারে সংরক্ষণ করা যায়।'
                : 'Save reports as PDF or JPG.',
          ),
        ],
      ),
    );
  }

  Widget _reportItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard(BuildContext context) {
    final isBangla = settings.isBangla;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            AppTheme.gold.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.gold,
              size: 29,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isBangla ? 'অ্যাপটি তৈরি করেছেন' : 'Developed by',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Sayeed Mahadi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 17),
          Divider(
            color: Theme.of(context)
                .dividerColor
                .withValues(alpha: 0.35),
          ),
          const SizedBox(height: 13),
          _contactRow(
            context,
            Icons.mail_rounded,
            isBangla ? 'ইমেইল' : 'Email',
            'mahadisayeed@gmail.com',
          ),
        ],
      ),
    );
  }

  Widget _contactRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.gold, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isBangla = settings.isBangla;

    return Column(
      children: [
        const Text(
          'আমার হিসাব',
          style: TextStyle(
            color: AppTheme.gold,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isBangla
              ? 'সহজে আপনার হিসাব রাখুন'
              : 'Manage your money easily',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '© Sayeed Mahadi',
          style: TextStyle(
            fontSize: 10.5,
            color: Theme.of(context)
                .textTheme
                .bodySmall
                ?.color
                ?.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureData(
    this.icon,
    this.title,
    this.description,
  );
}
