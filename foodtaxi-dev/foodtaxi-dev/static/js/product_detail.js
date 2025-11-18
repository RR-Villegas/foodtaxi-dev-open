// ===== Grab Elements =====
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
const modalQuantity = document.getElementById("modalQuantity");
const modalStock = document.getElementById("modalStock");
const reviewsList = document.getElementById("reviewsList");
const reviewForm = document.getElementById("reviewForm");
const starsContainer = document.getElementById("starRating");

// ===== Star Rating System =====
let selectedRating = 0;

// Create or reset 5 stars dynamically (★)
if (starsContainer) {
  // 🧹 Clear existing stars before adding new ones (prevents 10 stars)
  starsContainer.innerHTML = "";

  for (let i = 1; i <= 5; i++) {
    const star = document.createElement("span");
    star.classList.add("star");
    star.innerHTML = "★";
    star.dataset.value = i;

    // When clicked → set rating
    star.addEventListener("click", () => {
      selectedRating = i;
      updateStarDisplay();
    });

    // Hover effect
    star.addEventListener("mouseover", () => highlightStars(i));
    star.addEventListener("mouseleave", updateStarDisplay);

    // Add to container
    starsContainer.appendChild(star);
  }
}

function highlightStars(num) {
  const stars = starsContainer.querySelectorAll(".star");
  stars.forEach((star, index) => {
    star.classList.toggle("hovered", index < num);
  });
}

function updateStarDisplay() {
  const stars = starsContainer.querySelectorAll(".star");
  stars.forEach((star, index) => {
    star.classList.toggle("selected", index < selectedRating);
    star.classList.remove("hovered");
  });
}

// ===== Open Product Modal =====
products.forEach((product) => {
  product.addEventListener("click", () => {
    const productId = product.dataset.id;

    // Fill modal content
    modalImage.src = product.querySelector("img")?.src || "/static/images/placeholder.png";
    modalName.textContent = product.querySelector(".product-name").textContent;
    modalCategory.textContent = product.querySelector(".product-category").textContent;
    modalPrice.textContent = product.querySelector(".product-price").textContent;
    modalRating.textContent = product.querySelector(".product-rating").textContent;
    modalStock.textContent = "In Stock: " + (product.dataset.stock_quantity || "N/A");
    modalDescription.textContent = product.dataset.description || "No description available";
    modalProductId.value = productId;

    if (modalQuantity) modalQuantity.value = 1;

    // Show modal
    overlay.classList.add("active");
    overlay.style.display = "flex";

    // Load reviews after modal opens
    loadReviews(productId);
  });
});

// ===== Load Reviews =====
async function loadReviews(productId) {
  reviewsList.innerHTML = "<p>Loading reviews...</p>";
  try {
    const res = await fetch(`/buyer/product_reviews/${productId}`);
    const data = await res.json();

    if (!data.reviews.length) {
      reviewsList.innerHTML = "<p>No reviews yet.</p>";
      return;
    }

    reviewsList.innerHTML = data.reviews
      .map(
        (r) => `
      <div class="review">
        <div class="stars">${"★".repeat(r.rating)}${"☆".repeat(5 - r.rating)}</div>
        <p>${r.comment}</p>
        <small>by ${r.first_name} ${r.last_name} — ${new Date(r.created_at).toLocaleDateString()}</small>
      </div>
    `
      )
      .join("");
  } catch (err) {
    reviewsList.innerHTML = "<p>Failed to load reviews.</p>";
  }
}

// ===== Submit Review =====
reviewForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const productId = modalProductId.value;
  const comment = document.getElementById("reviewComment").value;

  if (!selectedRating) {
    alert("Please select a star rating first.");
    return;
  }

  const res = await fetch("/buyer/add_review", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ product_id: productId, rating: selectedRating, comment }),
  });

  const data = await res.json();
  if (data.success) {
    reviewForm.reset();
    selectedRating = 0;
    updateStarDisplay();
    loadReviews(productId);
  } else {
    alert(data.error || "Failed to submit review.");
  }
});

// ===== Close Modal =====
overlay.addEventListener("click", (e) => {
  if (e.target === overlay || e.target === closeBtn) {
    overlay.classList.remove("active");
    overlay.style.display = "none";
  }
});
