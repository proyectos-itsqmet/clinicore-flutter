/// Form validation for the auth screens.
///
/// Every function returns `null` when the value is acceptable and a
/// user-facing message when it is not — the contract Flutter's
/// `FormFieldValidator` already uses, so these drop straight into
/// `AppTextField.validator`.
///
/// The messages are written for the person who mistyped, not for the
/// developer: they say what to do next, not what rule was broken.
abstract final class Validators {
  /// Anything the form cannot be submitted without.
  static String? required(String? value, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$field es obligatorio';
    return null;
  }

  /// Deliberately permissive. Over-strict email regexes reject valid
  /// addresses (new TLDs, plus-addressing, apostrophes) and the only real
  /// check is whether the confirmation mail arrives — so this catches
  /// typos, not RFC violations.
  static String? email(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu correo';
    final RegExp pattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]{2,}$');
    if (!pattern.hasMatch(v)) return 'Revisa el correo, algo no cuadra';
    return null;
  }

  /// Ecuadorian national ID.
  ///
  /// This is a real check, not a length check. The cedula carries a mod-10
  /// check digit, and validating it here means a mistyped digit is caught on
  /// the phone instead of coming back from the server — which matters for a
  /// clinic, where the cedula is the key the medical history is filed under.
  ///
  /// Rules:
  /// * 10 digits;
  /// * digits 1-2 are the province, 01-24 (or 30, consulates);
  /// * digit 3 is below 6 for a natural person;
  /// * digits 1-9 are weighted 2,1,2,1,2,1,2,1,2 — any product above 9 has 9
  ///   subtracted — and digit 10 is what completes the sum to the next
  ///   multiple of ten.
  static String? cedula(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu cedula';
    if (v.length != 10 || !RegExp(r'^\d{10}$').hasMatch(v)) {
      return 'La cedula tiene 10 digitos';
    }

    final List<int> d = v.split('').map(int.parse).toList();

    final int province = d[0] * 10 + d[1];
    if ((province < 1 || province > 24) && province != 30) {
      return 'Esa cedula no corresponde a ninguna provincia';
    }
    if (d[2] >= 6) return 'Revisa la cedula, el tercer digito no es valido';

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      final int weight = i.isEven ? 2 : 1;
      int product = d[i] * weight;
      if (product > 9) product -= 9;
      sum += product;
    }
    final int check = (10 - (sum % 10)) % 10;

    if (check != d[9]) return 'Revisa la cedula, no verifica';
    return null;
  }

  /// Ecuadorian mobile: 10 digits starting `09`.
  static String? phone(String? value) {
    final String v = (value ?? '').replaceAll(RegExp(r'\s|-'), '');
    if (v.isEmpty) return 'Ingresa tu celular';
    if (!RegExp(r'^09\d{8}$').hasMatch(v)) {
      return 'El celular va con 10 digitos, empezando en 09';
    }
    return null;
  }

  /// Eight characters with at least one letter and one digit.
  ///
  /// No mandatory symbol and no maximum: NIST dropped composition rules years
  /// ago because they push people toward `Passw0rd!` and away from length,
  /// which is the thing that actually helps.
  static String? password(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Ingresa una contrasena';
    if (v.length < 8) return 'Al menos 8 caracteres';
    if (!RegExp(r'[A-Za-zaeiouAEIOUnN]').hasMatch(v)) {
      return 'Agrega al menos una letra';
    }
    if (!RegExp(r'\d').hasMatch(v)) return 'Agrega al menos un numero';
    return null;
  }

  /// The repeat field. Takes the original so the comparison happens here
  /// rather than in every screen.
  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Repite la contrasena';
    if (value != original) return 'Las contrasenas no coinciden';
    return null;
  }

  /// A person's name. Letters, spaces, apostrophes and hyphens — nothing
  /// else, and no minimum beyond two characters, because short real names
  /// exist and rejecting them is a bug people remember.
  static String? fullName(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu nombre';
    if (v.length < 2) return 'Nombre demasiado corto';
    if (!RegExp(r"^[\p{L}\p{M}\s'-]+$", unicode: true).hasMatch(v)) {
      return 'El nombre solo lleva letras';
    }
    return null;
  }

  /// A 6-digit one-time code.
  static String? otp(String? value, {int length = 6}) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa el codigo';
    if (v.length != length || !RegExp(r'^\d+$').hasMatch(v)) {
      return 'El codigo tiene $length digitos';
    }
    return null;
  }
}
