// static/javascript/auth.js

let currentRegisterStep = 1;
const registrationData = {};

document.addEventListener('DOMContentLoaded', function() {
    // Get modal elements
    const authModal = document.getElementById('auth-modal');
    const closeModalBtn = document.getElementById('close-modal');
    const switchFormBtns = document.querySelectorAll('.switch-form');
    const loginForm = document.getElementById('login-form');
    const registerForm = document.getElementById('register-form');
    const accountTypeSelect = document.getElementById('reg-account-type');
    const passwordToggles = document.querySelectorAll('.password-toggle');

    // Open modal from navbar login links
    const loginLinks = document.querySelectorAll('a[href*="login"]');
    loginLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            if (this.textContent.includes('Login') || this.textContent.includes('login')) {
                e.preventDefault();
                openAuthModal('login');
            }
        });
    });

    // Close modal
    closeModalBtn.addEventListener('click', closeAuthModal);
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') closeAuthModal();
    });

    // Form switching
    switchFormBtns.forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            const formName = this.getAttribute('data-form');
            switchForm(formName);
        });
    });

    // Password visibility toggle
    passwordToggles.forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            const input = this.parentElement.querySelector('input');
            if (input.type === 'password') {
                input.type = 'text';
                this.textContent = '🙈';
            } else {
                input.type = 'password';
                this.textContent = '👁️';
            }
        });
    });

    // Account type change - show/hide conditional docs
    accountTypeSelect.addEventListener('change', function() {
        document.getElementById('seller-docs').style.display = this.value === 'Seller' ? 'flex' : 'none';
        document.getElementById('rider-docs').style.display = this.value === 'Rider' ? 'flex' : 'none';
    });

    // Location cascade listeners
    document.getElementById('reg-region').addEventListener('change', loadProvinces);
    document.getElementById('reg-province').addEventListener('change', loadCitiesAndMunicipalities); // RENAMED FUNCTION
    document.getElementById('reg-city').addEventListener('change', function() { // ADDED LOGIC
        if (this.value) {
            document.getElementById('reg-municipality').value = ''; // Clear Municipality if City is selected
            document.getElementById('reg-municipality').disabled = true;
        } else {
            document.getElementById('reg-municipality').disabled = false;
        }
        loadBarangays();
        updateZipCodeFromMunicipality(); // Update zipcode when city changes
    });
    document.getElementById('reg-municipality').addEventListener('change', function() { // NEW LISTENER
        if (this.value) {
            document.getElementById('reg-city').value = ''; // Clear City if Municipality is selected
            document.getElementById('reg-city').disabled = true;
        } else {
            document.getElementById('reg-city').disabled = false;
        }
        loadBarangays();
        updateZipCodeFromMunicipality(); // Update zipcode when municipality changes
    });

    // Update zip code when barangay is selected
    document.getElementById('reg-barangay').addEventListener('change', updateZipCodeFromBarangay);

    // Login form submission
    loginForm.addEventListener('submit', function(e) {
        e.preventDefault();
        handleLogin();
    });

    // Register form submission (only triggers on final step)
    registerForm.addEventListener('submit', function(e) {
        e.preventDefault();
        handleRegisterSubmit();
    });

    // Initialize region data
    loadPhilippineRegions();
});

// --- MODAL FUNCTIONS ---
function openAuthModal(form = 'login') {
    const modal = document.getElementById('auth-modal');
    modal.classList.add('active');
    switchForm(form);
}

function closeAuthModal() {
    const modal = document.getElementById('auth-modal');
    modal.classList.remove('active');
}

function switchForm(formName) {
    // Hide all form containers
    document.querySelectorAll('.auth-form-container').forEach(container => {
        container.classList.remove('active');
    });

    // Show selected form
    const formContainer = document.getElementById(`${formName}-form-container`);
    if (formContainer) {
        formContainer.classList.add('active');
    }

    // Reset register step when switching to register
    if (formName === 'register') {
        currentRegisterStep = 1;
        showRegisterStep(1);
    }
}

