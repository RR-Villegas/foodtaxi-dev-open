# Scrapping Verification Code - TODO

## Backend Changes (app.py)
- [ ] Remove OTP-related imports and functions (generate_otp, send_otp_email, send_otp_sms)
- [ ] Remove OTP verification routes (/api/verify-otp, /api/resend-otp)
- [ ] Modify /api/register to set verification flags to True immediately
- [ ] Remove buyer_verification table insertions and updates
- [ ] Remove OTP fields from seller/rider application creation

## Frontend Changes (auth.js)
- [ ] Remove OTP step (step 4) from registration flow
- [ ] Remove OTP input fields and related functions
- [ ] Simplify registration to complete after account creation
- [ ] Update step navigation and validation logic

## Testing
- [ ] Test registration without OTP
- [ ] Test login functionality
- [ ] Verify seller/rider applications work without OTP
