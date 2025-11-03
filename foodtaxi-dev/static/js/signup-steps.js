document.addEventListener("DOMContentLoaded", () => {
  // --- Multi-step form setup ---
  const steps = document.querySelectorAll(".form-step");
  const indicators = document.querySelectorAll(".step-indicator div");

  function showStep(step) {
    steps.forEach(s => s.classList.remove("active"));
    document.getElementById("step" + step).classList.add("active");
    updateIndicator(step);
  }

  function updateIndicator(step) {
    indicators.forEach((dot, i) => {
      dot.classList.toggle("active", i === step - 1);
    });
  }

  // Next & Back buttons
  document.querySelectorAll(".next-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const nextStep = btn.getAttribute("data-next");
      showStep(nextStep);
    });
  });

  document.querySelectorAll(".back-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const prevStep = btn.getAttribute("data-prev");
      showStep(prevStep);
    });
  });

  // Remove user type dynamic fields for now
  // const userType = document.getElementById("user_type");
  // const sellerFields = document.getElementById("sellerFields");
  // const riderFields = document.getElementById("riderFields");

  // userType.addEventListener("change", function () {
  //   sellerFields.style.display = this.value === "seller" ? "block" : "none";
  //   riderFields.style.display = this.value === "rider" ? "block" : "none";
  // });
});