// --- LOGIN FUNCTIONS ---
async function handleLogin() {
    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;

    try {
        const response = await fetch('/api/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ email, password })
        });

        const data = await response.json();

        if (response.ok) {
            showMessage('Login successful! Redirecting...', 'success');
            setTimeout(() => {
                window.location.href = '/';
            }, 1200);
        } else {
            showMessage(data.message || 'Login failed', 'error');
        }
    } catch (error) {
        console.error('Login error:', error);
        showMessage('An error occurred. Please try again.', 'error');
    }
}

// --- REGISTER FUNCTIONS ---
function registerNextStep() {
    if (validateCurrentStep()) {
        saveStepData();

        const accountType = document.getElementById('reg-account-type').value;

        // Check if this is the final step (step 2 for Buyers, step 3 for Sellers/Riders)
        const isFinalStep = (accountType === 'Buyer' && currentRegisterStep === 2) || (accountType !== 'Buyer' && currentRegisterStep === 3);

        if (isFinalStep) {
            // Submit registration directly
            handleRegisterSubmit();
        } else {
            // Normal step navigation
            currentRegisterStep++;
            showRegisterStep(currentRegisterStep);
        }
    }
}

function registerPrevStep() {
    currentRegisterStep--;
    
    // Skip step 3 for Buyer accounts when going back
    const accountType = document.getElementById('reg-account-type').value;
    if (currentRegisterStep === 3 && accountType === 'Buyer') {
        currentRegisterStep = 2;
    }
    
    showRegisterStep(currentRegisterStep);
}

function showRegisterStep(step) {
    // Hide all steps
    for (let i = 1; i <= 4; i++) {
        const stepEl = document.getElementById(`register-step-${i}`);
        if (stepEl) stepEl.classList.remove('active');
    }

    // Show current step
    const currentStepEl = document.getElementById(`register-step-${step}`);
    if (currentStepEl) currentStepEl.classList.add('active');

    // Scroll to top
    document.querySelector('.auth-modal').scrollTop = 0;
}

function validateCurrentStep() {
    const step = currentRegisterStep;

    if (step === 1) {
        const firstname = document.getElementById('reg-firstname').value;
        const surname = document.getElementById('reg-surname').value;
        const email = document.getElementById('reg-email').value;
        const phone = document.getElementById('reg-phone').value;
        const password = document.getElementById('reg-password').value;
        const confirmPassword = document.getElementById('reg-confirm-password').value;
        const accountType = document.getElementById('reg-account-type').value;

        if (!firstname || !surname || !email || !phone || !password || !confirmPassword || !accountType) {
            showMessage('Please fill in all required fields', 'error');
            return false;
        }

        if (password !== confirmPassword) {
            showMessage('Passwords do not match', 'error');
            return false;
        }

        if (password.length < 8) {
            showMessage('Password must be at least 8 characters', 'error');
            return false;
        }

        return true;
    }

    if (step === 2) {
        const homeAddress = document.getElementById('reg-home').value;
        const streetAddress = document.getElementById('reg-address').value;
        const region = document.getElementById('reg-region').value;
        const province = document.getElementById('reg-province').value;
        const city = document.getElementById('reg-city').value; // NEW
        const municipality = document.getElementById('reg-municipality').value; // NEW
        const barangay = document.getElementById('reg-barangay').value;
        const zip = document.getElementById('reg-zip').value;

        if (!homeAddress || !streetAddress || !region || !province || !barangay || !zip) {
            showMessage('Please fill in all required address fields (Home Address, Street Address, Region, Province, Barangay, Zip)', 'error');
            return false;
        }

        // Check the mutual exclusivity: exactly one of City or Municipality must be selected
        if (!city && !municipality) {
             showMessage('Please select either a City or a Municipality', 'error');
             return false;
        }
        
        // This validation is implicitly handled by the disabling logic in the listeners, 
        // but it's good practice to ensure both aren't simultaneously chosen.
        if (city && municipality) {
             showMessage('Please select only a City OR a Municipality, not both.', 'error');
             return false;
        }

        return true;
    }

    if (step === 3) {
        const accountType = document.getElementById('reg-account-type').value;

        // Buyers skip step 3, so this should never be reached for them
        if (accountType === 'Buyer') {
            return true;
        }

        if (accountType === 'Seller') {
            const businessName = document.getElementById('reg-business-name').value;
            const docs = document.getElementById('reg-seller-docs').files;

            if (!businessName || docs.length === 0) {
                showMessage('Please provide business name and upload documents', 'error');
                return false;
            }
        }

        if (accountType === 'Rider') {
            const licenseNumber = document.getElementById('reg-license-number').value;
            const vehicleType = document.getElementById('reg-vehicle-type').value;
            const plateNumber = document.getElementById('reg-plate-number').value;
            const docs = document.getElementById('reg-rider-docs').files;

            if (!licenseNumber || !vehicleType || !plateNumber || docs.length === 0) {
                showMessage('Please fill in all rider information and upload documents', 'error');
                return false;
            }
        }

        return true;
    }



    return true;
}

