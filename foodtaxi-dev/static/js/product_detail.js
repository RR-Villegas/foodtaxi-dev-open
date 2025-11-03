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
const modalQuantity = document.getElementById("modalQuantity"); // if you have quantity input
const modalStock = document.getElementById("modalStock");


// Attach click event to each product
products.forEach((product) => {
  product.addEventListener("click", () => {
    // Grab data from product element
    modalImage.src = product.querySelector("img")?.src || "/static/images/placeholder.png";
    modalName.textContent = product.querySelector(".product-name").textContent;
    modalCategory.textContent = product.querySelector(".product-category").textContent;
    modalPrice.textContent = product.querySelector(".product-price").textContent;
    modalRating.textContent = product.querySelector(".product-rating").textContent;
    modalStock.textContent = "In Stock: " + (product.dataset.stock_quantity || "N/A"); 
  
  
    // Use dataset for hidden info
    modalDescription.textContent = product.dataset.description || "No description available";
    modalProductId.value = product.dataset.id;

    
  


    // Reset quantity if exists
    if (modalQuantity) modalQuantity.value = 1;

    // Show modal
    overlay.classList.add("active");
    overlay.style.display = "flex";
  });
});

// Close modal when clicking outside or on close button
overlay.addEventListener("click", (e) => {
  if (e.target === overlay || e.target === closeBtn) {
    overlay.classList.remove("active");
    overlay.style.display = "none";
  }
});
