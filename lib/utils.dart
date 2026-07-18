import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';

bool _phoneNumberFormattingAvailable = false;

bool get phoneNumberFormattingAvailable => _phoneNumberFormattingAvailable;

Future<void> initializePhoneNumberFormatting() async {
  await init();
  _phoneNumberFormattingAvailable = CountryManager().countries.isNotEmpty;
}

String readablePhoneNumber(String value) {
  final raw = value.trim();
  if (!_phoneNumberFormattingAvailable || !_isE164(raw)) return raw;

  try {
    final formatted = formatNumberSync(
      raw,
      phoneNumberFormat: PhoneNumberFormat.international,
      inputContainsCountryCode: true,
    ).trim();
    return formatted.isEmpty ? raw : formatted;
  } catch (_) {
    return raw;
  }
}

Future<String> actionablePhoneNumber(String value, {String? region}) async {
  final raw = value.trim();
  if (!_phoneNumberFormattingAvailable || _isE164(raw)) return raw;

  try {
    final result = await parse(raw, region: region);
    final e164 = (result['e164'] as String?)?.trim();
    return e164 == null || !_isE164(e164) ? raw : e164;
  } catch (_) {
    return raw;
  }
}

bool _isE164(String value) => RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(value);

extension IterableExtensions<T> on Iterable<T> {
  Iterable<T> intersperse(T separator) {
    if (isEmpty) return [];
    return map((e) => [separator, e]).expand((e) => e).skip(1);
  }
}
