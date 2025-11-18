const gear = document.getElementById("raiderSettingsIcon");
const dropdown = gear.parentElement;

gear.addEventListener("click", () => {
  dropdown.classList.toggle("active");
  gear.style.transform = dropdown.classList.contains("active")
    ? "rotate(180deg)"
    : "rotate(0)";
});
