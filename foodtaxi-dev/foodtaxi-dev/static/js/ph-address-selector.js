document.addEventListener("DOMContentLoaded", () => {
  const regionSelect = document.getElementById("region");
  const provinceSelect = document.getElementById("province");
  const citySelect = document.getElementById("city");
  const barangaySelect = document.getElementById("barangay");

  const regionText = document.getElementById("region-text");
  const provinceText = document.getElementById("province-text");
  const cityText = document.getElementById("city-text");
  const barangayText = document.getElementById("barangay-text");

  // --- Load Regions ---
  async function loadRegions() {
    try {
      const res = await fetch("https://psgc.gitlab.io/api/regions/");
      const data = await res.json();
      regionSelect.innerHTML = '<option value="">Select Region</option>';
      data.forEach(r => {
        const option = document.createElement("option");
        option.value = r.code;
        option.textContent = r.name;
        regionSelect.appendChild(option);
      });
    } catch (err) {
      console.error("Error loading regions:", err);
    }
  }

  // --- Load Provinces ---
  async function loadProvinces(regionCode) {
    try {
      const res = await fetch(`https://psgc.gitlab.io/api/regions/${regionCode}/provinces/`);
      const data = await res.json();
      provinceSelect.innerHTML = '<option value="">Select Province</option>';
      data.forEach(p => {
        const option = document.createElement("option");
        option.value = p.code;
        option.textContent = p.name;
        provinceSelect.appendChild(option);
      });
      citySelect.innerHTML = '<option value="">Select City</option>';
      barangaySelect.innerHTML = '<option value="">Select Barangay</option>';
    } catch (err) {
      console.error("Error loading provinces:", err);
    }
  }

  // --- Load Cities ---
  async function loadCities(provinceCode) {
    try {
      const res = await fetch(`https://psgc.gitlab.io/api/provinces/${provinceCode}/cities-municipalities/`);
      const data = await res.json();
      citySelect.innerHTML = '<option value="">Select City/Municipality</option>';
      data.forEach(c => {
        const option = document.createElement("option");
        option.value = c.code;
        option.textContent = c.name;
        citySelect.appendChild(option);
      });
      barangaySelect.innerHTML = '<option value="">Select Barangay</option>';
    } catch (err) {
      console.error("Error loading cities:", err);
    }
  }

  // --- Load Barangays ---
  async function loadBarangays(cityCode) {
    try {
      const res = await fetch(`https://psgc.gitlab.io/api/cities-municipalities/${cityCode}/barangays/`);
      const data = await res.json();
      barangaySelect.innerHTML = '<option value="">Select Barangay</option>';
      data.forEach(b => {
        const option = document.createElement("option");
        option.value = b.code;
        option.textContent = b.name;
        barangaySelect.appendChild(option);
      });
    } catch (err) {
      console.error("Error loading barangays:", err);
    }
  }

  // --- Update hidden inputs on select change ---
  regionSelect.addEventListener("change", () => {
    regionText.value = regionSelect.selectedOptions[0]?.text || "";
    if (regionSelect.value) loadProvinces(regionSelect.value);
  });

  provinceSelect.addEventListener("change", () => {
    provinceText.value = provinceSelect.selectedOptions[0]?.text || "";
    if (provinceSelect.value) loadCities(provinceSelect.value);
  });

  citySelect.addEventListener("change", () => {
    cityText.value = citySelect.selectedOptions[0]?.text || "";
    if (citySelect.value) loadBarangays(citySelect.value);
  });

  barangaySelect.addEventListener("change", () => {
    barangayText.value = barangaySelect.selectedOptions[0]?.text || "";
  });

  // --- IMPORTANT: Sync hidden inputs right before form submit ---
  const form = document.querySelector("form");
  if (form) {
    form.addEventListener("submit", () => {
      regionText.value = regionSelect.selectedOptions[0]?.text || "";
      provinceText.value = provinceSelect.selectedOptions[0]?.text || "";
      cityText.value = citySelect.selectedOptions[0]?.text || "";
      barangayText.value = barangaySelect.selectedOptions[0]?.text || "";
    });
  }

  // --- Initialize ---
  loadRegions();
});
