import 'package:flutter/foundation.dart';

import 'app/app_variant.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  await bootstrapApp(defaultAppVariant(isWeb: kIsWeb));
}
