import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/ghana_card_ocr_service.dart';

class CustomerCreateScreen extends StatefulWidget {
  const CustomerCreateScreen({super.key});

  @override
  State<CustomerCreateScreen> createState() => _CustomerCreateScreenState();
}

class _CustomerCreateScreenState extends State<CustomerCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _digitalAddressCtrl = TextEditingController();

  bool _loading = false;
  bool _scanning = false;
  File? _idDocumentFront;

  final GhanaCardOcrService _ocrService = GhanaCardOcrService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _idNumberCtrl.dispose();
    _dobCtrl.dispose();
    _digitalAddressCtrl.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // ─── Ghana Card Scanning ──────────────────────────────────────────────────

  Future<void> _scanGhanaCard() async {
    // Let the user choose camera or gallery (gallery useful for testing on simulator)
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: MerchantTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Select Image Source',
                  style: TextStyle(
                    color: MerchantTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt,
                    color: MerchantTheme.primary),
                title: const Text('Camera',
                    style: TextStyle(color: MerchantTheme.textPrimary)),
                subtitle: const Text('Take a photo of the Ghana Card',
                    style: TextStyle(color: MerchantTheme.textMuted, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library,
                    color: MerchantTheme.primary),
                title: const Text('Gallery',
                    style: TextStyle(color: MerchantTheme.textPrimary)),
                subtitle: const Text('Choose an existing photo',
                    style: TextStyle(color: MerchantTheme.textMuted, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;

    setState(() => _scanning = true);

    try {
      final imageFile = File(picked.path);
      final cardData = await _ocrService.processImage(imageFile);

      setState(() {
        _idDocumentFront = imageFile;
      });

      // Auto-fill fields (only if OCR found values)
      if (cardData.fullName != null && _nameCtrl.text.isEmpty) {
        _nameCtrl.text = cardData.fullName!;
      }
      if (cardData.idNumber != null) {
        _idNumberCtrl.text = cardData.idNumber!;
      }
      if (cardData.dateOfBirth != null) {
        _dobCtrl.text = cardData.dateOfBirth!;
      }
      if (cardData.digitalAddress != null) {
        _digitalAddressCtrl.text = cardData.digitalAddress!;
      }

      if (mounted) {
        final pct = (cardData.confidence * 100).round();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cardData.confidence >= 0.75
                  ? 'Card scanned successfully ($pct% fields detected)'
                  : 'Partial scan ($pct% fields detected). Please verify and complete the fields.',
            ),
            backgroundColor: cardData.confidence >= 0.75
                ? MerchantTheme.accent
                : MerchantTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: MerchantTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  // ─── Create Customer ──────────────────────────────────────────────────────

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final api = context.read<AuthProvider>().api;
    if (api == null) return;
    setState(() => _loading = true);

    try {
      await api.createCustomer(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        idType: _idNumberCtrl.text.isNotEmpty ? 'national_id' : '',
        idNumber: _idNumberCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim(),
        digitalAddress: _digitalAddressCtrl.text.trim(),
        idDocumentFront: _idDocumentFront,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer registered successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: MerchantTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Date of Birth Picker ─────────────────────────────────────────────────

  Future<void> _pickDateOfBirth() async {
    DateTime initial = DateTime(1990, 1, 1);
    if (_dobCtrl.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_dobCtrl.text);
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Customer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Scan Ghana Card section ──
              _buildScanSection(),
              const SizedBox(height: 24),

              // ── Personal details ──
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  hintText: '0XX XXX XXXX',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'City (optional)',
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 24),

              // ── Ghana Card fields ──
              TextFormField(
                controller: _idNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghana Card Number (optional)',
                  prefixIcon: Icon(Icons.credit_card),
                  hintText: 'GHA-XXXXXXXXX-X',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final regex = RegExp(r'^GHA-\d{9}-\d$');
                  if (!regex.hasMatch(v.toUpperCase())) {
                    return 'Format: GHA-XXXXXXXXX-X';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobCtrl,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth (optional)',
                  prefixIcon: Icon(Icons.calendar_today),
                  hintText: 'YYYY-MM-DD',
                ),
                readOnly: true,
                onTap: _pickDateOfBirth,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _digitalAddressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Digital Address (optional)',
                  prefixIcon: Icon(Icons.pin_drop),
                  hintText: 'GA-XXX-XXXX',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final regex = RegExp(r'^[A-Z]{2}-\d{3}-\d{4}$');
                  if (!regex.hasMatch(v.toUpperCase())) {
                    return 'Format: XX-XXX-XXXX';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _loading ? null : _handleCreate,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Register Customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Scan Section Widget ──────────────────────────────────────────────────

  Widget _buildScanSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MerchantTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MerchantTheme.border),
      ),
      child: Column(
        children: [
          if (_idDocumentFront != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _idDocumentFront!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: MerchantTheme.accent, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ghana Card captured',
                    style: TextStyle(
                      color: MerchantTheme.accent,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _scanning ? null : _scanGhanaCard,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Rescan'),
                ),
              ],
            ),
          ] else ...[
            const Icon(
              Icons.credit_card,
              size: 40,
              color: MerchantTheme.textMuted,
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan Ghana Card to auto-fill details',
              style: TextStyle(
                color: MerchantTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scanning ? null : _scanGhanaCard,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner),
              label: Text(_scanning ? 'Scanning...' : 'Scan Ghana Card'),
            ),
          ],
        ],
      ),
    );
  }
}
