import 'import_labels.dart';

/// One documented root of a Facebook export and what it holds.
///
/// The folder names are Facebook's own, so a path under one of these roots is
/// something the export itself named. [roots] holds every spelling the export
/// layouts use for the same category; [description] states in plain language
/// what the category is, not what the importer does with it.
class ImportCategory {
  const ImportCategory({
    required this.code,
    required this.roots,
    required this.label,
    required this.description,
  });

  /// Stable, content-free identifier used in coverage counts.
  final String code;

  /// Top-level folder names that belong to this category.
  final List<String> roots;

  final ImportLabel label;
  final ImportLabel description;
}

/// The known export roots, in the order the coverage report lists them.
const List<ImportCategory> importCategories = [
  ImportCategory(
    code: 'ads_information',
    roots: ['ads_information', 'ads'],
    label: ImportLabel(en: 'Ads information', ar: 'معلومات الإعلانات'),
    description: ImportLabel(
      en: 'The ads, interests and advertisers Facebook recorded about you.',
      ar: 'الإعلانات والاهتمامات والمعلنون الذين سجّلتهم فيسبوك عنك.',
    ),
  ),
  ImportCategory(
    code: 'friends_and_followers',
    roots: ['friends_and_followers', 'friends'],
    label: ImportLabel(en: 'Friends and followers', ar: 'الأصدقاء والمتابعون'),
    description: ImportLabel(
      en: 'Your friend list and the people and pages you follow.',
      ar: 'قائمة أصدقائك والأشخاص والصفحات التي تتابعها.',
    ),
  ),
  ImportCategory(
    code: 'personal_information',
    roots: ['personal_information', 'profile_information'],
    label: ImportLabel(en: 'Personal information', ar: 'المعلومات الشخصية'),
    description: ImportLabel(
      en: 'The profile details and contact information you gave Facebook.',
      ar: 'بيانات ملفك ومعلومات التواصل التي أعطيتها لفيسبوك.',
    ),
  ),
  ImportCategory(
    code: 'activity',
    roots: ['your_activity_across_facebook', 'your_facebook_activity'],
    label: ImportLabel(en: 'Your activity', ar: 'نشاطك'),
    description: ImportLabel(
      en: 'Your posts, comments, reactions and the rest of your activity.',
      ar: 'منشوراتك وتعليقاتك وتفاعلاتك وبقية نشاطك.',
    ),
  ),
  ImportCategory(
    code: 'your_places',
    roots: ['your_places'],
    label: ImportLabel(en: 'Your places', ar: 'أماكنك'),
    description: ImportLabel(
      en: 'Places you checked in to or saved.',
      ar: 'الأماكن التي سجّلت حضورك فيها أو حفظتها.',
    ),
  ),
  ImportCategory(
    code: 'logged_information',
    roots: ['logged_information'],
    label: ImportLabel(en: 'Logged information', ar: 'المعلومات المسجّلة'),
    description: ImportLabel(
      en: 'IP addresses and device information Facebook logged.',
      ar: 'عناوين IP ومعلومات الأجهزة التي سجّلتها فيسبوك.',
    ),
  ),
  ImportCategory(
    code: 'security_and_login_information',
    roots: ['security_and_login_information'],
    label: ImportLabel(en: 'Security and login', ar: 'الأمان وتسجيل الدخول'),
    description: ImportLabel(
      en: 'Login history, sessions and security settings.',
      ar: 'سجل الدخول والجلسات وإعدادات الأمان.',
    ),
  ),
  ImportCategory(
    code: 'preferences',
    roots: ['preferences', 'settings'],
    label: ImportLabel(en: 'Preferences', ar: 'التفضيلات'),
    description: ImportLabel(
      en: 'The language, display and notification settings you chose.',
      ar: 'إعدادات اللغة والعرض والإشعارات التي اخترتها.',
    ),
  ),
  ImportCategory(
    code: 'facebook_profile_information',
    roots: ['facebook_profile_information'],
    label: ImportLabel(en: 'Profile information', ar: 'معلومات الملف الشخصي'),
    description: ImportLabel(
      en: 'The profile information Facebook holds about you.',
      ar: 'معلومات الملف الشخصي التي تحتفظ بها فيسبوك عنك.',
    ),
  ),
  ImportCategory(
    code: 'apps_and_websites',
    roots: [
      'apps_and_websites_off_your_facebook_activity',
      'apps_and_websites',
    ],
    label: ImportLabel(en: 'Apps and websites', ar: 'التطبيقات والمواقع'),
    description: ImportLabel(
      en: 'Apps and websites that use Facebook login or share data with it.',
      ar: 'التطبيقات والمواقع التي تستخدم تسجيل الدخول بفيسبوك أو تشاركها بياناتك.',
    ),
  ),
  ImportCategory(
    code: 'connections',
    roots: ['connections'],
    label: ImportLabel(en: 'Connections', ar: 'الارتباطات'),
    description: ImportLabel(
      en: 'Your connections to pages, groups and other accounts.',
      ar: 'ارتباطاتك بالصفحات والمجموعات والحسابات الأخرى.',
    ),
  ),
  ImportCategory(
    code: 'messages',
    roots: ['messages'],
    label: ImportLabel(en: 'Messages', ar: 'الرسائل'),
    description: ImportLabel(
      en: 'Your conversations and the media sent in them.',
      ar: 'محادثاتك والوسائط المرسلة فيها.',
    ),
  ),
  ImportCategory(
    code: 'photos_and_videos',
    roots: ['photos_and_videos', 'videos'],
    label: ImportLabel(en: 'Photos and videos', ar: 'الصور والفيديوهات'),
    description: ImportLabel(
      en: 'The photos and videos you uploaded.',
      ar: 'الصور والفيديوهات التي رفعتها.',
    ),
  ),
  ImportCategory(
    code: 'posts',
    roots: ['posts', 'your_posts'],
    label: ImportLabel(en: 'Posts', ar: 'المنشورات'),
    description: ImportLabel(
      en: 'The posts and updates you published.',
      ar: 'المنشورات والتحديثات التي نشرتها.',
    ),
  ),
  ImportCategory(
    code: 'comments',
    roots: ['comments', 'your_comments'],
    label: ImportLabel(en: 'Comments', ar: 'التعليقات'),
    description: ImportLabel(
      en: 'Comments you wrote on posts.',
      ar: 'التعليقات التي كتبتها على المنشورات.',
    ),
  ),
  ImportCategory(
    code: 'likes_and_reactions',
    roots: ['likes_and_reactions'],
    label: ImportLabel(en: 'Likes and reactions', ar: 'الإعجابات والتفاعلات'),
    description: ImportLabel(
      en: 'Likes and reactions you left on posts.',
      ar: 'الإعجابات والتفاعلات التي تركتها على المنشورات.',
    ),
  ),
  ImportCategory(
    code: 'groups',
    roots: ['groups'],
    label: ImportLabel(en: 'Groups', ar: 'المجموعات'),
    description: ImportLabel(
      en: 'Groups you belong to and your posts in them.',
      ar: 'المجموعات التي تنتمي إليها ومنشوراتك فيها.',
    ),
  ),
  ImportCategory(
    code: 'events',
    roots: ['events'],
    label: ImportLabel(en: 'Events', ar: 'الأحداث'),
    description: ImportLabel(
      en: 'Events you created, joined or replied to.',
      ar: 'الأحداث التي أنشأتها أو انضممت إليها أو ردّت عليها.',
    ),
  ),
  ImportCategory(
    code: 'stories',
    roots: ['stories'],
    label: ImportLabel(en: 'Stories', ar: 'القصص'),
    description: ImportLabel(
      en: 'Stories and story activity kept in the export.',
      ar: 'القصص ونشاط القصص المحفوظ في التصدير.',
    ),
  ),
  ImportCategory(
    code: 'search',
    roots: ['search'],
    label: ImportLabel(en: 'Search', ar: 'البحث'),
    description: ImportLabel(
      en: 'The searches Facebook recorded.',
      ar: 'عمليات البحث التي سجّلتها فيسبوك.',
    ),
  ),
];

final Map<String, ImportCategory> _categoryByRoot = {
  for (final category in importCategories)
    for (final root in category.roots) root: category,
};

/// The category of [relativePath], or null when the path is genuinely unknown.
///
/// The root is matched as a whole path segment. The first two segments are
/// considered, so an export that was unzipped under one wrapper folder still
/// classifies, while a folder name deeper in the tree never does.
ImportCategory? importCategoryForPath(String relativePath) {
  final segments = relativePath
      .replaceAll('\\', '/')
      .split('/')
      .take(2)
      .map((segment) => segment.trim().toLowerCase());
  for (final segment in segments) {
    final category = _categoryByRoot[segment];
    if (category != null) return category;
  }
  return null;
}
