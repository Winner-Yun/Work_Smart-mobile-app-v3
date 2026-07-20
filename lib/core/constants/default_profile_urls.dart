class DefaultProfileUrls {
  DefaultProfileUrls._();

  static const String male =
      'https://res.cloudinary.com/dwrf0xt1x/image/upload/v1772785604/no-profile-man-480_pontxk.png';
  static const String female =
      'https://res.cloudinary.com/dwrf0xt1x/image/upload/v1772785604/no-profile-woman-480_cjtkbd.png';

  static String byGender(String? gender) {
    final normalizedGender = (gender ?? '').trim().toLowerCase();
    if (normalizedGender == 'female') {
      return female;
    }
    return male;
  }

  static String resolve({String? gender, String? providedUrl}) {
    final normalizedUrl = (providedUrl ?? '').trim();
    if (normalizedUrl.isNotEmpty) {
      return normalizedUrl;
    }
    return byGender(gender);
  }
}
