/// Language-aware UI strings. Use `LocaleService` to toggle languages.
import '../locale/locale_service.dart';

class AppStrings {
  AppStrings._();

  // App
  static String get appName => LocaleService.isEnglish ? 'Oikko' : 'Oikko';
  static String get appTagline => LocaleService.isEnglish
      ? 'Teachers Association, Baniachang'
      : 'শিক্ষক সমিতি, বানিয়াচং';

  // Auth - Login
  static String get loginTitle =>
      LocaleService.isEnglish ? 'Welcome' : 'স্বাগতম';
  static String get loginSubtitle => LocaleService.isEnglish
      ? 'Sign in with email or phone'
      : 'ইমেইল বা ফোন নম্বর দিয়ে লগইন করুন';
  static String get identifierHint =>
      LocaleService.isEnglish ? 'Email or phone' : 'ইমেইল অথবা ফোন নম্বর';
  static String get passwordHint =>
      LocaleService.isEnglish ? 'Password' : 'পাসওয়ার্ড';
  static String get login => LocaleService.isEnglish ? 'Log in' : 'লগইন করুন';
  static String get dontHaveAccount => LocaleService.isEnglish
      ? "Don't have an account? Register"
      : 'একাউন্ট নেই? রেজিস্টার করুন';

  // Auth - Register
  static String get registerTitle =>
      LocaleService.isEnglish ? 'Create account' : 'নতুন একাউন্ট';
  static String get registerSubtitle => LocaleService.isEnglish
      ? 'Register with your details'
      : 'তথ্য দিয়ে রেজিস্টার করুন';
  static String get nameHint =>
      LocaleService.isEnglish ? 'Full name' : 'পূর্ণ নাম';
  static String get nameHintEn =>
      LocaleService.isEnglish ? 'Full name (English)' : 'নাম (ইংরেজিতে)';
  static String get emailHint => LocaleService.isEnglish ? 'Email' : 'ইমেইল';
  static String get phoneHint =>
      LocaleService.isEnglish ? '01XXXXXXXXX' : '01XXXXXXXXX';
  static String get confirmPasswordHint =>
      LocaleService.isEnglish ? 'Confirm password' : 'পাসওয়ার্ড আবার লিখুন';
  static String get register =>
      LocaleService.isEnglish ? 'Register' : 'রেজিস্টার করুন';
  static String get alreadyHaveAccount => LocaleService.isEnglish
      ? 'Already have an account? Log in'
      : 'একাউন্ট আছে? লগইন করুন';
  static String get passwordMismatch => LocaleService.isEnglish
      ? 'Passwords do not match'
      : 'পাসওয়ার্ড মিলছে না';

  // Auth - Email Verification
  static String get verifyEmailTitle =>
      LocaleService.isEnglish ? 'Verify email' : 'ইমেইল যাচাই করুন';
  static String get verifyEmailSubtitle => LocaleService.isEnglish
      ? 'A verification link was sent to this address'
      : 'যাচাইকরণ লিংক পাঠানো হয়েছে এই ঠিকানায়';
  static String get verifyEmailInstruction => LocaleService.isEnglish
      ? 'Click the link in your email and then press the button below'
      : 'ইমেইলের লিংকে ক্লিক করে ফিরে এসে নিচের বাটনে চাপুন';
  static String get iveVerified => LocaleService.isEnglish
      ? "I've verified, continue"
      : 'যাচাই সম্পন্ন হয়েছে, চালিয়ে যান';
  static String get resendEmail =>
      LocaleService.isEnglish ? 'Resend' : 'আবার পাঠান';
  static String get stillNotVerified => LocaleService.isEnglish
      ? 'Still not verified — check your email'
      : 'এখনও যাচাই সম্পন্ন হয়নি, ইমেইল চেক করুন';

  // Navigation / sections
  static String get home => LocaleService.isEnglish ? 'Home' : 'হোম';
  static String get directory =>
      LocaleService.isEnglish ? 'Directory' : 'সদস্য তালিকা';
  static String get finance => LocaleService.isEnglish ? 'Finance' : 'হিসাব';
  /// Short form for the bottom-nav tab (`directory` is too long to fit).
  static String get members => LocaleService.isEnglish ? 'Members' : 'সদস্য';
  static String get notices => LocaleService.isEnglish ? 'Notices' : 'নোটিশ';
  static String get welfare =>
      LocaleService.isEnglish ? 'Welfare fund' : 'কল্যাণ তহবিল';
  static String get polls => LocaleService.isEnglish ? 'Polls' : 'পোল';
  static String get profile => LocaleService.isEnglish ? 'Profile' : 'প্রোফাইল';
  static String get admin => LocaleService.isEnglish ? 'Admin' : 'এডমিন';
  static String get developer =>
      LocaleService.isEnglish ? 'Developer' : 'ডেভেলপার';