function saveStepData() {
    const step = currentRegisterStep;

    if (step === 1) {
        registrationData.firstname = document.getElementById('reg-firstname').value;
        registrationData.surname = document.getElementById('reg-surname').value;
        registrationData.email = document.getElementById('reg-email').value;
        registrationData.phone_number = document.getElementById('reg-phone').value;
        registrationData.password = document.getElementById('reg-password').value;
        registrationData.account_type = document.getElementById('reg-account-type').value;
    }

    if (step === 2) {
        registrationData.home_address = document.getElementById('reg-home').value;
        registrationData.street_address = document.getElementById('reg-address').value;
        registrationData.region = document.getElementById('reg-region').value;
        registrationData.province = document.getElementById('reg-province').value;

        // Save the chosen value, ensuring only one is present
        registrationData.city = document.getElementById('reg-city').value;
        registrationData.municipality = document.getElementById('reg-municipality').value;

        registrationData.barangay = document.getElementById('reg-barangay').value;
        registrationData.zip_code = document.getElementById('reg-zip').value;

        // Clean up the data object before sending, so the backend only receives one field (e.g., city_or_municipality)
        if (!registrationData.city) {
            registrationData.city_or_municipality = registrationData.municipality;
            delete registrationData.municipality;
            delete registrationData.city;
        } else {
            registrationData.city_or_municipality = registrationData.city;
            delete registrationData.municipality;
            delete registrationData.city;
        }
    }

    if (step === 3) {
        if (registrationData.account_type === 'Seller') {
            registrationData.business_name = document.getElementById('reg-business-name').value;
            registrationData.dti_registration_number = document.getElementById('reg-dti-number').value;
            registrationData.seller_documents = document.getElementById('reg-seller-docs').files;
        }

        if (registrationData.account_type === 'Rider') {
            registrationData.license_number = document.getElementById('reg-license-number').value;
            registrationData.vehicle_type = document.getElementById('reg-vehicle-type').value;
            registrationData.plate_number = document.getElementById('reg-plate-number').value;
            registrationData.rider_documents = document.getElementById('reg-rider-docs').files;
        }
    }
}

async function handleRegisterSubmit() {
    try {
        // Submit registration data directly
        const response = await fetch('/api/register', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(registrationData)
        });

        const data = await response.json();

        if (response.ok) {
            showMessage('Registration successful! Welcome to FoodTaxi Omega!', 'success');
            setTimeout(() => {
                closeAuthModal();
                window.location.reload();
            }, 2000);
        } else {
            showMessage(data.message || 'Registration failed', 'error');
        }
    } catch (error) {
        console.error('Registration error:', error);
        showMessage('An error occurred. Please try again.', 'error');
    }
}



