document.addEventListener("DOMContentLoaded", () => {
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

  // --- Step Validation ---
  function validateStep(step) {
    const currentStep = document.getElementById("step" + step);
    const inputs = currentStep.querySelectorAll("input, select");
    let valid = true;

    inputs.forEach(input => {
      if (input.hasAttribute("required") && !input.value.trim()) {
        valid = false;
        input.classList.add("invalid");
      } else {
        input.classList.remove("invalid");
      }

      // Additional custom validation for step 1
      if (step === 1) {
        const password = document.getElementById("password").value;
        const confirm = document.getElementById("confirm_password").value;

        if (password.length < 8) {
          valid = false;
          document.getElementById("password").classList.add("invalid");
        }

        if (password !== confirm) {
          valid = false;
          document.getElementById("confirm_password").classList.add("invalid");
        }

        const email = currentStep.querySelector('input[type="email"]');
        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailPattern.test(email.value)) {
          valid = false;
          email.classList.add("invalid");
        }
      }
    });

    return valid;
  }

  // --- Next & Back Buttons ---
  document.querySelectorAll(".next-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const nextStep = parseInt(btn.getAttribute("data-next"));
      const currentStep = nextStep - 1;

      if (!validateStep(currentStep)) {
        alert("Please fill out all required fields correctly before proceeding.");
        return;
      }

      showStep(nextStep);
    });
  });

  document.querySelectorAll(".back-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const prevStep = parseInt(btn.getAttribute("data-prev"));
      showStep(prevStep);
    });
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
