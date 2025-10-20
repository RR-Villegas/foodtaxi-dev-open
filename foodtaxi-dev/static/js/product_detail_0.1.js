document.addEventListener("DOMContentLoaded", function () {
  console.log("✅ product_detail_0.1.js is loaded");

  const overlay = document.getElementById("productOverlay");
  const modal = document.getElementById("productModal");
  const closeBtn = document.querySelector(".close-btn");

  const modalImage = document.getElementById("modalImage");
  const modalName = document.getElementById("modalName");
  const modalCategory = document.getElementById("modalCategory");
  const modalPrice = document.getElementById("modalPrice");
  const modalRating = document.getElementById("modalRating");
  const modalDescription = document.getElementById("modalDescription");

  const products = document.querySelectorAll(".product");

  if (!overlay || !products.length) {
    console.error("❌ Overlay or product elements not found!");
    return;
  }

  // Open modal when clicking a product
  products.forEach((product) => {
    product.addEventListener("click", () => {
      const img = product.querySelector("img")?.src || "";
      const name = product.querySelector(".product-name")?.innerText || "";
      const category =
        product.querySelector(".product-category")?.innerText || "";
      const price = product.querySelector(".product-price")?.innerText || "";
      const rating =
        product.querySelector(".product-rating")?.innerText || "★★★★☆";

      modalImage.src = img;
      modalName.textContent = name;
      modalCategory.textContent = category;
      modalPrice.textContent = price;
      modalRating.textContent = rating;
      modalDescription.textContent = `Learn more about ${name}!`;

      overlay.classList.add("active");
      console.log("🟢 Modal opened for:", name);
    });
  });

  // Close modal (close button)
  closeBtn?.addEventListener("click", () => {
    overlay.classList.remove("active");
  });

  // Close when clicking outside modal
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) {
      overlay.classList.remove("active");
    }
  });
});