  // Common
  static String get loading =>
      LocaleService.isEnglish ? 'Loading...' : 'লোড হচ্ছে...';
  static String get noData =>
      LocaleService.isEnglish ? 'No data' : 'কোনো তথ্য পাওয়া যায়নি';
  static String get errorGeneric => LocaleService.isEnglish
      ? 'Something went wrong, try again'
      : 'কিছু একটা সমস্যা হয়েছে, আবার চেষ্টা করুন';
  static String get retry =>
      LocaleService.isEnglish ? 'Retry' : 'আবার চেষ্টা করুন';
  static String get save => LocaleService.isEnglish ? 'Save' : 'সংরক্ষণ করুন';
  static String get cancel => LocaleService.isEnglish ? 'Cancel' : 'বাতিল';
  static String get submit => LocaleService.isEnglish ? 'Submit' : 'জমা দিন';

  // Member linking (section 4.9 of planning doc)
  static String get findMyProfile =>
      LocaleService.isEnglish ? 'Find my profile' : 'আমার প্রোফাইল খুঁজুন';
  static String get thisIsMe =>
      LocaleService.isEnglish ? 'This is me' : 'এটা আমার প্রোফাইল';
  static String get linkRequestSent => LocaleService.isEnglish
      ? 'Link request sent, pending admin approval'
      : 'অনুরোধ পাঠানো হয়েছে, এডমিনের অনুমোদনের অপেক্ষায়';

  // Notices
  static String get noNotices =>
      LocaleService.isEnglish ? 'No notices yet' : 'এখনো কোনো নোটিশ নেই';
  static String get noticeTitle =>
      LocaleService.isEnglish ? 'Title' : 'শিরোনাম';
  static String get noticeBody =>
      LocaleService.isEnglish ? 'Content' : 'বিষয়বস্তু';
  static String get publishNotice =>
      LocaleService.isEnglish ? 'Publish' : 'প্রকাশ করুন';
  static String get deleteNotice =>
      LocaleService.isEnglish ? 'Delete' : 'মুছুন';
  static String get noticePostedBy =>
      LocaleService.isEnglish ? 'Posted by' : 'পোস্ট করেছেন';
  static String get eventDate =>
      LocaleService.isEnglish ? 'Event date' : 'ইভেন্টের তারিখ';
  static String get location => LocaleService.isEnglish ? 'Location' : 'স্থান';

  // Menu / settings drawer
  static String get menu => LocaleService.isEnglish ? 'Menu' : 'মেনু';
  static String get editProfile =>
      LocaleService.isEnglish ? 'Edit profile' : 'প্রোফাইল সম্পাদনা';
  static String get about =>
      LocaleService.isEnglish ? 'About the association' : 'সমিতি সম্পর্কে';
  static String get language => LocaleService.isEnglish ? 'Language' : 'ভাষা';
  static String get logout => LocaleService.isEnglish ? 'Log out' : 'লগ আউট';
  static String get changePhoto =>
      LocaleService.isEnglish ? 'Change photo' : 'ছবি পরিবর্তন করুন';
  static String get profileUpdated => LocaleService.isEnglish
      ? 'Profile updated'
      : 'প্রোফাইল হালনাগাদ করা হয়েছে';
  static String get allMembers =>
      LocaleService.isEnglish ? 'All members' : 'সকল সদস্য';
  static String get seeDetails =>
      LocaleService.isEnglish ? 'See details' : 'বিস্তারিত জানুন';

  // Finance / payments (admin)
  static String get addPayment =>
      LocaleService.isEnglish ? 'Add payment' : 'টাকা জমা যোগ করুন';
  static String get selectMember =>
      LocaleService.isEnglish ? 'Select member' : 'সদস্য নির্বাচন করুন';
  static String get changeMember =>
      LocaleService.isEnglish ? 'Change' : 'পরিবর্তন করুন';
  static String get amount => LocaleService.isEnglish ? 'Amount' : 'পরিমাণ';
  static String get descriptionOptional =>
      LocaleService.isEnglish ? 'Description (optional)' : 'বিবরণ (ঐচ্ছিক)';
  static String get paymentDate =>
      LocaleService.isEnglish ? 'Date' : 'তারিখ';
  static String get paymentAdded =>
      LocaleService.isEnglish ? 'Payment added' : 'টাকা জমা যোগ করা হয়েছে';
  /// The headline figure on the finance hero card: collected minus spent.
  static String get totalNetAmount =>
      LocaleService.isEnglish ? 'TOTAL NET AMOUNT' : 'মোট নিট পরিমাণ';

