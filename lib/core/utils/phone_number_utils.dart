class PhoneNumberUtils {
  PhoneNumberUtils._();

  /// E.164 ফরম্যাট ভ্যালিডেশনের রেগুলার এক্সপ্রেশন:
  /// '+' দিয়ে শুরু হবে, প্রথম ডিজিট ১-৯ এবং মোট ৭ থেকে ১৫টি ডিজিট থাকবে।
  static final RegExp _e164RegExp = RegExp(r'^\+[1-9]\d{6,14}$');

  /// যেকোনো স্পেস, ড্যাশ, ব্র্যাকেট বা ডট মুছে ফেলে ক্লিন স্ট্রিং তৈরি করে।
  static String clean(String phone) {
    var value = phone.trim();
    if (value.isEmpty) {
      return '';
    }

    final hasPlus = value.startsWith('+');
    // প্লাস ও সব ডিজিট ছাড়া বাকি সব চিহ্ন (স্পেস, ড্যাশ, ব্র্যাকেট) মুছে ফেলা
    value = value.replaceAll(RegExp(r'[^\d]'), '');

    return hasPlus ? '+$value' : value;
  }

  /// ফোন নম্বরকে আন্তর্জাতিক E.164 ফরম্যাটে রূপান্তর করে।
  static String normalize(String phone) {
    final cleaned = clean(phone);

    if (cleaned.isEmpty) {
      throw const FormatException('Phone number cannot be empty.');
    }

    if (!cleaned.startsWith('+')) {
      throw const FormatException(
        'Phone number must include an international country code starting with "+".',
      );
    }

    return cleaned;
  }

  /// আন্তর্জাতিক E.164 ফরম্যাট যাচাইকরণ।
  static bool isValid(String phone) {
    final cleaned = clean(phone);
    return _e164RegExp.hasMatch(cleaned);
  }

  /// একবারে নম্বর ক্লিন, নরমালাইজ এবং ভ্যালিডেট করে।
  static String normalizeAndValidate(String phone) {
    final normalized = normalize(phone);

    if (!isValid(normalized)) {
      throw const FormatException(
        'Phone number is not a valid ITU-T E.164 number.',
      );
    }

    return normalized;
  }
}
