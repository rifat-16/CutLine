import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

Future<TaskSnapshot> uploadStorageFile({
  required Reference ref,
  required XFile file,
  SettableMetadata? metadata,
}) async {
  final bytes = await file.readAsBytes();
  return ref.putData(bytes, metadata).whenComplete(() {});
}
