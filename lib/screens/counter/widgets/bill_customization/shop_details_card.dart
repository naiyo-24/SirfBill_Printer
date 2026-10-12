import 'package:flutter/material.dart';
import 'customization_text_field.dart';

class ShopDetailsCard extends StatelessWidget {
  final TextEditingController shopNameCtrl;
  final TextEditingController taglineCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController landlineCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController gstCtrl;
  final TextEditingController cinNumberCtrl;

  const ShopDetailsCard({
    super.key,
    required this.shopNameCtrl,
    required this.taglineCtrl,
    required this.addressCtrl,
    required this.phoneCtrl,
    required this.landlineCtrl,
    required this.emailCtrl,
    required this.gstCtrl,
    required this.cinNumberCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shop / Pharmacy Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            CustomizationTextField(
              label: 'Shop / Pharmacy Name',
              controller: shopNameCtrl,
            ),
            const SizedBox(height: 12),
            CustomizationTextField(
              label: 'Tagline / Slogan',
              controller: taglineCtrl,
            ),
            const SizedBox(height: 12),
            CustomizationTextField(
              label: 'Address',
              controller: addressCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomizationTextField(
                    label: 'Primary Phone',
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomizationTextField(
                    label: 'Landline (Optional)',
                    controller: landlineCtrl,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomizationTextField(
                    label: 'Email Address',
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomizationTextField(
                    label: 'GST Number',
                    controller: gstCtrl,
                    maxLength: 15,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: CustomizationTextField(
                    label: 'CIN Number',
                    controller: cinNumberCtrl,
                    maxLength: 21,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
