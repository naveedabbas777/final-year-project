/// Help guide model for storing guidance content
class HelpGuide {
  final String screenName;
  final String titleEn;
  final String titleUr;
  final String descriptionEn;
  final String descriptionUr;
  final List<HelpTip> tips;
  final String? contactSupport;

  HelpGuide({
    required this.screenName,
    required this.titleEn,
    required this.titleUr,
    required this.descriptionEn,
    required this.descriptionUr,
    required this.tips,
    this.contactSupport,
  });
}

class HelpTip {
  final String titleEn;
  final String titleUr;
  final String descriptionEn;
  final String descriptionUr;
  final IconType icon;

  HelpTip({
    required this.titleEn,
    required this.titleUr,
    required this.descriptionEn,
    required this.descriptionUr,
    required this.icon,
  });
}

enum IconType {
  lightbulb,
  info,
  help,
  settings,
  location,
  weather,
  alert,
  market,
  crop,
}

/// Comprehensive help guides for all screens
final Map<String, HelpGuide> appHelpGuides = {
  'dashboard': HelpGuide(
    screenName: 'dashboard',
    titleEn: 'Dashboard Help',
    titleUr: 'ڈیش بورڈ مدد',
    descriptionEn:
        'Your home screen shows weather updates, farm tips, and recent alerts for your location.',
    descriptionUr:
        'آپ کی ہوم سکرین آپ کی جگہ کے لیے موسم کی تازہ کاری، کھیتی کے نکات، اور حالیہ الرٹس دکھاتی ہے۔',
    tips: [
      HelpTip(
        titleEn: 'View Weather',
        titleUr: 'موسم دیکھیں',
        descriptionEn:
            'Check current temperature and conditions. Tap the weather section for a detailed 10-day forecast.',
        descriptionUr:
            'موجودہ درجہ حرارت اور حالات چیک کریں۔ تفصیلی 10 روزہ پیشن گوئی کے لیے موسم کے حصے پر ٹیپ کریں۔',
        icon: IconType.weather,
      ),
      HelpTip(
        titleEn: 'Farm Tips',
        titleUr: 'کھیتی کے نکات',
        descriptionEn:
            'Swipe through daily farming tips to learn best practices for your crops and soil.',
        descriptionUr:
            'اپنی فصلوں اور مٹی کے لیے بہترین طریقے سیکھنے کے لیے روزانہ کھیتی کے نکات کے ذریعے سوائپ کریں۔',
        icon: IconType.lightbulb,
      ),
      HelpTip(
        titleEn: 'Alerts Panel',
        titleUr: 'الرٹس پینل',
        descriptionEn:
            'Stay updated with weather warnings and farming alerts. Tap to view full details.',
        descriptionUr:
            'موسم کی انتباہات اور کھیتی کے الرٹس سے اپڈیٹ رہیں۔ مکمل تفصیلات دیکھنے کے لیے ٹیپ کریں۔',
        icon: IconType.alert,
      ),
      HelpTip(
        titleEn: 'Change Location',
        titleUr: 'جگہ بدلیں',
        descriptionEn:
            'Tap location icon to change your farming area and get localized weather and alerts.',
        descriptionUr:
            'اپنے کھیتی کے علاقے کو تبدیل کرنے کے لیے جگہ کے آئکن پر ٹیپ کریں۔',
        icon: IconType.location,
      ),
    ],
  ),
  'forecast': HelpGuide(
    screenName: 'forecast',
    titleEn: 'Forecast Help',
    titleUr: 'پیشن گوئی مدد',
    descriptionEn:
        'Detailed weather forecast for the next 10 days to help plan your farming activities.',
    descriptionUr:
        'اگلے 10 دنوں کی تفصیلی موسم کی پیشن گوئی آپ کی کھیتی کی سرگرمیوں کو منصوبہ بندی میں مدد دیتی ہے۔',
    tips: [
      HelpTip(
        titleEn: 'Daily Forecast',
        titleUr: 'روزانہ کی پیشن گوئی',
        descriptionEn:
            'Scroll right to see the next 10 days. Each card shows temperature, conditions, and precipitation.',
        descriptionUr:
            'اگلے 10 دن دیکھنے کے لیے دائیں طرف سکرول کریں۔ ہر کارڈ درجہ حرارت، حالات، اور بارش دکھاتا ہے۔',
        icon: IconType.weather,
      ),
      HelpTip(
        titleEn: 'Detailed View',
        titleUr: 'تفصیلی نقطہ نظر',
        descriptionEn:
            'Tap any day to see wind speed, humidity, and UV index for better planning.',
        descriptionUr:
            'بہتر منصوبہ بندی کے لیے ہوا کی رفتار، نمی، اور UV انڈیکس دیکھنے کے لیے کسی بھی دن پر ٹیپ کریں۔',
        icon: IconType.info,
      ),
      HelpTip(
        titleEn: 'Plan Activities',
        titleUr: 'سرگرمیوں کی منصوبہ بندی کریں',
        descriptionEn:
            'Use the forecast to plan irrigation, spraying, and harvesting on suitable days.',
        descriptionUr:
            'مناسب دنوں میں آبپاشی، سپرے، اور کٹائی کی منصوبہ بندی کے لیے پیشن گوئی استعمال کریں۔',
        icon: IconType.lightbulb,
      ),
    ],
  ),
  'alerts': HelpGuide(
    screenName: 'alerts',
    titleEn: 'Alerts Help',
    titleUr: 'الرٹس مدد',
    descriptionEn:
        'Important notifications about weather conditions, pests, and farming recommendations.',
    descriptionUr:
        'موسم کی حالات، کیڑے، اور کھیتی کی تجاویز کے بارے میں اہم اطلاعات۔',
    tips: [
      HelpTip(
        titleEn: 'Alert Types',
        titleUr: 'الرٹس کی اقسام',
        descriptionEn:
            'Rain: Heavy rainfall warnings. Heat: Temperature alerts. Wind: Strong wind notices.',
        descriptionUr:
            'بارش: بھاری بارش کی انتباہات۔ گرمی: درجہ حرارت کی الرٹس۔ ہوا: تیز ہوا کی اطلاعات۔',
        icon: IconType.alert,
      ),
      HelpTip(
        titleEn: 'Mark as Read',
        titleUr: 'پڑھا ہوا نشان کریں',
        descriptionEn:
            'Tap Mark All Read to clear unread alerts and focus on new notifications.',
        descriptionUr:
            'غیر پڑھی الرٹس کو صاف کرنے اور نئی اطلاعات پر توجہ دینے کے لیے سب پڑھا ہوا نشان کریں ٹیپ کریں۔',
        icon: IconType.info,
      ),
      HelpTip(
        titleEn: 'Refresh Alerts',
        titleUr: 'الرٹس ریفریش کریں',
        descriptionEn:
            'Tap refresh icon to get the latest alerts and updates immediately.',
        descriptionUr:
            'فوری طور پر جدید ترین الرٹس اور اپڈیٹس حاصل کرنے کے لیے ریفریش آئکن پر ٹیپ کریں۔',
        icon: IconType.info,
      ),
    ],
  ),
  'market': HelpGuide(
    screenName: 'market',
    titleEn: 'Market Help',
    titleUr: 'منڈی مدد',
    descriptionEn:
        'Buy and sell agricultural products directly. Access marketplace listings and prices.',
    descriptionUr:
        'براہ راست زرعی مصنوعات خریدیں اور فروخت کریں۔ منڈی کی فہرستوں اور قیمتوں تک رسائی حاصل کریں۔',
    tips: [
      HelpTip(
        titleEn: 'Browse Products',
        titleUr: 'مصنوعات براؤز کریں',
        descriptionEn:
            'Scroll to view available products. Filter by category, price, and location.',
        descriptionUr:
            'دستیاب مصنوعات دیکھنے کے لیے سکرول کریں۔ زمرہ، قیمت، اور جگہ کے لحاظ سے فلٹر کریں۔',
        icon: IconType.market,
      ),
      HelpTip(
        titleEn: 'Create Listing',
        titleUr: 'فہرست بنائیں',
        descriptionEn:
            'Tap + to create a new product listing. Add photos, price, and description.',
        descriptionUr:
            'نئی مصنوعات کی فہرست بنانے کے لیے + ٹیپ کریں۔ تصویریں، قیمت، اور تفصیل شامل کریں۔',
        icon: IconType.info,
      ),
      HelpTip(
        titleEn: 'Message Sellers',
        titleUr: 'بیچنے والوں کو پیغام دیں',
        descriptionEn:
            'Tap on a product to view details and chat with the seller directly.',
        descriptionUr:
            'تفصیلات دیکھنے اور براہ راست بیچنے والے کے ساتھ بات چیت کرنے کے لیے کسی مصنوعات پر ٹیپ کریں۔',
        icon: IconType.info,
      ),
    ],
  ),
  'settings': HelpGuide(
    screenName: 'settings',
    titleEn: 'Settings Help',
    titleUr: 'ترتیبات مدد',
    descriptionEn:
        'Manage your profile, preferences, notifications, and app settings.',
    descriptionUr:
        'اپنی پروفائل، ترجیحات، اطلاعات، اور ایپ کی ترتیبات کو منظم کریں۔',
    tips: [
      HelpTip(
        titleEn: 'Edit Profile',
        titleUr: 'پروفائل میں ترمیم کریں',
        descriptionEn:
            'Update your name, photo, location, and farming details.',
        descriptionUr: 'اپنا نام، تصویر، جگہ، اور کھیتی کی تفصیلات اپڈیٹ کریں۔',
        icon: IconType.settings,
      ),
      HelpTip(
        titleEn: 'Notifications',
        titleUr: 'اطلاعات',
        descriptionEn:
            'Turn on/off alerts, weather notifications, and message alerts.',
        descriptionUr: 'الرٹس، موسم کی اطلاعات، اور پیغام کی الرٹس آن/آف کریں۔',
        icon: IconType.alert,
      ),
      HelpTip(
        titleEn: 'Language',
        titleUr: 'زبان',
        descriptionEn:
            'Switch between English and Urdu for your preferred language.',
        descriptionUr:
            'اپنی پسندیدہ زبان کے لیے انگریزی اور اردو کے درمیان سوئچ کریں۔',
        icon: IconType.settings,
      ),
      HelpTip(
        titleEn: 'AI Assistant',
        titleUr: 'AI معاون',
        descriptionEn:
            'Access the farming AI assistant for expert guidance in English or Urdu.',
        descriptionUr:
            'انگریزی یا اردو میں ماہرانہ رہنمائی کے لیے کھیتی کے AI معاون تک رسائی حاصل کریں۔',
        icon: IconType.help,
      ),
    ],
  ),
};
