# TODO: Update /become_seller and /seller_dashboard

## Pending Tasks
- [ ] Test the changes by running the app and checking seller_dashboard and become_seller

## Completed Tasks

- [x] Confirm plan with user
- [x] Add seller_id column to products table in database.sql
- [x] Add applications and seller_stores tables to database.sql
- [x] Update seller_dashboard route in app.py to fetch only seller's products using seller_id
- [x] Add email_status enum to accounts table
- [x] Update /become_seller to utilize SMTP for email verification
- [x] Add email verification route
- [x] Add verification_token column to accounts table
