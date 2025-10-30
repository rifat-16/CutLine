import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload salon image
  Future<String> uploadSalonImage(File image, String salonId) async {
    try {
      final ref = _storage
          .ref()
          .child(AppConstants.salonImagesPath)
          .child('$salonId.jpg');

      final uploadTask = ref.putFile(image);
      await uploadTask;
      
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      throw 'Error uploading salon image: ${e.toString()}';
    }
  }

  // Upload barber image
  Future<String> uploadBarberImage(
    File image,
    String salonId,
    String barberId,
  ) async {
    try {
      final ref = _storage
          .ref()
          .child(AppConstants.barberImagesPath)
          .child(salonId)
          .child('$barberId.jpg');

      final uploadTask = ref.putFile(image);
      await uploadTask;
      
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      throw 'Error uploading barber image: ${e.toString()}';
    }
  }

  // Delete image
  Future<void> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      throw 'Error deleting image: ${e.toString()}';
    }
  }

  // Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw 'Error picking image: ${e.toString()}';
    }
  }

  // Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw 'Error picking image from camera: ${e.toString()}';
    }
  }
}
