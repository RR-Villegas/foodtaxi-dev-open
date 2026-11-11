import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_taxi/widgets/product_card.dart';

void main() {
  const product = <String, dynamic>{
    'product_id': 'product-1',
    'name':
        'An exceptionally long product name that should never push the price or button out of alignment',
    'price': 123.45,
    'stock_quantity': 3,
    'average_rating': 4.5,
    'review_count': 123,
  };

  testWidgets('tile card truncates long titles and keeps action aligned', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(174, 294));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 174,
            height: 294,
            child: ProductCard(
              product: product,
              onTap: () {},
              onAction: () {},
              actionLabel: 'A very long action label that must be truncated',
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(
      find.text(
        'An exceptionally long product name that should never push the price or button out of alignment',
      ),
    );
    final action = tester.widget<Text>(
      find.text('A very long action label that must be truncated'),
    );

    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(action.maxLines, 1);
    expect(action.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('list card bounds long product and seller names', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 124));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCard(
            product: product,
            layout: ProductCardLayout.list,
            storeName:
                'An exceptionally long seller name that should remain on one line',
            onTap: () {},
            onStoreTap: () {},
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<Text>(
            find.text(
              'An exceptionally long product name that should never push the price or button out of alignment',
            ),
          )
          .maxLines,
      1,
    );
    expect(
      tester
          .widget<Text>(
            find.text(
              'An exceptionally long seller name that should remain on one line',
            ),
          )
          .maxLines,
      1,
    );
    final titleTop = tester
        .getTopLeft(
          find.text(
            'An exceptionally long product name that should never push the price or button out of alignment',
          ),
        )
        .dy;
    final storeTop = tester
        .getTopLeft(
          find.text(
            'An exceptionally long seller name that should remain on one line',
          ),
        )
        .dy;
    final ratingTop = tester.getTopLeft(find.text('(123)')).dy;
    expect(titleTop, lessThan(storeTop));
    expect(storeTop, lessThan(ratingTop));
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('card shows the price range and number of product options', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(174, 294));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 174,
            height: 294,
            child: ProductCard(
              product: {
                ...product,
                'product_variant': [
                  {'price': 180.0, 'is_active': true},
                  {'price': 210.0, 'is_active': true},
                  {'price': 250.0, 'is_active': false},
                ],
              },
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('PHP 123.45–210.00'), findsOneWidget);
    expect(find.text('3 options'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
