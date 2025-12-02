// cart.js - Corrected JavaScript

/**
 * Opens the checkout modal by setting its display property to 'flex'.
 */
function openCheckoutModal() {
    const modal = document.getElementById('checkoutModal');
    // Check if the element exists before trying to modify its style
    if (modal) {
        modal.style.display = 'flex';
    }
}

/**
 * Toggles the visibility of payment details based on the selected method.
 * @param {string} method - 'cod' or 'gcash'
 */
function togglePaymentDetails(method) {
    const gcashDetails = document.getElementById('gcashDetails');
    const codDetails = document.getElementById('codDetails');

    // Ensure both payment detail containers exist
    if (gcashDetails && codDetails) {
        if (method === 'gcash') {
            gcashDetails.style.display = 'block';
            codDetails.style.display = 'none';
        } else { // 'cod'
            gcashDetails.style.display = 'none';
            codDetails.style.display = 'block';
        }
    }
}

// Set the initial state when the script loads (COD selected by default)
// This must run for the Cash on Delivery confirmation box to be visible initially.
togglePaymentDetails('cod');