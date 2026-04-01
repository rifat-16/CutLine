import 'package:cutline/app/admin_bootstrap.dart';
import 'package:cutline/shared/config/app_flavor.dart';

Future<void> main() async {
  await bootstrapAdmin(flavor: AppFlavor.prod);
}
