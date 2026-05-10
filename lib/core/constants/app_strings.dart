class AppStrings {
  AppStrings._();

  static const appName = 'duh';
  static const appSubtitle =
      'Өдөр тутмын ажлаа ухаалгаар төлөвлөж, шаардлагагүй зорчилтыг багасгана.';

  // Auth
  static const login = 'Нэвтрэх';
  static const register = 'Бүртгэл үүсгэх';
  static const forgotPassword = 'Нууц үг мартсан?';
  static const sendResetLink = 'Сэргээх холбоос илгээх';
  static const resetPassword = 'Нууц үг шинэчлэх';
  static const logout = 'Гарах';

  static const email = 'Имэйл';
  static const password = 'Нууц үг';
  static const confirmPassword = 'Нууц үг давтах';
  static const newPassword = 'Шинэ нууц үг';
  static const confirmNewPassword = 'Шинэ нууц үг давтах';
  static const fullName = 'Овог нэр';
  static const phone = 'Утасны дугаар';
  static const userType = 'Хэрэглэгчийн төрөл';
  static const district = 'Дүүрэг';
  static const language = 'Хэл';

  static const welcomePrefix = 'Тавтай морил, ';

  // Errors
  static const errNetwork = 'Интернет холболтоо шалгана уу.';
  static const errInvalidCredentials = 'Имэйл эсвэл нууц үг буруу байна.';
  static const errEmailExists = 'Энэ имэйлээр бүртгэл үүссэн байна.';
  static const errSession = 'Таны session дууссан байна. Дахин нэвтэрнэ үү.';
  static const errServer = 'Сервертэй холбогдоход алдаа гарлаа.';
  static const errResetExpired = 'Сэргээх холбоосын хугацаа дууссан байна.';
  static const errPasswordsMismatch = 'Нууц үг таарахгүй байна.';
  static const errEmailRequired = 'Имэйл шаардлагатай.';
  static const errEmailInvalid = 'Имэйл формат буруу байна.';
  static const errPasswordRequired = 'Нууц үг шаардлагатай.';
  static const errPasswordMin = 'Нууц үг доод тал нь 8 тэмдэгт байна.';
  static const errPasswordPattern =
      'Нууц үг доод тал нь нэг үсэг, нэг тоо агуулсан байх ёстой.';
  static const errFullNameRequired = 'Овог нэр шаардлагатай.';
  static const errPhoneInvalid = 'Утасны дугаар буруу байна.';
  static const errUserTypeRequired = 'Хэрэглэгчийн төрлөө сонгоно уу.';

  // Success / generic
  static const forgotPasswordSent =
      'Хэрэв энэ имэйл бүртгэлтэй бол нууц үг сэргээх холбоос илгээгдлээ.';
  static const passwordResetSuccess = 'Нууц үг амжилттай шинэчлэгдлээ.';

  // Home cards
  static const cardPlan = 'Өдрийн төлөвлөгөө';
  static const cardMap = 'Газрын зураг';
  static const cardComplaint = 'Санал, гомдол';
  static const cardOrgData = 'Байгууллагын дата';
  static const comingSoon = 'Удахгүй';

  // User type labels (mn)
  static const userTypeLabels = <String, String>{
    'general': 'Энгийн хэрэглэгч',
    'elderly': 'Ахмад настан',
    'wheelchair': 'Тэргэнцэртэй хэрэглэгч',
    'parent_with_stroller': 'Хүүхдийн тэрэгтэй эцэг эх',
    'visually_impaired': 'Харааны бэрхшээлтэй хэрэглэгч',
    'organization': 'Байгууллага',
  };

  static const districts = <String>[
    'Баянгол',
    'Баянзүрх',
    'Сүхбаатар',
    'Сонгинохайрхан',
    'Хан-Уул',
    'Чингэлтэй',
    'Налайх',
    'Багануур',
    'Багахангай',
  ];
}
