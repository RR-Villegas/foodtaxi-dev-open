# FoodTaxi

FoodTaxi is a Flutter-based food delivery platform with role-based accounts for Buyers, Sellers, Riders, and Admins.

The project uses Supabase as its backend service for:
- Authentication
- PostgreSQL database
- Storage
- Edge Functions
- Row Level Security (RLS)

## Features

### Authentication
- Email/password signup and login
- Role-based accounts
- Session persistence
- Input validation and sanitization

### Buyer Features
- Browse stores and products
- Place orders
- Track deliveries

### Seller Features
- Seller registration workflow
- Store management
- Product management
- Order handling

### Rider Features
- Rider registration workflow
- Delivery management
- Delivery status tracking

### Admin Features
- Application approval system
- Account verification
- Email notifications using Brevo + Supabase Edge Functions

## Tech Stack

### Frontend
- Flutter
- Dart

### Backend
- Supabase
- PostgreSQL
- Supabase Edge Functions
- Brevo Email API

## Project Structure

```txt
lib/
├── models/
├── services/
├── utils/
├── widgets/
└── pages/

supabase/
├── functions/
├── migrations/
└── config.toml
```

## Setup

### Requirements
- Flutter SDK
- Dart SDK
- Node.js
- Supabase CLI
- VS Code with Deno extension (for Edge Functions)

### Install Dependencies

```bash
flutter pub get
```

### Configure Supabase

Create a `.env` or configure constants with:
- Supabase URL
- Supabase anon key

### Edge Function Secrets

Configure these in Supabase Dashboard:

```txt
BREVO_API_KEY
BREVO_SENDER_EMAIL
BREVO_SENDER_NAME
```

### Deploy Edge Functions

```bash
supabase functions deploy send-application-email
```

## Development Notes

### Git Ignore

Recommended `.gitignore` entries:

```gitignore
.supabase
node_modules
.env
.env.local
```

### Deno Support

For Supabase Edge Functions, enable Deno in VS Code:

```json
{
  "deno.enable": true,
  "deno.enablePaths": ["supabase/functions"]
}
```

## Current Status

This project is currently under active development.
Features and database schema may still change.

## License

This project is for educational and development purposes.