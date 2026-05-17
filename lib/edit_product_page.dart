import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/database_service.dart';
import 'services/input_validator.dart';

class EditProductPage extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic>? product;
  final List<String> categories;

  const EditProductPage({
    super.key,
    required this.storeId,
    required this.categories,
    this.product,
  });

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _baseSizeController = TextEditingController();
  final _baseUnitQuantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final List<_VariantDraft> _variants = [];

  String? _category;
  String? _imagePath;
  String _stockMode = 'independent';
  bool _isActive = true;
  bool _isSaving = false;
  bool _isUploading = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController.text = product?['name']?.toString() ?? '';
    _priceController.text = product?['price']?.toString() ?? '';
    _stockController.text = product?['stock_quantity']?.toString() ?? '0';
    _baseSizeController.text = product?['base_size_label']?.toString() ?? 'Default';
    _baseUnitQuantityController.text =
        product?['base_unit_quantity']?.toString() ?? '1';
    _descriptionController.text = product?['description']?.toString() ?? '';
    _category = product?['category']?.toString();
    _imagePath = product?['main_image_url']?.toString();
    _stockMode = product?['stock_mode']?.toString() == 'shared'
        ? 'shared'
        : 'independent';
    _isActive = product?['is_active'] != false;

    final rawVariants = product?['product_variant'];
    if (rawVariants is List) {
      for (final variant in rawVariants) {
        if (variant is! Map) continue;
        _variants.add(
          _VariantDraft(
            size: variant['size_label']?.toString() ?? '',
            price: variant['price']?.toString() ?? '',
            stock: variant['stock_quantity']?.toString() ?? '0',
            unitQuantity: variant['stock_unit_quantity']?.toString() ?? '1',
            isActive: variant['is_active'] != false,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _baseSizeController.dispose();
    _baseUnitQuantityController.dispose();
    _descriptionController.dispose();
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;

    setState(() => _isUploading = true);
    final path = await DatabaseService.uploadProductImage(
      bytes: await image.readAsBytes(),
      fileName: image.name,
    );

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      if (path != null) _imagePath = path;
    });

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image could not be uploaded')),
      );
    }
  }

  void _addVariant() {
    setState(() {
      _variants.add(
        _VariantDraft(
          size: '',
          price: _priceController.text,
          stock: '0',
          unitQuantity: '1',
        ),
      );
    });
  }

  void _removeVariant(_VariantDraft variant) {
    setState(() {
      _variants.remove(variant);
      variant.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final productName = InputValidator.cleanProductTitle(_nameController.text);
    final baseSize = InputValidator.cleanDisplayText(
      _baseSizeController.text,
      fallback: 'Default',
    );
    final variants = _variants
        .where((variant) => variant.sizeController.text.trim().isNotEmpty)
        .map(
          (variant) => {
            'product_name': productName,
            'size_label': InputValidator.cleanDisplayText(
              variant.sizeController.text,
            ),
            'price': double.parse(variant.priceController.text.trim()),
            'stock_quantity': int.parse(variant.stockController.text.trim()),
            'stock_unit_quantity': int.parse(
              variant.unitQuantityController.text.trim(),
            ),
            'is_active': variant.isActive,
          },
        )
        .toList();

    final ok = _isEditing
        ? await DatabaseService.updateProduct(
            productId: widget.product!['product_id'].toString(),
            name: productName,
            category: _category,
            price: double.parse(_priceController.text.trim()),
            stockQuantity: int.parse(_stockController.text.trim()),
            stockMode: _stockMode,
            baseSizeLabel: baseSize,
            baseUnitQuantity: int.parse(_baseUnitQuantityController.text.trim()),
            mainImageUrl: _imagePath,
            description: _descriptionController.text,
            isActive: _isActive,
            variants: variants,
          )
        : await DatabaseService.insertProduct(
            storeId: widget.storeId,
            name: productName,
            category: _category,
            price: double.parse(_priceController.text.trim()),
            stockQuantity: int.parse(_stockController.text.trim()),
            stockMode: _stockMode,
            baseSizeLabel: baseSize,
            baseUnitQuantity: int.parse(_baseUnitQuantityController.text.trim()),
            mainImageUrl: _imagePath,
            description: _descriptionController.text,
            isActive: _isActive,
            variants: variants,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product could not be saved')),
      );
    }
  }

  Widget _imagePreview() {
    final imagePath = _imagePath;
    if (imagePath == null || imagePath.trim().isEmpty) {
      return Container(
        height: 220,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.add_photo_alternate_outlined, size: 56),
      );
    }

    final url = imagePath.startsWith('http')
        ? imagePath
        : DatabaseService.getProductImageUrl(imagePath);

    return Image.network(
      url,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: 220,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, size: 56),
      ),
    );
  }

  String? _requiredText(String? value) {
    final cleaned = InputValidator.cleanDisplayText(value);
    return cleaned.isEmpty ? 'Required' : null;
  }

  String? _productNameValidator(String? value) {
    return InputValidator.isValidProductName(value?.trim() ?? '')
        ? null
        : 'Enter a valid product name';
  }

  String? _priceValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 0 ? 'Enter a valid price' : null;
  }

  String? _stockValidator(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 0 ? 'Enter valid stock' : null;
  }

  String? _unitValidator(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 1 ? 'Enter 1 or higher' : null;
  }

  String _generatedSku([String? sizeLabel]) {
    return DatabaseService.generateSku(
      _nameController.text,
      sizeLabel ?? _baseSizeController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          TextButton(
            onPressed: _isSaving || _isUploading ? null : _save,
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: _imagePreview()),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isUploading ? null : _pickImage,
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Product Image'),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product Name *'),
              validator: _productNameValidator,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: widget.categories
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _stockMode,
              decoration: const InputDecoration(labelText: 'Stock Mode'),
              items: const [
                DropdownMenuItem(
                  value: 'independent',
                  child: Text('Separate stock per size'),
                ),
                DropdownMenuItem(
                  value: 'shared',
                  child: Text('Shared count stock'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _stockMode = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Base Price *'),
                    keyboardType: TextInputType.number,
                    validator: _priceValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: InputDecoration(
                      labelText: _stockMode == 'shared'
                          ? 'Shared Stock *'
                          : 'Base Stock *',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _stockValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _baseSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Default Size *',
                      hintText: 'Default, 10 pcs, Regular',
                    ),
                    validator: _requiredText,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _baseUnitQuantityController,
                    decoration: InputDecoration(
                      labelText: _stockMode == 'shared'
                          ? 'Deduct Amount *'
                          : 'Unit Amount *',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _unitValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.qr_code_2_outlined),
              title: Text('Auto SKU: ${_generatedSku()}'),
              subtitle: const Text('Generated from product name and size'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            SwitchListTile(
              value: _isActive,
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to buyers'),
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sizes and Prices',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Add size',
                  onPressed: _addVariant,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_variants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No alternate sizes. Buyers will use the base price.'),
              )
            else
              ..._variants.map(
                (variant) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: variant.sizeController,
                                decoration: const InputDecoration(
                                  labelText: 'Size',
                                  hintText: 'Small, Medium, Large',
                                ),
                                validator: _requiredText,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove size',
                              onPressed: () => _removeVariant(variant),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: variant.priceController,
                                decoration: const InputDecoration(labelText: 'Price'),
                                keyboardType: TextInputType.number,
                                validator: _priceValidator,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _stockMode == 'shared'
                                  ? TextFormField(
                                      controller: variant.unitQuantityController,
                                      decoration: const InputDecoration(
                                        labelText: 'Deduct Amount',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: _unitValidator,
                                    )
                                  : TextFormField(
                                      controller: variant.stockController,
                                      decoration: const InputDecoration(
                                        labelText: 'Stock',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: _stockValidator,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Auto SKU: ${_generatedSku(variant.sizeController.text)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                        SwitchListTile(
                          value: variant.isActive,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Available'),
                          onChanged: (value) {
                            setState(() => variant.isActive = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _isSaving || _isUploading ? null : _save,
          icon: const Icon(Icons.save),
          label: Text(_isSaving ? 'Saving Product...' : 'Save Product'),
        ),
      ),
    );
  }
}

class _VariantDraft {
  _VariantDraft({
    required String size,
    required String price,
    required String stock,
    required String unitQuantity,
    this.isActive = true,
  })  : sizeController = TextEditingController(text: size),
        priceController = TextEditingController(text: price),
        stockController = TextEditingController(text: stock),
        unitQuantityController = TextEditingController(text: unitQuantity);

  final TextEditingController sizeController;
  final TextEditingController priceController;
  final TextEditingController stockController;
  final TextEditingController unitQuantityController;
  bool isActive;

  void dispose() {
    sizeController.dispose();
    priceController.dispose();
    stockController.dispose();
    unitQuantityController.dispose();
  }
}
