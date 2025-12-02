// static/js/carousel.js

function initializeCarousel(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return; 

    const track = container.querySelector('.carousel-track');
    const items = container.querySelectorAll('.carousel-item');
    const prevBtn = container.querySelector('.prev-btn');
    const nextBtn = container.querySelector('.next-btn');

    // If there are no items to show, exit initialization after ensuring items don't break JS
    if (items.length === 0) {
        prevBtn.disabled = true;
        nextBtn.disabled = true;
        return;
    }

    let currentIndex = 0;
    let itemsPerView = 7; // Initial default
    let itemWidth = 0;    // Will be calculated in updateCarousel

    function updateCarousel() {
        // --- FIX START: Recalculate dimensions and view count on every update ---
        itemsPerView = window.innerWidth <= 768 ? 3 : 7;
        
        // This is necessary to account for any padding/margin added by CSS
        const firstItem = items[0];
        if (firstItem) {
            // Calculate width based on the visible area divided by the number of items to show
            itemWidth = track.clientWidth / itemsPerView; 
        }
        // --- FIX END ---
        
        // Ensure all items are set to the newly calculated width (important for consistency)
        items.forEach(item => {
            item.style.minWidth = `${itemWidth}px`; // Use minWidth to prevent shrinking
        });

        // Calculate the total number of scrollable moves
        const totalItems = items.length;
        // Max index is the last position where the first visible item can start scrolling
        const maxIndex = totalItems - itemsPerView; 
        
        // Ensure index is within bounds, especially after resize changes maxIndex
        if (currentIndex < 0) {
            currentIndex = 0;
        } else if (currentIndex > maxIndex) {
            currentIndex = maxIndex > 0 ? maxIndex : 0; // Handle case where maxIndex < 0 (fewer items than view)
        }

        const offset = -currentIndex * itemWidth;
        track.style.transform = `translateX(${offset}px)`;

        // Disable buttons at boundaries
        prevBtn.disabled = currentIndex === 0;
        // Buttons should be disabled if we are at maxIndex OR if maxIndex is 0 or less (not scrollable)
        nextBtn.disabled = currentIndex >= maxIndex; 
    }

    // Event listeners for buttons
    prevBtn.addEventListener('click', () => {
        currentIndex--;
        updateCarousel();
    });

    nextBtn.addEventListener('click', () => {
        currentIndex++;
        updateCarousel();
    });

    // Initial update and handle window resize
    window.addEventListener('resize', updateCarousel);
    updateCarousel(); 
}