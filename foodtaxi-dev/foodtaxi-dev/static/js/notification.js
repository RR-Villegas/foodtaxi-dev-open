function showNotification(message, type = "success", duration = 3000) {
  const container = document.getElementById("notification-container");
  if (!container) return;

  // Create notification element
  const notif = document.createElement("div");
  notif.className = `notification ${type}`;
  notif.textContent = message;

  // Add to container
  container.appendChild(notif);

  // Auto-remove after duration
  setTimeout(() => {
    notif.style.opacity = '0';
    notif.style.transform = 'translateY(-20px)';
    setTimeout(() => notif.remove(), 300); // match CSS transition
  }, duration);
}
