import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/settings_models.dart';
import '../../services/shop_settings_service.dart';
import '../../utils/responsive.dart';
import '../../utils/pdf_generator.dart';
import '../../config/api_client.dart';
import '../../providers/counter_providers.dart';

import 'widgets/bill_customization/shop_details_card.dart';
import 'widgets/bill_customization/bank_details_card.dart';
import 'widgets/bill_customization/terms_conditions_card.dart';
import 'widgets/bill_customization/media_upload_card.dart';
import 'widgets/bill_customization/bill_preview_panel.dart';

class BillCustomizationScreen extends ConsumerStatefulWidget {
  const BillCustomizationScreen({super.key});

  @override
  ConsumerState<BillCustomizationScreen> createState() =>
      _BillCustomizationScreenState();
}

class _BillCustomizationScreenState
    extends ConsumerState<BillCustomizationScreen> {
  bool _isSaving = false;
  bool _isGenerating = false;

  final TextEditingController _shopNameCtrl = TextEditingController();
  final TextEditingController _taglineCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _landlineCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _gstCtrl = TextEditingController();
  final TextEditingController _cinNumberCtrl = TextEditingController();

  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _branchNameCtrl = TextEditingController();
  final TextEditingController _acHolderCtrl = TextEditingController();
  final TextEditingController _acNumberCtrl = TextEditingController();
  final TextEditingController _ifscCtrl = TextEditingController();
  final TextEditingController _upiIdCtrl = TextEditingController();

  final TextEditingController _terms1Ctrl = TextEditingController();
  final TextEditingController _terms2Ctrl = TextEditingController();
  final TextEditingController _terms3Ctrl = TextEditingController();

  String? _logoUrl;
  String? _qrUrl;

  String _previewFormat = 'A4';
  Uint8List? _previewBytes;

  // Local cache for images
  static Uint8List? _cachedDefaultLogo;
  static Uint8List? _cachedLogoBytes;
  static String? _cachedLogoUrl;
  static Uint8List? _cachedQrBytes;
  static String? _cachedQrUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final settings = await ref.read(settingsProvider.future);
        _populateFields(settings);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading settings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _taglineCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _landlineCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    _cinNumberCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchNameCtrl.dispose();
    _acHolderCtrl.dispose();
    _acNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _upiIdCtrl.dispose();
    _terms1Ctrl.dispose();
    _terms2Ctrl.dispose();
    _terms3Ctrl.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> settings) {
    if (!mounted) return;
    setState(() {
      _shopNameCtrl.text = settings['shop_name'] ?? '';
      _taglineCtrl.text = settings['tagline'] ?? '';
      _addressCtrl.text = settings['address'] ?? '';
      _phoneCtrl.text = settings['phone'] ?? '';
      _landlineCtrl.text = settings['landline'] ?? '';
      _emailCtrl.text = settings['email'] ?? '';
      _gstCtrl.text = settings['gst_number'] ?? '';
      _cinNumberCtrl.text = settings['cin_number'] ?? settings['drug_licence'] ?? '';

      _bankNameCtrl.text = settings['bank_name'] ?? '';
      _branchNameCtrl.text = settings['branch_name'] ?? '';
      _acHolderCtrl.text = settings['ac_holder_name'] ?? '';
      _acNumberCtrl.text = settings['ac_number'] ?? '';
      _ifscCtrl.text = settings['ifsc_code'] ?? '';
      _upiIdCtrl.text = settings['upi_id'] ?? '';

      _terms1Ctrl.text = settings['terms_1'] ?? '';
      _terms2Ctrl.text = settings['terms_2'] ?? '';
      _terms3Ctrl.text = settings['terms_3'] ?? '';

      _logoUrl = settings['logo_url'];
      _qrUrl = settings['qr_url'];
    });
  }

  Future<void> _saveSettings() async {
    final gst = _gstCtrl.text.trim();
    if (gst.isNotEmpty && !RegExp(r'^[A-Za-z0-9]{15}$').hasMatch(gst)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'GST Number must be exactly 15 alphanumeric characters',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone Number must be exactly 10 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cin = _cinNumberCtrl.text.trim();
    if (cin.isNotEmpty && !RegExp(r'^[A-Za-z0-9]{21}$').hasMatch(cin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'CIN Number must be exactly 21 alphanumeric characters',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final data = {
        'shop_name': _shopNameCtrl.text,
        'tagline': _taglineCtrl.text,
        'address': _addressCtrl.text,
        'phone': _phoneCtrl.text,
        'landline': _landlineCtrl.text,
        'email': _emailCtrl.text,
        'gst_number': _gstCtrl.text,
        'cin_number': _cinNumberCtrl.text.trim(),
        'drug_licence': _cinNumberCtrl.text.trim(),
        'bank_name': _bankNameCtrl.text,
        'branch_name': _branchNameCtrl.text,
        'ac_holder_name': _acHolderCtrl.text,
        'ac_number': _acNumberCtrl.text,
        'ifsc_code': _ifscCtrl.text,
        'upi_id': _upiIdCtrl.text.trim(),
        'terms_1': _terms1Ctrl.text,
        'terms_2': _terms2Ctrl.text,
        'terms_3': _terms3Ctrl.text,
        'logo_url': _logoUrl,
        'qr_url': _qrUrl,
      };

      await ref.read(settingsProvider.notifier).updateSettings(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage(bool isLogo) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.bytes != null) {
      try {
        final bytes = result.files.single.bytes!;
        final filename = result.files.single.name;
        String url;
        if (isLogo) {
          url = await ShopSettingsService.uploadLogo(bytes, filename);
          setState(() => _logoUrl = url);
        } else {
          url = await ShopSettingsService.uploadQr(bytes, filename);
          setState(() => _qrUrl = url);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _generatePreviewPdf() async {
    setState(() {
      _isGenerating = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generating Preview...'),
          ],
        ),
      ),
    );

    Uint8List? finalLogoBytes;
    Uint8List? finalQrBytes;

    try {
      if (_logoUrl != null && _logoUrl!.isNotEmpty) {
        if (_cachedLogoUrl == _logoUrl && _cachedLogoBytes != null) {
          finalLogoBytes = _cachedLogoBytes;
        } else {
          final res = await ApiClient().dio.get(
            _logoUrl!,
            options: Options(responseType: ResponseType.bytes),
          );
          if (res.statusCode == 200) {
            _cachedLogoBytes = res.data;
            _cachedLogoUrl = _logoUrl;
            finalLogoBytes = _cachedLogoBytes;
          }
        }
      } else {
        if (_cachedDefaultLogo == null) {
          final ByteData bytes = await rootBundle.load('assets/LOGO.png');
          _cachedDefaultLogo = bytes.buffer.asUint8List();
        }
        finalLogoBytes = _cachedDefaultLogo;
      }

      if (_qrUrl != null && _qrUrl!.isNotEmpty) {
        if (_cachedQrUrl == _qrUrl && _cachedQrBytes != null) {
          finalQrBytes = _cachedQrBytes;
        } else {
          final res = await ApiClient().dio.get(
            _qrUrl!,
            options: Options(responseType: ResponseType.bytes),
          );
          if (res.statusCode == 200) {
            _cachedQrBytes = res.data;
            _cachedQrUrl = _qrUrl;
            finalQrBytes = _cachedQrBytes;
          }
        }
      }

      final settings = ShopSettings(
        shopName: _shopNameCtrl.text,
        tagline: _taglineCtrl.text,
        address: _addressCtrl.text,
        phone: _phoneCtrl.text,
        landline: _landlineCtrl.text,
        email: _emailCtrl.text,
        gstNumber: _gstCtrl.text,
        cinNumber: _cinNumberCtrl.text,
        bankName: _bankNameCtrl.text,
        branchName: _branchNameCtrl.text,
        acHolderName: _acHolderCtrl.text,
        acNumber: _acNumberCtrl.text,
        ifscCode: _ifscCtrl.text,
        upiId: _upiIdCtrl.text.trim(),
        terms1: _terms1Ctrl.text,
        terms2: _terms2Ctrl.text,
        terms3: _terms3Ctrl.text,
      );

      final dummyItems = [
        BillItem(
          id: '1',
          name: 'Paracetamol 500mg',
          batch: 'B123',
          expiry: '12/25',
          hsn: '3004',
          qty: 2,
          mrp: 25.0,
          price: 25.0,
          cgst: 6,
          sgst: 6,
          total: 50.0,
        ),
        BillItem(
          id: '2',
          name: 'Amoxicillin 250mg',
          batch: 'B456',
          expiry: '10/24',
          hsn: '3004',
          qty: 1,
          mrp: 120.0,
          price: 120.0,
          cgst: 6,
          sgst: 6,
          total: 120.0,
        ),
        BillItem(
          id: '3',
          name: 'Cough Syrup 100ml',
          batch: 'C789',
          expiry: '05/26',
          hsn: '3004',
          qty: 1,
          mrp: 85.0,
          price: 85.0,
          cgst: 6,
          sgst: 6,
          total: 85.0,
        ),
      ].map((e) => e.toMap()).toList();

      final args = {
        'items': dummyItems,
        'subtotal': 170.0,
        'discount': 0.0,
        'tax': 20.4,
        'grandTotal': 190.4,
        'invoiceNumber': 'PREVIEW-001',
        'customerName': 'John Doe',
        'customerPhone': '9876543210',
        'customerLocation': 'Mumbai',
        'doctorName': 'Dr. Smith',
        'format': _previewFormat,
        'shopSettings': settings.toMap(),
        'logoBytes': finalLogoBytes,
        'qrBytes': finalQrBytes,
      };

      final bytes = await PdfGenerator.generateBill(
        items: args['items'] as List<Map<String, dynamic>>,
        subtotal: args['subtotal'] as double,
        discount: args['discount'] as double,
        tax: args['tax'] as double,
        grandTotal: args['grandTotal'] as double,
        invoiceNumber: args['invoiceNumber'] as String,
        customerName: args['customerName'] as String,
        customerPhone: args['customerPhone'] as String,
        customerLocation: args['customerLocation'] as String,
        doctorName: args['doctorName'] as String,
        format: args['format'] as String,
        shopSettings: args['shopSettings'] as Map<String, dynamic>,
        logoBytes: args['logoBytes'] as Uint8List?,
        qrBytes: args['qrBytes'] as Uint8List?,
      );

      if (mounted) {
        setState(() {
          _previewBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    if (settingsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Bill Customization',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Builder(
                builder: (context) {
                  final isDesktop =
                      Responsive.isDesktop(context) ||
                      Responsive.isTablet(context);

                  final rightPane = BillPreviewPanel(
                    previewFormat: _previewFormat,
                    previewBytes: _previewBytes,
                    isGenerating: _isGenerating,
                    onFormatChanged: (format) {
                      setState(() {
                        _previewFormat = format;
                        _previewBytes = null;
                      });
                    },
                    onGeneratePreview: _generatePreviewPdf,
                  );

                  final leftPane = DefaultTabController(
                    length: isDesktop ? 2 : 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            isScrollable: !isDesktop,
                            tabAlignment: !isDesktop
                                ? TabAlignment.start
                                : TabAlignment.fill,
                            labelColor: isDark
                                ? Colors.green[400]
                                : const Color(0xFF166534),
                            unselectedLabelColor: isDark
                                ? Colors.grey[400]
                                : const Color(0xFF64748B),
                            indicatorColor: const Color(0xFF22C55E),
                            tabs: [
                              const Tab(text: 'Shop Details'),
                              const Tab(text: 'Bill Customization'),
                              if (!isDesktop) const Tab(text: 'Live Preview'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TabBarView(
                            children: [
                              SingleChildScrollView(
                                child: Column(
                                  children: [
                                    ShopDetailsCard(
                                      shopNameCtrl: _shopNameCtrl,
                                      taglineCtrl: _taglineCtrl,
                                      addressCtrl: _addressCtrl,
                                      phoneCtrl: _phoneCtrl,
                                      landlineCtrl: _landlineCtrl,
                                      emailCtrl: _emailCtrl,
                                      gstCtrl: _gstCtrl,
                                      cinNumberCtrl: _cinNumberCtrl,
                                    ),
                                    const SizedBox(height: 16),
                                    BankDetailsCard(
                                      bankNameCtrl: _bankNameCtrl,
                                      branchNameCtrl: _branchNameCtrl,
                                      acHolderCtrl: _acHolderCtrl,
                                      acNumberCtrl: _acNumberCtrl,
                                      ifscCtrl: _ifscCtrl,
                                      upiIdCtrl: _upiIdCtrl,
                                    ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                child: Column(
                                  children: [
                                    TermsConditionsCard(
                                      terms1Ctrl: _terms1Ctrl,
                                      terms2Ctrl: _terms2Ctrl,
                                      terms3Ctrl: _terms3Ctrl,
                                    ),
                                    const SizedBox(height: 16),
                                    MediaUploadCard(
                                      logoUrl: _logoUrl,
                                      qrUrl: _qrUrl,
                                      onPickLogo: () => _pickImage(true),
                                      onPickQr: () => _pickImage(false),
                                      onClearLogo: () =>
                                          setState(() => _logoUrl = null),
                                      onClearQr: () =>
                                          setState(() => _qrUrl = null),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isDesktop) rightPane,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: leftPane),
                        const SizedBox(width: 24),
                        Expanded(child: rightPane),
                      ],
                    );
                  } else {
                    return leftPane;
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
