// static/js/carousel.js (REPLACE ALL CONTENT)

function initializeCarousel(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return; 

    // Target the element containing the items for transformation (based on your HTML)
    const transformTarget = container.querySelector('.carousel-wrapper'); 
    const items = container.querySelectorAll('.carousel-item');
    const prevBtn = container.querySelector('.prev-btn');
    const nextBtn = container.querySelector('.next-btn');

    if (items.length === 0 || !transformTarget) {
        if (prevBtn) prevBtn.disabled = true;
        if (nextBtn) nextBtn.disabled = true;
        return;
    }

    let currentIndex = 0;
    let autoplayInterval;
    
    // --- Helper Function: Get current translateX from CSS Matrix ---
    // Used to read the live position during a drag
    function getTranslateX() {
        const style = window.getComputedStyle(transformTarget);
        const matrix = style.transform || style.webkitTransform || style.mozTransform;
        if (matrix === 'none') return 0;
        
        // Extract the translateX value
        const matrixValues = matrix.match(/matrix.*\((.+)\)/)[1].split(', ');
        return parseFloat(matrixValues[4]); 
    }
    
    // --- CORE FUNCTION: Update Carousel Position ---
    function updateCarousel(instant = false) {
        
        const firstItem = items[0];
        if (!firstItem) return;
        
        // CRITICAL: Use the actual computed width (includes padding/margin from CSS)
        const itemWidth = firstItem.offsetWidth; 
        
        // Determine view count (matching your CSS media queries)
        const itemsPerView = window.innerWidth <= 768 ? 3 : 7;
        const totalItems = items.length;
        const maxIndex = totalItems - itemsPerView; 
        
        // Ensure index is within bounds
        currentIndex = Math.max(0, Math.min(currentIndex, maxIndex > 0 ? maxIndex : 0));
        
        const offset = -currentIndex * itemWidth;
        
        // Apply transform
        transformTarget.style.transition = instant ? 'none' : 'transform 0.5s ease-in-out';
        transformTarget.style.transform = `translateX(${offset}px)`;

        // Update button state
        if (prevBtn) prevBtn.disabled = currentIndex === 0;
        if (nextBtn) nextBtn.disabled = currentIndex >= maxIndex;
    }

    // --- AUTOPLAY LOGIC (Auto Scroll Right) ---
    function startAutoplay() {
        stopAutoplay(); 
        
        autoplayInterval = setInterval(() => {
            const itemsPerView = window.innerWidth <= 768 ? 3 : 7;
            const maxIndex = items.length - itemsPerView; 
            
            // Looping logic: Go to next, or snap back to start
            if (currentIndex >= maxIndex) {
                currentIndex = 0; 
                updateCarousel(true); // Snap instantly to start for seamless loop
            } else {
                currentIndex++;
                updateCarousel(false); // Animate next slide
            }
        }, 3000); // 3 seconds interval
    }

    function stopAutoplay() {
        if (autoplayInterval) {
            clearInterval(autoplayInterval);
        }
    }
    
    // Pause/Resume Autoplay on hover/focus
    container.addEventListener('mouseenter', stopAutoplay);
    container.addEventListener('mouseleave', startAutoplay);
    
    // --- BUTTON NAVIGATION ---
    if (prevBtn) {
        prevBtn.addEventListener('click', () => {
            currentIndex--;
            updateCarousel();
            stopAutoplay();
        });
    }

    if (nextBtn) {
        nextBtn.addEventListener('click', () => {
            currentIndex++;
            updateCarousel();
            stopAutoplay();
        });
    }
    
    // --- DRAG/SWIPE LOGIC ---
    let isDragging = false;
    let startX; 
    let initialTranslateX; 
    let hasDragged = false; 

    const dragStart = (e) => {
        isDragging = true;
        hasDragged = false;
        
        stopAutoplay(); 
        transformTarget.style.transition = 'none'; 

        const clientX = e.clientX || e.touches[0].clientX; 
        
        startX = clientX;
        initialTranslateX = getTranslateX();
        
        // Visual feedback
        transformTarget.style.cursor = 'grabbing';
        container.style.userSelect = 'none'; 
    };

    const dragMove = (e) => {
        if (!isDragging) return;
        // CRITICAL FIX: Prevent browser's native drag/selection behavior ("sticking")
        e.preventDefault(); 
        
        const clientX = e.clientX || e.touches[0].clientX;
        const currentX = clientX;
        const dragDistance = currentX - startX;
        
        // Apply immediate drag position
        transformTarget.style.transform = `translateX(${initialTranslateX + dragDistance}px)`;

        if (Math.abs(dragDistance) > 10) { 
            hasDragged = true;
        }
    };

    const dragEnd = () => {
        if (!isDragging) return;
        isDragging = false;
        
        // SNAP TO NEAREST ITEM ON DRAG END
        if (hasDragged) {
            const finalTranslateX = getTranslateX();
            const itemWidth = items[0].offsetWidth;
            
            // Calculate the number of items moved and snap to the nearest index
            const itemsMoved = Math.round((initialTranslateX - finalTranslateX) / itemWidth);
            currentIndex += itemsMoved;
            
            // Snap back with transition
            updateCarousel(false); 
        }
        
        // Reset feedback
        transformTarget.style.cursor = 'grab';
        container.style.userSelect = 'auto';
        startAutoplay(); 
    };

    // Apply drag listeners to the transformTarget
    transformTarget.addEventListener('mousedown', dragStart);
    transformTarget.addEventListener('touchstart', dragStart); 
    
    // Listeners for mouse/touch release and movement on the document for robustness
    document.addEventListener('mouseup', dragEnd);
    document.addEventListener('touchend', dragEnd);
    document.addEventListener('mousemove', dragMove);
    document.addEventListener('touchmove', dragMove);


    // --- SCROLLWHEEL NAVIGATION ---
    transformTarget.addEventListener('wheel', (e) => {
        // Prevent vertical page scroll if user is attempting horizontal scroll
        e.preventDefault(); 
        stopAutoplay();
        
        if (e.deltaY !== 0) { // deltaY is usually used for vertical scroll on wheel
            // Scroll right (down on wheel)
            if (e.deltaY > 0) {
                currentIndex++;
            } 
            // Scroll left (up on wheel)
            else if (e.deltaY < 0) {
                currentIndex--;
            }
            updateCarousel();
            
            // Resume autoplay after a short delay (if user stops scrolling)
            clearTimeout(transformTarget.wheelTimer);
            transformTarget.wheelTimer = setTimeout(startAutoplay, 1500); 
        }
    });


    // --- PREVENT ACCIDENTAL CLICKS AFTER DRAG ---
    transformTarget.querySelectorAll('.carousel-item a').forEach(link => {
        link.addEventListener('click', (e) => {
            if (hasDragged) {
                e.preventDefault();
                hasDragged = false; 
            }
        });
    });

    // Initial load and resize handling
    window.addEventListener('resize', () => updateCarousel(true));
    updateCarousel(true); 
    startAutoplay(); 
}