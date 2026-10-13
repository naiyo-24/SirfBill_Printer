import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/inventory_service.dart';
import '../../services/customer_service.dart';
import '../../services/billing_service.dart';
import '../../services/draft_service.dart';
import '../../services/billing_history_service.dart';
import '../../services/transaction_service.dart';
import '../../utils/pdf_generator.dart';
import '../../services/shop_settings_service.dart';
import '../../providers/billing_provider.dart';
import '../../providers/counter_providers.dart';

import 'widgets/billing/billing_left_panel.dart';
import 'widgets/billing/billing_right_panel.dart';
import 'widgets/billing/billing_header.dart';
import 'widgets/billing/billing_dialogs.dart';
import 'widgets/billing/drafts_dialog.dart';
import 'widgets/billing/bill_preview_dialog.dart';
import 'widgets/billing/customer_search_field.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  List<Map<String, dynamic>> get _currentBill =>
      ref.watch(billingProvider).currentBill;

  List<Customer> _allCustomers = [];

  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final FocusNode _customerNameFocusNode = FocusNode();
  final TextEditingController _customerSearchController = TextEditingController();
  final FocusNode _customerSearchFocusNode = FocusNode();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerLocationController = TextEditingController();
  final TextEditingController _itemSearchController = TextEditingController();

  Timer? _searchDebounce;
  String? _savedCustomerId;
  Map<String, dynamic>? _shopSettings;
  bool _isGeneratingBill = false;

  double get _subtotal => ref.read(billingProvider).subtotal;
  double get _discountAmount => ref.read(billingProvider).discountAmount;
  double get _gstAmount => ref.read(billingProvider).gstAmount;
  double get _grandTotal => ref.read(billingProvider).grandTotal;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _fetchShopSettings();
    _discountController.addListener(_onDiscountChanged);
  }

  void _onDiscountChanged() {
    final val = double.tryParse(_discountController.text) ?? 0.0;
    final isPerc = ref.read(billingProvider).isDiscountPercentage;
    if (ref.read(billingProvider).discountValue != val) {
      ref.read(billingProvider.notifier).updateDiscount(val, isPerc);
    }
  }

  Future<void> _fetchShopSettings() async {
    try {
      _shopSettings = await ShopSettingsService.getSettings();
      PdfGenerator.preloadFonts();

      if (_shopSettings?['logo_url'] != null) {
        String url = _shopSettings!['logo_url'];
        if (PdfGenerator.getCachedLogoUrl() != url) {
          PdfGenerator.preloadLogo(url);
        }
      }
      if (_shopSettings?['qr_url'] != null) {
        String url = _shopSettings!['qr_url'];
        if (PdfGenerator.getCachedQrUrl() != url) {
          PdfGenerator.preloadQr(url);
        }
      }
    } catch (e) {
      debugPrint('Error fetching shop settings: $e');
    }
  }

  @override
  void dispose() {
    _discountController.removeListener(_onDiscountChanged);
    _discountController.dispose();
    _customerNameController.dispose();
    _customerNameFocusNode.dispose();
    _customerSearchController.dispose();
    _customerSearchFocusNode.dispose();
    _customerPhoneController.dispose();
    _customerLocationController.dispose();
    _itemSearchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    try {
      final customers = await CustomerService.getCustomers();
      if (mounted) {
        setState(() {
          _allCustomers = customers;
        });
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }
  }

  String _generateInvoiceNo() {
    String baseInvoice =
        _shopSettings?['shop_name']
            ?.toString()
            .replaceAll(' ', '')
            .toUpperCase() ??
        'INV';
    if (baseInvoice.length > 5) baseInvoice = baseInvoice.substring(0, 5);
    return '$baseInvoice${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  Future<void> _saveDraft() async {
    if (_currentBill.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save empty draft')),
      );
      return;
    }

    final draft = DraftBill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerName: _customerNameController.text,
      customerPhone: _customerPhoneController.text,
      customerAge: '',
      doctorName: '',
      format: ref.read(billingProvider).selectedFormat,
      items: List.from(_currentBill),
      discountValue: ref.read(billingProvider).discountValue,
      isDiscountPercentage: ref.read(billingProvider).isDiscountPercentage,
      createdAt: DateTime.now(),
    );

    await DraftService.saveDraft(draft);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill saved as draft!')),
      );
      ref.read(billingProvider.notifier).clearBill();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerLocationController.clear();
      _discountController.clear();
      setState(() {});
    }
  }

  Future<void> _saveCustomerToDb() async {
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a customer name to save.')),
      );
      return;
    }

    final customer = Customer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _customerNameController.text,
      phone: _customerPhoneController.text,
      location: _customerLocationController.text,
    );

    try {
      final savedCustomer = await CustomerService.saveCustomer(customer);
      if (mounted) {
        setState(() {
          _savedCustomerId = savedCustomer.id;
        });
        ref.invalidate(customerProvider);
        _fetchCustomers();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer saved to database successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Error Saving Customer', style: TextStyle(color: Colors.red)),
              ],
            ),
            content: Text(errorMessage),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(color: Color(0xFF166534))),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _showDraftsDialog() async {
    await DraftsDialog.show(
      context,
      onDraftSelected: (draft) {
        setState(() {
          ref.read(billingProvider.notifier).setBill(List.from(draft.items));
          _customerNameController.text = draft.customerName;
          _customerPhoneController.text = draft.customerPhone;
          ref.read(billingProvider.notifier).updateSelectedFormat(
                draft.format.isNotEmpty ? draft.format : 'A4',
              );
          ref.read(billingProvider.notifier).updateDiscount(
                draft.discountValue,
                draft.isDiscountPercentage,
              );
          _discountController.text =
              draft.discountValue > 0 ? draft.discountValue.toString() : '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft loaded successfully!')),
        );
      },
    );
  }

  Future<void> _showBillPreview() async {
    if (_currentBill.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to the bill first.')),
      );
      return;
    }

    final String invoiceNo = _generateInvoiceNo();
    final futurePdfBytes = Future.delayed(
      const Duration(milliseconds: 50),
      () => PdfGenerator.generateBill(
        items: _currentBill,
        subtotal: _subtotal,
        discount: _discountAmount,
        tax: _gstAmount,
        grandTotal: _grandTotal,
        invoiceNumber: invoiceNo,
        customerName: _customerNameController.text.isNotEmpty
            ? _customerNameController.text
            : 'Walk-in Customer',
        customerPhone: _customerPhoneController.text,
        customerLocation: _customerLocationController.text,
        shopSettings: _shopSettings,
        doctorName: '',
        paymentMethod: ref.read(billingProvider).paymentMethod,
        gstNumber: ref.read(billingProvider).gstNumber,
        format: ref.read(billingProvider).selectedFormat,
      ),
    );

    BillPreviewDialog.show(
      context,
      pdfFuture: futurePdfBytes,
      format: ref.read(billingProvider).selectedFormat,
      invoiceNo: invoiceNo,
    );
  }

  Future<void> _generateAndSaveBill() async {
    if (_isGeneratingBill) return;

    if (_currentBill.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to the bill first.')),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isGeneratingBill = true);

    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Generating bill..."),
              ],
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      if (_customerNameController.text.isNotEmpty) {
        final existingCust = _allCustomers.where(
          (c) => c.name.toLowerCase() == _customerNameController.text.toLowerCase(),
        ).toList();
        if (existingCust.isNotEmpty) {
          _savedCustomerId = existingCust.first.id;
        } else {
          final newCust = await CustomerService.saveCustomer(
            Customer(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _customerNameController.text,
              phone: _customerPhoneController.text,
            ),
          );
          _savedCustomerId = newCust.id;
          _allCustomers.add(newCust);
        }
      }

      final String invoiceNo = _generateInvoiceNo();

      if (_currentBill.isNotEmpty) {
        await BillingService.checkout(
          items: _currentBill,
          totalAmount: _grandTotal,
          customerId: _savedCustomerId,
          customerName: _customerNameController.text.isNotEmpty
              ? _customerNameController.text
              : 'Walk-in Customer',
          customerPhone: _customerPhoneController.text,
          customerLocation: _customerLocationController.text,
          customerGstin: ref.read(billingProvider).gstNumber,
          invoiceNo: invoiceNo,
          paymentMethod: ref.read(billingProvider).paymentMethod,
        );
      }

      ref.invalidate(inventoryProvider);
      ref.invalidate(billingInventoryProvider);
      ref.invalidate(customerProvider);

      final pdfBytes = await PdfGenerator.generateBill(
        items: _currentBill,
        subtotal: _subtotal,
        discount: _discountAmount,
        tax: _gstAmount,
        grandTotal: _grandTotal,
        invoiceNumber: invoiceNo,
        customerName: _customerNameController.text.isNotEmpty
            ? _customerNameController.text
            : 'Walk-in Customer',
        customerPhone: _customerPhoneController.text,
        customerLocation: _customerLocationController.text,
        shopSettings: _shopSettings,
        doctorName: '',
        paymentMethod: ref.read(billingProvider).paymentMethod,
        gstNumber: ref.read(billingProvider).gstNumber,
        format: ref.read(billingProvider).selectedFormat,
      );

      await FileSaver.instance.saveFile(
        name: invoiceNo,
        bytes: pdfBytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Bill generated and saved successfully! Preparing to print...'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await BillingHistoryService.saveBill(
        SavedBill(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          invoiceNo: invoiceNo,
          customerName: _customerNameController.text.isNotEmpty
              ? _customerNameController.text
              : 'Walk-in Customer',
          customerPhone: _customerPhoneController.text,
          customerLocation: _customerLocationController.text,
          customerGstin: ref.read(billingProvider).gstNumber,
          doctorName: '',
          paymentMode: ref.read(billingProvider).paymentMethod,
          subtotal: _subtotal,
          discount: _discountAmount,
          tax: _gstAmount,
          grandTotal: _grandTotal,
          items: List.from(_currentBill),
          createdAt: DateTime.now(),
          format: ref.read(billingProvider).selectedFormat,
        ),
      );

      // Record sale in Accounts
      try {
        final paymentMethod = ref.read(billingProvider).paymentMethod;
        await TransactionService.saveTransaction({
          "date": DateTime.now().toIso8601String(),
          "amount": _grandTotal,
          "transaction_type": "INCOME",
          "description": "Sale - Invoice #$invoiceNo (${_customerNameController.text.isNotEmpty ? _customerNameController.text : 'Walk-in'})",
          "category_name": "Sales",
          "category": "Sales",
          "payment_mode": paymentMethod,
        });
      } catch (e) {
        debugPrint('Error recording transaction in Accounts: $e');
      }

      ref.invalidate(historyProvider);
      ref.invalidate(accountsProvider);

      _clearCart();

      if (dialogContext != null && dialogContext!.mounted) {
        final ctx = dialogContext!;
        dialogContext = null;
        Navigator.pop(ctx);
      }

      if (mounted) {
        setState(() => _isGeneratingBill = false);
      }

      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        final selectedFormat = ref.read(billingProvider).selectedFormat;
        PdfPageFormat pageFormat = PdfPageFormat.a4;
        if (selectedFormat == 'A5') {
          pageFormat = PdfPageFormat.a5.landscape;
        } else if (selectedFormat == 'Thermal') {
          pageFormat = const PdfPageFormat(80 * PdfPageFormat.mm, 300 * PdfPageFormat.mm);
        }

        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: '$invoiceNo.pdf',
          format: pageFormat,
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error generating bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (dialogContext != null && dialogContext!.mounted) {
        final ctx = dialogContext!;
        dialogContext = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ctx.mounted) Navigator.pop(ctx);
        });
      }
      if (mounted) {
        setState(() => _isGeneratingBill = false);
      }
    }
  }

  void _increaseQty(int index) {
    final item = _currentBill[index];
    final packStock = item['stock'] ?? 0;
    final looseStock = item['loose_stock'] ?? 0;
    final packSize = item['pack_size'] ?? 1;
    final isLoose = item['is_loose'] ?? false;
    final currentQty = item['qty'] ?? 0;
    final itemName = item['name'];

    final int availableLimit = isLoose ? (packStock * packSize) + looseStock : packStock;

    if (currentQty >= availableLimit) {
      BillingDialogs.showStockLimitReachedDialog(
        context,
        itemName,
        availableLimit,
        isLoose,
      );
      return;
    }

    ref.read(billingProvider.notifier).updateItemQuantity(index, currentQty + 1);
  }

  void _decreaseQty(int index) {
    if (_currentBill[index]['qty'] > 1) {
      ref.read(billingProvider.notifier).updateItemQuantity(index, _currentBill[index]['qty'] - 1);
    }
  }

  void _removeItem(int index) {
    ref.read(billingProvider.notifier).removeItem(index);
  }

  void _clearCart() {
    ref.read(billingProvider.notifier).clearBill();
    setState(() {
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerLocationController.clear();
      _customerSearchController.clear();
      _discountController.clear();
      _savedCustomerId = null;
    });
    ref.read(billingProvider.notifier).updateDiscount(0.0, false);
    ref.read(billingInventoryProvider.notifier).loadInventory();
    _fetchCustomers();
  }

  void _addToCart(Map<String, dynamic> item) async {
    final isCustom = item['is_custom'] ?? false;
    final stock = item['stock'] ?? 0;

    final existingIndex = _currentBill.indexWhere(
      (element) => element['name'] == item['name'],
    );

    if (existingIndex >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['name'].toString().split(' - Item')[0]} is already in the cart!'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!isCustom && stock <= 0) {
      BillingDialogs.showOutOfStockDialog(context, item['name']);
      return;
    }

    double mrp = (item['mrp'] as num?)?.toDouble() ?? 0.0;
    double discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
    double totalAfterDiscount = mrp - (mrp * (discount / 100));

    int packSize = (item['pack_size'] as num?)?.toInt() ?? 1;
    bool isLoose = false;

    if (!isCustom && packSize > 1) {
      final result = await BillingDialogs.showQuantityTypeDialog(context, item['name']);
      if (result == null) return;
      isLoose = result;
    }

    if (isLoose && packSize > 1) {
      double effectivePrice = mrp / packSize;
      totalAfterDiscount = effectivePrice - (effectivePrice * (discount / 100));
    }

    final initialQty = item['qty'] ?? 1;
    final customId = 'custom_${DateTime.now().millisecondsSinceEpoch}';

    ref.read(billingProvider.notifier).addItem({
      'inventory_item_id': item['inventory_item_id'] ?? customId,
      'name': item['name'],
      'brand': item['brand'],
      'qty': initialQty,
      'price': mrp,
      'mrp': mrp,
      'total': totalAfterDiscount * initialQty,
      'batch': (item['batch_number'] != null && item['batch_number'].toString().isNotEmpty)
          ? item['batch_number']
          : (item['batch'] ?? '-'),
      'expiry': (item['expiry_date'] != null && item['expiry_date'].toString().isNotEmpty)
          ? item['expiry_date']
          : (item['expiry'] ?? '-'),
      'hsn': (item['hsn_code'] != null && item['hsn_code'].toString().isNotEmpty)
          ? item['hsn_code']
          : (item['hsn'] ?? '-'),
      'discount': item['discount'] ?? 0.0,
      'cgst': item['cgst'] ?? 0,
      'sgst': item['sgst'] ?? 0,
      'gst': item['gst'] ?? ((item['cgst'] ?? 0) + (item['sgst'] ?? 0)),
      'stock': isCustom ? 999999 : stock,
      'pack_size': item['pack_size'] ?? 1,
      'loose_stock': item['loose_stock'] ?? 0,
      'is_loose': isLoose,
      'id': item['inventory_item_id'] ?? customId,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${item['name'].toString().split(' - Item')[0]} to cart'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _mapAndSortInventory(List<InventoryItem> items) {
    final mapped = items.map((item) => {
      'inventory_item_id': item.id,
      'name': item.name,
      'brand': item.manufacturer,
      'pack': item.sku,
      'mrp': item.unitPrice,
      'stock': item.stockQuantity,
      'batch_number': item.batchNumber,
      'hsn_code': (item.hsnCode != null && item.hsnCode!.isNotEmpty) ? item.hsnCode : '-',
      'expiry_date': item.expiryDate.isNotEmpty ? item.expiryDate : '-',
      'cgst': (item.gst ?? 0.0) / 2,
      'sgst': (item.gst ?? 0.0) / 2,
      'gst': item.gst ?? 0.0,
      'discount': item.discount ?? 0.0,
      'category_id': item.categoryId,
      'rack_id': item.rackId,
      'pack_size': item.packSize ?? 1,
      'loose_stock': item.looseStock,
    }).toList();

    mapped.sort((a, b) {
      final nameA = (a['name'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    return mapped;
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(billingInventoryProvider);
    final allItems = inventoryState.when(
      data: _mapAndSortInventory,
      loading: () => <Map<String, dynamic>>[],
      error: (_, _) => <Map<String, dynamic>>[],
    );

    final categoryAsync = ref.watch(categoryProvider);
    final backendCategories = categoryAsync.value ?? [];
    final dynamicCategories = ['All', ...backendCategories.map((c) => c.name)];

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BillingHeaderWidget(
            onRefresh: () {
              final selectedIndex = ref.read(billingProvider).selectedCategoryIndex;
              String? categoryId;
              if (selectedIndex != 0 && selectedIndex <= backendCategories.length) {
                categoryId = backendCategories[selectedIndex - 1].id;
              }

              ref.read(billingInventoryProvider.notifier).loadInventory(
                searchQuery: _itemSearchController.text.isNotEmpty
                    ? _itemSearchController.text
                    : null,
                categoryId: categoryId,
              );
              _fetchCustomers();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshed inventory and data.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isDesktopWidth = constraints.maxWidth > 1100;
                  bool hasEnoughHeight = constraints.maxHeight > 850;

                  Widget leftSide = inventoryState.when(
                    data: (_) => BillingLeftPanel(
                      isDesktopWidth: isDesktopWidth,
                      hasEnoughHeight: isDesktopWidth ? hasEnoughHeight : true,
                      filteredItems: allItems,
                      categories: dynamicCategories,
                      selectedCategoryIndex: ref.watch(billingProvider).selectedCategoryIndex,
                      onAddToCart: _addToCart,
                      onCategorySelected: (index) {
                        ref.read(billingProvider.notifier).updateCategory(index);
                        String? categoryId;
                        if (index != 0 && index <= backendCategories.length) {
                          categoryId = backendCategories[index - 1].id;
                        }
                        ref.read(billingInventoryProvider.notifier).loadInventory(
                          searchQuery: _itemSearchController.text,
                          categoryId: categoryId,
                        );
                      },
                      hasMore: ref.read(billingInventoryProvider.notifier).hasMore,
                      onLoadMore: () {
                        ref.read(billingInventoryProvider.notifier).loadMore();
                      },
                      searchController: _itemSearchController,
                      onSearch: (q) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                          final selectedIndex = ref.read(billingProvider).selectedCategoryIndex;
                          String? categoryId;
                          if (selectedIndex != 0 && selectedIndex <= backendCategories.length) {
                            categoryId = backendCategories[selectedIndex - 1].id;
                          }
                          ref.read(billingInventoryProvider.notifier).loadInventory(
                            searchQuery: q.trim().isEmpty ? null : q.trim(),
                            categoryId: categoryId,
                          );
                        });
                      },
                      onSubmitted: (q) {
                        _searchDebounce?.cancel();
                        final selectedIndex = ref.read(billingProvider).selectedCategoryIndex;
                        String? categoryId;
                        if (selectedIndex != 0 && selectedIndex <= backendCategories.length) {
                          categoryId = backendCategories[selectedIndex - 1].id;
                        }
                        ref.read(billingInventoryProvider.notifier).loadInventory(
                          searchQuery: q.trim().isEmpty ? null : q.trim(),
                          categoryId: categoryId,
                        );
                      },
                    ),
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Color(0xFF22C55E)),
                    ),
                    error: (err, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(err.toString(), style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.read(billingInventoryProvider.notifier).loadInventory(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );

                  Widget rightSide = BillingRightPanel(
                    hasEnoughHeight: isDesktopWidth && hasEnoughHeight,
                    discountController: _discountController,
                    customerNameController: _customerNameController,
                    customerPhoneController: _customerPhoneController,
                    customerLocationController: _customerLocationController,
                    onClearCart: _clearCart,
                    onDecreaseQty: _decreaseQty,
                    onIncreaseQty: _increaseQty,
                    onRemoveItem: _removeItem,
                    onUpdateItemDiscount: (index, disc) {
                      ref.read(billingProvider.notifier).updateItemDiscount(index, disc);
                    },
                    onSaveCustomerToDb: _saveCustomerToDb,
                    onSaveDraft: _saveDraft,
                    onShowDraftsDialog: _showDraftsDialog,
                    onShowBillPreview: _showBillPreview,
                    onGenerateBill: _generateAndSaveBill,
                    customerSearchField: CustomerSearchField(
                      searchController: _customerSearchController,
                      searchFocusNode: _customerSearchFocusNode,
                      allCustomers: _allCustomers,
                      onCustomerSelected: (selection) {
                        if (selection.id == 'NO_DATA') return;
                        _customerNameController.text = selection.name;
                        _customerPhoneController.text = selection.phone;
                        _customerLocationController.text = selection.location;
                        _customerSearchController.clear();
                        setState(() {
                          _savedCustomerId = selection.id;
                        });
                      },
                    ),
                    isGeneratingBill: _isGeneratingBill,
                  );

                  if (isDesktopWidth) {
                    Widget content = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 13, child: leftSide),
                        const SizedBox(width: 24),
                        Expanded(flex: 9, child: rightSide),
                      ],
                    );
                    return hasEnoughHeight
                        ? content
                        : SingleChildScrollView(child: content);
                  } else {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 500,
                            child: leftSide,
                          ),
                          const SizedBox(height: 24),
                          rightSide,
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
