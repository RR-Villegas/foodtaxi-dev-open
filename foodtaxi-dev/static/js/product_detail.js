// Grab elements
const products = document.querySelectorAll(".product");
const overlay = document.getElementById("productOverlay");
const modal = document.getElementById("productModal");
const modalImage = document.getElementById("modalImage");
const modalName = document.getElementById("modalName");
const modalCategory = document.getElementById("modalCategory");
const modalPrice = document.getElementById("modalPrice");
const modalDescription = document.getElementById("modalDescription");
const closeBtn = document.querySelector(".close-btn");
const modalRating = document.getElementById("modalRating");
const modalProductId = document.getElementById("modalProductId");

// Attach click event to each product
products.forEach((product) => {
  product.addEventListener("click", () => {
    // Grab data from product element
    const img = product.querySelector("img").src;
    const name = product.querySelector(".product-name").textContent;
    const category = product.querySelector(".product-category").textContent;
    const price = product.querySelector(".product-price").textContent;
    const rating = product.querySelector(".product-rating").textContent;
    const productId = product.dataset.id; // Make sure each product has data-id="{{ product.id }}"

    // Fill modal
    modalImage.src = img;
    modalName.textContent = name;
    modalCategory.textContent = category;
    modalPrice.textContent = price;
    modalRating.textContent = rating;
    modalDescription.textContent = "This is a placeholder description for now."; // Replace later if needed

    // Set product_id in hidden form field
    modalProductId.value = productId;

    // Show modal
    overlay.classList.add("active");
  });
});

// Close modal when clicking outside or on close button
overlay.addEventListener("click", (e) => {
  if (e.target === overlay || e.target === closeBtn) {
    overlay.classList.remove("active");
  }
});

document.querySelectorAll(".product").forEach((product) => {
  product.addEventListener("click", () => {
    const overlay = document.getElementById("productOverlay");
    overlay.style.display = "flex";
  });
});