  /// Everything taken in (member dues + other income) — the gross figure,
  /// before expenses are subtracted.
  static String get totalCollected =>
      LocaleService.isEnglish ? 'TOTAL COLLECTED' : 'মোট সংগ্রহ';
  static String get totalExpense =>
      LocaleService.isEnglish ? 'TOTAL EXPENSE' : 'মোট ব্যয়';

  static String get clearAll =>
      LocaleService.isEnglish ? 'Clear all' : 'সব মুছুন';
  static String get addExpense =>
      LocaleService.isEnglish ? 'Add expense' : 'খরচ যোগ করুন';
  static String get expenseAdded =>
      LocaleService.isEnglish ? 'Expense added' : 'খরচ যোগ করা হয়েছে';
  static String get expenseReason => LocaleService.isEnglish
      ? 'What was it spent on?'
      : 'কী বাবদ খরচ হয়েছে?';
  static String get myStatement =>
      LocaleService.isEnglish ? 'My statement' : 'আমার হিসাব';
  static String get allTransactions =>
      LocaleService.isEnglish ? 'All transactions' : 'সকল লেনদেন';
  static String get noTransactions =>
      LocaleService.isEnglish ? 'No transactions yet' : 'এখনো কোনো লেনদেন নেই';

  // Add member (admin) + member-ID linking
  static String get addMember =>
      LocaleService.isEnglish ? 'Add member' : 'সদস্য যোগ করুন';
  static String get memberAdded =>
      LocaleService.isEnglish ? 'Member added' : 'সদস্য যোগ করা হয়েছে';
  static String get memberId =>
      LocaleService.isEnglish ? 'Member ID' : 'সদস্য আইডি';
  static String get memberIdGeneratedHint => LocaleService.isEnglish
      ? 'Share this ID with the teacher — they can use it to connect their account'
      : 'এই আইডি শিক্ষকের সাথে শেয়ার করুন — তিনি এটি দিয়ে তার একাউন্ট যুক্ত করতে পারবেন';
  static String get copyId => LocaleService.isEnglish ? 'Copy' : 'কপি করুন';
  static String get idCopied =>
      LocaleService.isEnglish ? 'Copied to clipboard' : 'ক্লিপবোর্ডে কপি করা হয়েছে';
  static String get addAnother =>
      LocaleService.isEnglish ? 'Add another' : 'আরেকজন যোগ করুন';
  static String get connectWithId =>
      LocaleService.isEnglish ? 'Connect with member ID' : 'সদস্য আইডি দিয়ে যুক্ত করুন';
  static String get enterMemberId =>
      LocaleService.isEnglish ? 'Enter the member ID' : 'সদস্য আইডি লিখুন';
  static String get connect => LocaleService.isEnglish ? 'Connect' : 'যুক্ত করুন';
  static String get idNotFound => LocaleService.isEnglish
      ? 'No unclaimed member found with this ID'
      : 'এই আইডিতে কোনো সদস্য পাওয়া যায়নি';
  static String get orSearchByName =>
      LocaleService.isEnglish ? 'or search by name' : 'অথবা নাম দিয়ে খুঁজুন';
  static String get linkRequests =>
      LocaleService.isEnglish ? 'Link requests' : 'সংযোগ অনুরোধ';
  static String get noLinkRequests =>
      LocaleService.isEnglish ? 'No pending requests' : 'কোনো অনুরোধ নেই';
  static String get allRequestsReviewed => LocaleService.isEnglish
      ? 'All requests have been reviewed'
      : 'সকল অনুরোধ পর্যালোচনা করা হয়েছে';
  static String get approve => LocaleService.isEnglish ? 'Approve' : 'অনুমোদন';
  static String get reject => LocaleService.isEnglish ? 'Reject' : 'প্রত্যাখ্যান';
  static String get requestedPhone =>
      LocaleService.isEnglish ? 'Requested with phone' : 'যে নম্বর দিয়ে অনুরোধ করেছেন';
}
