import 'package:flutter/material.dart';

import '../services/database_service.dart';

enum ProductCardLayout { tile, list }

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAction,
    this.actionLabel = 'View item',
    this.layout = ProductCardLayout.tile,
    this.storeName,
    this.onStoreTap,
    this.showStock = false,
  });

  final Map<String, dynamic> product;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final String actionLabel;
  final ProductCardLayout layout;
  final String? storeName;
  final VoidCallback? onStoreTap;
  final bool showStock;

  static const _fallbackImage = 'assets/images/burger.jpg';

  int get _stock =>
      int.tryParse(product['stock_quantity']?.toString() ?? '') ?? 0;

  double get _rating {
    final value = product['average_rating'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get _reviewCount {
    final value = product['review_count'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return layout == ProductCardLayout.list
        ? _buildListCard(context)
        : _buildTileCard(context);
  }

  Widget _buildTileCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.45,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _productImage(product['main_image_url']),
                  if (showStock && _stock <= 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _badge(
                        'Sold out',
                        scheme.errorContainer,
                        scheme.onErrorContainer,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          DatabaseService.displayProductName(product['name']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(height: 36, child: _price(context)),
                    const SizedBox(height: 2),
                    SizedBox(height: 20, child: _ratingRow(context)),
                    const Spacer(),
                    SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onAction ?? onTap,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          actionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    return SizedBox(
      height: 124,
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 98,
                    height: 98,
                    child: _productImage(product['main_image_url']),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 21,
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            DatabaseService.displayProductName(product['name']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 18,
                        child: InkWell(
                          onTap: onStoreTap,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              storeName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 18,
                        child: _ratingRow(context, compact: true),
                      ),
                      const Spacer(),
                      SizedBox(height: 36, child: _price(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _productImage(dynamic value) {
    final path = value?.toString().trim() ?? '';
    if (path.isEmpty) {
      return Image.asset(_fallbackImage, fit: BoxFit.cover);
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        cacheWidth: 420,
        cacheHeight: 420,
        errorBuilder: (_, _, _) =>
            Image.asset(_fallbackImage, fit: BoxFit.cover),
      );
    }

    final url = path.startsWith('http')
        ? path
        : DatabaseService.getProductImageUrl(path);
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 420,
      cacheHeight: 420,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => Image.asset(_fallbackImage, fit: BoxFit.cover),
    );
  }

  Widget _price(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final discount = DatabaseService.activeProductDiscount(product);
    final optionCount = DatabaseService.productOptionCount(product);
    final discountLabel = discount == null
        ? null
        : discount['discount_type']?.toString() == 'amount'
        ? '-${DatabaseService.money(discount['discount_value'])}'
        : '-${discount['discount_value']}%';
    final details = <String>[
      if (optionCount > 1) '$optionCount options',
      ?discountLabel,
      if (showStock && _stock > 0) '$_stock left',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DatabaseService.displayProductPriceRange(product),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: discount == null ? scheme.primary : scheme.tertiary,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          details,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: discountLabel == null
                ? scheme.onSurfaceVariant
                : scheme.secondary,
            fontSize: 10,
            fontWeight: discountLabel == null
                ? FontWeight.normal
                : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _ratingRow(BuildContext context, {bool compact = false}) {
    final count = _reviewCount;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        ...List.generate(5, (index) {
          final filled = _rating >= index + 1;
          final half = !filled && _rating > index && _rating < index + 1;
          return Icon(
            filled
                ? Icons.star
                : half
                ? Icons.star_half
                : Icons.star_border,
            size: compact ? 12 : 14,
            color: Colors.amber,
          );
        }),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            count == 0 ? 'New' : '($count)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color background, Color foreground) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
