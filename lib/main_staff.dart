import 'app/app_variant.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  await bootstrapApp(AppVariant.staff);
}
