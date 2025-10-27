function showNotification(message, type = 'info') {
    const container = document.getElementById('notification-container');
    const notif = document.createElement('div');
    notif.className = `notification ${type}`;
    notif.textContent = message;
    container.appendChild(notif);

    // Auto-remove after 3s
    setTimeout(() => container.removeChild(notif), 3000);
}
