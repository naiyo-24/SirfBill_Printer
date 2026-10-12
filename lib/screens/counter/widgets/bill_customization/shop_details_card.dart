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
  final TextEditingController drugLicenceCtrl;

  const ShopDetailsCard({
    super.key,
    required this.shopNameCtrl,
    required this.taglineCtrl,
    required this.addressCtrl,
    required this.phoneCtrl,
    required this.landlineCtrl,
    required this.emailCtrl,
    required this.gstCtrl,
    required this.drugLicenceCtrl,
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
              'Shop Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            CustomizationTextField(
              label: 'Shop Name',
              controller: shopNameCtrl,
            ),
            CustomizationTextField(
              label: 'Tagline',
              controller: taglineCtrl,
            ),
            CustomizationTextField(
              label: 'Address',
              controller: addressCtrl,
              maxLines: 2,
            ),
            Row(
              children: [
                Expanded(
                  child: CustomizationTextField(
                    label: 'Phone',
                    controller: phoneCtrl,
                    maxLength: 10,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomizationTextField(
                    label: 'Landline',
                    controller: landlineCtrl,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: CustomizationTextField(
                    label: 'Email',
                    controller: emailCtrl,
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
                    label: 'Drug Licence',
                    controller: drugLicenceCtrl,
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
