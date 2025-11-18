document.addEventListener('DOMContentLoaded', function() {
    const changeBtn = document.getElementById('change-picture-btn');
    const modal = document.getElementById('profile-modal');
    const closeBtn = document.getElementById('close-modal');
    const fileInput = document.getElementById('profile-picture-input');
    const submitBtn = document.getElementById('submit-btn');
    const errorMsg = document.getElementById('error-message');

    // Show modal
    changeBtn.addEventListener('click', function() {
        modal.style.display = 'block';
    });

    // Close modal
    closeBtn.addEventListener('click', function() {
        modal.style.display = 'none';
        fileInput.value = '';
        submitBtn.disabled = true;
        errorMsg.style.display = 'none';
    });

    // Close modal on overlay click
    modal.addEventListener('click', function(e) {
        if (e.target === modal) {
            modal.style.display = 'none';
            fileInput.value = '';
            submitBtn.disabled = true;
            errorMsg.style.display = 'none';
        }
    });

    // Validate image on file select
    fileInput.addEventListener('change', function(e) {
        const file = e.target.files[0];
        if (file) {
            const img = new Image();
            img.onload = function() {
                if (img.width === img.height) {
                    submitBtn.disabled = false;
                    errorMsg.style.display = 'none';
                } else {
                    submitBtn.disabled = true;
                    errorMsg.style.display = 'block';
                }
            };
            img.src = URL.createObjectURL(file);
        } else {
            submitBtn.disabled = true;
            errorMsg.style.display = 'none';
        }
    });
});
