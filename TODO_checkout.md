# Checkout Implementation Plan

## Steps Completed:
- [x] 1. Create checkout_page.dart - Full checkout flow with address selection, payment methods, order summary
- [x] 2. Update database_service.dart - Add insertOrder(), insertOrderItem() methods
- [x] 3. Update cart_page.dart - Navigate to checkout page
- [x] 4. Update main.dart - Register /checkout route

## Files to Edit:
1. Create: `lib/checkout_page.dart`
2. Edit: `lib/services/database_service.dart`
3. Edit: `lib/cart_page.dart`
4. Edit: `lib/main.dart`

## Features:
- Order Summary with items, quantities, prices in ₱
- Delivery Address Selection (from saved addresses)
- Payment Method Selection (COD, GCash, Card)
- Order Total Calculation (subtotal + ₱50 delivery fee)
- Order Confirmation Dialog
- Success navigation and cart clearing
