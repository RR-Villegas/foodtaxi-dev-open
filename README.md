# Food Taxi Mobile

Food Taxi Mobile is a Flutter + Supabase food ordering and delivery app with separate flows for buyers, sellers, riders, and admins.

The app supports marketplace ordering, seller product management, rider applications, admin approval workflows, reports, coupons, commissions, Terms & Conditions versioning, and basic marketplace moderation tools.

---

## Features

### Buyer
- Sign up and log in with Supabase Auth
- Manage delivery address
- Browse stores and products
- Add items to cart
- Checkout orders
- Apply discount coupons
- Track order status
- View order history
- Review products, stores, and riders
- Report stores or products

### Seller
- Register as seller through an application flow
- Upload business permit documents
- Wait for admin approval
- Manage store profile
- Manage products and product variants
- Upload product/store images
- Manage product discounts
- View seller orders
- Update order status
- View product and store reviews

### Rider
- Register as rider through an application flow
- Upload rider/license/vehicle documents
- Wait for admin approval
- View available delivery orders
- Accept delivery orders
- Enter pickup code
- Mark orders as in transit or delivered
- View delivery history
- Receive rider ratings

### Admin
- Dashboard overview
- View admin commission/gains
- Filter sales by day, week, month, year, or custom range
- Review seller applications
- Review rider applications
- Approve or reject applications
- Manage coupons
- View reports
- Review marketplace flags
- Run unfair market scan
- Warn, suspend, dismiss, hide products, or ban sellers
- Manage Terms & Conditions versions

---

## Tech Stack

- Flutter
- Dart
- Supabase Auth
- Supabase Database / PostgreSQL
- Supabase Storage
- Supabase Edge Functions
- Row Level Security policies
- Shared Preferences
- Image Picker
- File Picker
- Dropdown Search

---

## Project Structure

```txt
lib/
  models/
    application_data.dart
    address_model.dart
    picked_document.dart
    user_model.dart

  services/
    auth_service.dart
    database_service.dart
    input_validator.dart
    local_storage_service.dart
    location_service.dart
    theme_service.dart

  widgets/
    adaptive_menu_item.dart
    notification_bell.dart

  admin_dashboard.dart
  buyer_dashboard.dart
  seller_dashboard.dart
  rider_dashboard.dart
  login_page.dart
  signup_page.dart
  seller_registration_page.dart
  rider_registration_page.dart
  terms_page.dart