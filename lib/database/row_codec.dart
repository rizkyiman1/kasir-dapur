int readInt(Object? value, {required String field}) {
  if (value is int) {
    return value;
  }
  throw StateError('Kolom $field harus integer, bukan $value');
}

int readMoney(Object? value, {required String field}) {
  if (value is int) {
    return value;
  }
  throw StateError('Nominal $field harus integer Rupiah, bukan $value');
}

String readString(Object? value, {required String field}) {
  if (value is String) {
    return value;
  }
  throw StateError('Kolom $field harus teks');
}

String? readStringOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw StateError(
    'Kolom opsional harus teks atau null, bukan ${value.runtimeType}: $value',
  );
}

int? readIntOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw StateError('Kolom opsional harus integer atau null');
}

bool readBoolInt(Object? value, {required String field}) {
  return readInt(value, field: field) == 1;
}
