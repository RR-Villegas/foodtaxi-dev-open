# Add Role Conditions for Sellers - TODO

## Plan
- [x] Create `require_seller` decorator: Check if logged in (401 if not), check if account_type == 'Seller' (403 if not).
- [x] Implement seller API routes: /api/seller/<seller_id>/sales, /api/seller/<seller_id>/products, /api/seller/<seller_id>/orders with decorator and seller_id match check.
- [x] Add check to /sellers_dashboard route: Redirect to login if not logged in, or to index with error if not seller.
