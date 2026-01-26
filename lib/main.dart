import 'package:cutline/app/bootstrap.dart';
import 'package:cutline/shared/config/app_flavor.dart';

Future<void> main() async {
  await bootstrap(flavor: AppFlavor.prod);
}
