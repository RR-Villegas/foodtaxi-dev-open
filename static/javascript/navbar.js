// static/javascript/navbar.js

document.addEventListener('DOMContentLoaded', function() {
    const hamburgerBtn = document.getElementById('hamburger-btn');
    const sidebarMenu = document.getElementById('sidebar-menu');
    const closeSidebarBtn = document.getElementById('close-sidebar');
    const sidebarOverlay = document.getElementById('sidebar-overlay');
    const themeSelect = document.getElementById('theme-select');

    // Hamburger menu toggle
    hamburgerBtn.addEventListener('click', function() {
        hamburgerBtn.classList.toggle('active');
        sidebarMenu.classList.toggle('active');
        sidebarOverlay.classList.toggle('active');
    });

    // Close sidebar when close button is clicked
    closeSidebarBtn.addEventListener('click', function() {
        hamburgerBtn.classList.remove('active');
        sidebarMenu.classList.remove('active');
        sidebarOverlay.classList.remove('active');
    });

    // Close sidebar when overlay is clicked
    sidebarOverlay.addEventListener('click', function() {
        hamburgerBtn.classList.remove('active');
        sidebarMenu.classList.remove('active');
        sidebarOverlay.classList.remove('active');
    });

    // Close sidebar when a link is clicked
    const sidebarLinks = document.querySelectorAll('.sidebar-link');
    sidebarLinks.forEach(link => {
        link.addEventListener('click', function() {
            hamburgerBtn.classList.remove('active');
            sidebarMenu.classList.remove('active');
            sidebarOverlay.classList.remove('active');
        });
    });

    // Initialize theme from localStorage
    const savedTheme = localStorage.getItem('theme') || 'light';
    applyTheme(savedTheme);
    themeSelect.value = savedTheme;

    // Theme selection
    themeSelect.addEventListener('change', function() {
        applyTheme(this.value);
        localStorage.setItem('theme', this.value);
    });

    // Close sidebar on Escape key
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            hamburgerBtn.classList.remove('active');
            sidebarMenu.classList.remove('active');
            sidebarOverlay.classList.remove('active');
        }
    });

    function applyTheme(theme) {
        const body = document.body;
        body.classList.remove('dark-mode', 'koishi-mode');
        
        if (theme === 'dark') {
            body.classList.add('dark-mode');
        } else if (theme === 'koishi') {
            body.classList.add('koishi-mode');
        }
        // light theme is default, no class needed
    }
});
