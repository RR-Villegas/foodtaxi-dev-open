# FoodTaxi Omega

FoodTaxi Omega is a Flutter marketplace app for local food sellers, buyers, riders, and admins. It uses Supabase for authentication, Postgres data, storage, realtime updates, and edge functions.

## Current Features

- Buyer marketplace dashboard with category rows, trending products, product search, cart, checkout, delivery address handling, order history, reviews, and shop/product reports.
- Seller registration with location verification and document uploads, store management, product/variant management, seller coupons, order state controls, and seller dashboard analytics.
- Rider registration with location verification and document uploads, ready-for-pickup queue, pickup code scanning, in-transit flow, proof-of-delivery upload, and delivery history.
- Admin dashboard for seller/rider applications, review notes, reports, coupons, sales filtering, and Brevo-backed application email notifications.
- Per-account themes, including Default, Dark Mode, Koishi Komeiji, Satori Komeiji, Rin Kaenbyou, and Utsuho Reiuji.
- Supabase Realtime listeners for order, product, and notification refreshes in critical workflows.

## Backend

The app is connected to Supabase:

- Auth: email/password accounts mapped to `account` rows.
- Database: Postgres tables for accounts, stores, products, variants, orders, addresses, applications, notifications, coupons, reviews, reports, and click tracking.
- Storage: product images, profile images, application documents, and delivery proof images.
- Edge Functions: Brevo email delivery for application approval/rejection messages.
- RLS: enabled on public application tables, with role and ownership policies expected to enforce access.

## Setup

Install Flutter dependencies:

```bash
flutter pub get
```

Configure Supabase in `lib/main.dart` or your environment-specific config:

- Supabase URL
- Supabase anon key

Configure Brevo secrets in Supabase:

```txt
BREVO_API_KEY
BREVO_SENDER_EMAIL
BREVO_SENDER_NAME
```

Deploy the email function after changing it:

```bash
supabase functions deploy send-application-email
```

## Project Layout

```txt
lib/
  models/
  services/
  widgets/
  *_page.dart
supabase/
  functions/
  migrations/
```

## Development Notes

- Keep service-role keys out of Flutter/client code.
- Use Supabase RLS and ownership checks for any table exposed through the Data API.
- Product click records are retained for one week for trending calculations.
- Theme choices are saved per logged-in account and reset to Default on logout.

## Status

This project is under active development. Database policies, app flows, and UI polish are still being tightened as features are added.
