import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/database_service.dart';

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
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final List<_VariantDraft> _variants = [];

  String? _category;
  String? _imagePath;
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
    _skuController.text = product?['sku']?.toString() ?? '';
    _descriptionController.text = product?['description']?.toString() ?? '';
    _category = product?['category']?.toString();
    _imagePath = product?['main_image_url']?.toString();
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
    _skuController.dispose();
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
      _variants.add(_VariantDraft(size: '', price: _priceController.text, stock: '0'));
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
    final variants = _variants
        .where((variant) => variant.sizeController.text.trim().isNotEmpty)
        .map(
          (variant) => {
            'size_label': variant.sizeController.text.trim(),
            'price': double.parse(variant.priceController.text.trim()),
            'stock_quantity': int.parse(variant.stockController.text.trim()),
            'is_active': variant.isActive,
          },
        )
        .toList();

    final ok = _isEditing
        ? await DatabaseService.updateProduct(
            productId: widget.product!['product_id'].toString(),
            name: _nameController.text,
            category: _category,
            price: double.parse(_priceController.text.trim()),
            stockQuantity: int.parse(_stockController.text.trim()),
            sku: _skuController.text,
            mainImageUrl: _imagePath,
            description: _descriptionController.text,
            isActive: _isActive,
            variants: variants,
          )
        : await DatabaseService.insertProduct(
            storeId: widget.storeId,
            name: _nameController.text,
            category: _category,
            price: double.parse(_priceController.text.trim()),
            stockQuantity: int.parse(_stockController.text.trim()),
            sku: _skuController.text,
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
    return (value?.trim().isEmpty ?? true) ? 'Required' : null;
  }

  String? _priceValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 0 ? 'Enter a valid price' : null;
  }

  String? _stockValidator(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 0 ? 'Enter valid stock' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        backgroundColor: const Color(0xFF2d8f4e),
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
              validator: _requiredText,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: widget.categories
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => setState(() => _category = value),
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
                    decoration: const InputDecoration(labelText: 'Base Stock *'),
                    keyboardType: TextInputType.number,
                    validator: _stockValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(labelText: 'SKU'),
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
                              child: TextFormField(
                                controller: variant.stockController,
                                decoration: const InputDecoration(labelText: 'Stock'),
                                keyboardType: TextInputType.number,
                                validator: _stockValidator,
                              ),
                            ),
                          ],
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
    this.isActive = true,
  })  : sizeController = TextEditingController(text: size),
        priceController = TextEditingController(text: price),
        stockController = TextEditingController(text: stock);

  final TextEditingController sizeController;
  final TextEditingController priceController;
  final TextEditingController stockController;
  bool isActive;

  void dispose() {
    sizeController.dispose();
    priceController.dispose();
    stockController.dispose();
  }
}