// --- PHILIPPINES REGIONS/PROVINCES/CITIES/BARANGAYS ---
async function loadPhilippineRegions() {
    try {
        console.log('Loading Philippine regions...');
        const response = await fetch('https://psgc.gitlab.io/api/regions/');
        const regions = await response.json();

        const regionSelect = document.getElementById('reg-region');
        regionSelect.innerHTML = '<option value="">Select region</option>';

        regions.forEach(region => {
            const option = document.createElement('option');
            // Store the code as value, display name as text
            option.value = region.code;
            option.textContent = region.name;
            regionSelect.appendChild(option);
        });

        console.log('Regions loaded:', regions.length);
    } catch (error) {
        console.error('Error loading regions:', error);
    }
}

async function loadProvinces() {
    const regionCode = document.getElementById('reg-region').value;
    const provinceSelect = document.getElementById('reg-province');
    const citySelect = document.getElementById('reg-city');
    const barangaySelect = document.getElementById('reg-barangay');
    
    console.log('loadProvinces called - regionCode:', regionCode);
    
    // Reset dependent dropdowns
    citySelect.innerHTML = '<option value="">Select city</option>';
    barangaySelect.innerHTML = '<option value="">Select barangay</option>';
    
    if (!regionCode) {
        provinceSelect.innerHTML = '<option value="">Select province</option>';
        return;
    }

    try {
        console.log(`Fetching: https://psgc.gitlab.io/api/regions/${regionCode}/provinces/`);
        const response = await fetch(`https://psgc.gitlab.io/api/regions/${regionCode}/provinces/`);
        const provinces = await response.json();

        provinceSelect.innerHTML = '<option value="">Select province</option>';

        provinces.forEach(province => {
            const option = document.createElement('option');
            // Store the code as value, display name as text
            option.value = province.code;
            option.textContent = province.name;
            provinceSelect.appendChild(option);
        });

        console.log('Provinces loaded:', provinces.length);
    } catch (error) {
        console.error('Error loading provinces:', error);
    }
}

async function loadCitiesAndMunicipalities() { // RENAMED from loadCities
    const provinceCode = document.getElementById('reg-province').value;
    const citySelect = document.getElementById('reg-city');
    const municipalitySelect = document.getElementById('reg-municipality'); // NEW
    const barangaySelect = document.getElementById('reg-barangay');

    console.log('loadCitiesAndMunicipalities called - provinceCode:', provinceCode);

    // Reset dependent dropdowns and enable inputs
    barangaySelect.innerHTML = '<option value="">Select barangay</option>';
    citySelect.disabled = false;
    municipalitySelect.disabled = false;

    if (!provinceCode) {
        console.log('Missing provinceCode, resetting city/municipality dropdowns');
        citySelect.innerHTML = '<option value="">Select city</option>';
        municipalitySelect.innerHTML = '<option value="">Select municipality</option>';
        return;
    }

    try {
        const url = `https://psgc.gitlab.io/api/provinces/${provinceCode}/cities-municipalities/`; // Use combined endpoint
        console.log(`Fetching: ${url}`);
        const response = await fetch(url);

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const citiesAndMunicipalities = await response.json();

        citySelect.innerHTML = '<option value="">Select city</option>';
        municipalitySelect.innerHTML = '<option value="">Select municipality</option>';

        citiesAndMunicipalities.forEach(item => {
            const option = document.createElement('option');
            option.value = item.code;
            option.textContent = item.name;

            // PSGC types: 'City' or 'Municipality'
            if (item.isCity) { // Use 'isCity' property if available, or check against name/type
                citySelect.appendChild(option);
            } else {
                municipalitySelect.appendChild(option);
            }
        });

        console.log('Cities & Municipalities loaded:', citiesAndMunicipalities.length);
    } catch (error) {
        console.error('Error loading cities/municipalities:', error);
        citySelect.innerHTML = '<option value="">Error loading cities</option>';
        municipalitySelect.innerHTML = '<option value="">Error loading municipalities</option>';
    }
}

