import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

Future<TaskSnapshot> uploadStorageFile({
  required Reference ref,
  required XFile file,
  SettableMetadata? metadata,
}) {
  return ref.putFile(File(file.path), metadata).whenComplete(() {});
}
