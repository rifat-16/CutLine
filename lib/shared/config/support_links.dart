import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportLinks {
  static final Uri facebookPage = Uri.parse(
    'https://www.facebook.com/profile.php?id=61585485098998',
  );

  static final Uri ownerWhatsAppGroup = Uri.parse(
    'https://chat.whatsapp.com/LdrkpDgDBMqBB2KZClmzKB?mode=gi_t',
  );

  static final Uri userWhatsAppGroup = Uri.parse(
    'https://chat.whatsapp.com/EHlqd4uaKtZ8tPvdp1IHPO?mode=gi_t',
  );

  static final Uri barberWhatsAppGroup = Uri.parse(
    'https://chat.whatsapp.com/DtvwIzzYtAzCYGDzLqQaIL?mode=gi_t',
  );

  static Future<void> openFacebookPage(BuildContext context) {
    return _openExternal(
      context,
      facebookPage,
      failureMessage: 'Could not open Facebook page.',
    );
  }

  static Future<void> openOwnerWhatsAppGroup(BuildContext context) {
    return _openExternal(
      context,
      ownerWhatsAppGroup,
      failureMessage: 'Could not open WhatsApp group.',
    );
  }

  static Future<void> openUserWhatsAppGroup(BuildContext context) {
    return _openExternal(
      context,
      userWhatsAppGroup,
      failureMessage: 'Could not open WhatsApp group.',
    );
  }

  static Future<void> openBarberWhatsAppGroup(BuildContext context) {
    return _openExternal(
      context,
      barberWhatsAppGroup,
      failureMessage: 'Could not open WhatsApp group.',
    );
  }

  static Future<void> _openExternal(
    BuildContext context,
    Uri uri, {
    required String failureMessage,
  }) async {
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}
