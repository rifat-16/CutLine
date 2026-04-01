import 'package:cloud_functions/cloud_functions.dart';

class AdminActionService {
  AdminActionService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> reviewSalon({
    required String salonId,
    required String decision,
    String reviewNote = '',
  }) async {
    final callable = _functions.httpsCallable('reviewSalon');
    await callable.call(<String, dynamic>{
      'salonId': salonId,
      'decision': decision,
      'reviewNote': reviewNote.trim(),
    });
  }

  Future<void> updateSupportRequest({
    required String requestId,
    required String status,
    String adminNote = '',
    String assignedAdminUid = '',
  }) async {
    final callable = _functions.httpsCallable('updateSupportRequest');
    await callable.call(<String, dynamic>{
      'requestId': requestId,
      'status': status,
      'adminNote': adminNote.trim(),
      'assignedAdminUid': assignedAdminUid.trim(),
    });
  }

  Future<void> setSalonRestriction({
    required String salonId,
    required bool restricted,
    String reason = '',
  }) async {
    final callable = _functions.httpsCallable('setSalonRestriction');
    await callable.call(<String, dynamic>{
      'salonId': salonId,
      'restricted': restricted,
      'reason': reason.trim(),
    });
  }
}