async function loadBarangays() {
    // Determine the active code (City or Municipality)
    const cityCode = document.getElementById('reg-city').value;
    const municipalityCode = document.getElementById('reg-municipality').value; // NEW
    const parentCode = cityCode || municipalityCode; // Use whichever is selected

    const barangaySelect = document.getElementById('reg-barangay');

    console.log('loadBarangays called - parentCode:', parentCode);

    if (!parentCode) {
        barangaySelect.innerHTML = '<option value="">Select barangay</option>';
        document.getElementById('reg-zip').value = ''; // Clear zip code
        return;
    }

    try {
        const url = `https://psgc.gitlab.io/api/cities-municipalities/${parentCode}/barangays/`; // Use the dedicated endpoint
        console.log(`Fetching: ${url}`);
        const response = await fetch(url);
        
        if (!response.ok) {
             throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const barangays = await response.json();

        barangaySelect.innerHTML = '<option value="">Select barangay</option>';

        barangays.forEach(barangay => {
            const option = document.createElement('option');
            // Store the code as value, display name as text
            option.value = barangay.code;
            option.textContent = barangay.name;
            // Store postal code as data attribute
            if (barangay.postalCode) {
                option.dataset.postalCode = barangay.postalCode;
            }
            barangaySelect.appendChild(option);
        });

        console.log('Barangays loaded:', barangays.length);
    } catch (error) {
        console.error('Error loading barangays:', error);
        barangaySelect.innerHTML = '<option value="">Error loading barangays</option>';
    }
}

function updateZipCodeFromBarangay() {
    const barangaySelect = document.getElementById('reg-barangay');
    const municipalitySelect = document.getElementById('reg-municipality');
    const citySelect = document.getElementById('reg-city');
    const zipCodeInput = document.getElementById('reg-zip');
    
    // --- 1. Determine City or Municipality Name ---
    let municipalityName = '';
    if (citySelect.value) {
        municipalityName = citySelect.options[citySelect.selectedIndex].textContent;
    } else if (municipalitySelect.value) {
        municipalityName = municipalitySelect.options[municipalitySelect.selectedIndex].textContent;
    }
    
    // Clear zipcode if no municipality selected
    if (!municipalityName) {
        zipCodeInput.value = '';
        console.log('No municipality selected, clearing zip code');
        return;
    }
    
    // --- 2. Attempt use-postal-ph Library Lookup ---
    if (typeof window.usePostalPH !== 'undefined') {
        try {
            console.log(`Attempting use-postal-ph lookup for: ${municipalityName}`);
            const postalPH = window.usePostalPH();
            const results = postalPH.fetchDataLists({
                municipality: municipalityName,
                limit: 1
            });
            
            if (results && results.data && results.data.length > 0 && results.data[0].post_code) {
                zipCodeInput.value = results.data[0].post_code;
                console.log(`Zip Code set by Library: ${results.data[0].post_code}`);
                return;
            }
        } catch (error) {
            console.error('Error with use-postal-ph lookup:', error);
        }
    }
    
    // --- 3. Attempt Data Attribute Lookup (Barangay change fallback) ---
    const selectedOption = barangaySelect.options[barangaySelect.selectedIndex];
    
    if (selectedOption && selectedOption.dataset.postalCode) {
        zipCodeInput.value = selectedOption.dataset.postalCode;
        console.log(`Zip Code set by Barangay Data: ${selectedOption.dataset.postalCode}`);
        return;
    }
    
    // --- 4. Fallback: If neither method works, clear the field ---
    console.log('Zip Code not found, clearing field.');
    zipCodeInput.value = '';
}

// --- UTILITY FUNCTIONS ---
function showMessage(message, type) {
    // Create a temporary message element or use browser alert
    console.log(`[${type.toUpperCase()}] ${message}`);
    alert(message); // Simple implementation; replace with toast/notification system later
}
