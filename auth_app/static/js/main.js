// Простой JavaScript для улучшения пользовательского опыта
document.addEventListener('DOMContentLoaded', function() {
    // Добавляем класс 'active' к текущему пункту меню
    const currentLocation = window.location.pathname;
    const menuItems = document.querySelectorAll('nav ul li a');
    
    menuItems.forEach(item => {
        if (item.getAttribute('href') === currentLocation) {
            item.parentElement.classList.add('current');
        }
    });
    
    // Эффекты для кнопок
    const buttons = document.querySelectorAll('.btn');
    buttons.forEach(button => {
        button.addEventListener('mouseover', function() {
            this.style.transform = 'scale(1.05)';
            this.style.transition = 'all 0.2s ease';
        });
        
        button.addEventListener('mouseout', function() {
            this.style.transform = 'scale(1)';
        });
    });
    
    // Анимация для информационных блоков
    const infoBoxes = document.querySelectorAll('.info-box');
    infoBoxes.forEach(box => {
        box.style.transition = 'all 0.3s ease';
        
        box.addEventListener('mouseover', function() {
            this.style.boxShadow = '0 5px 15px rgba(0,0,0,0.2)';
        });
        
        box.addEventListener('mouseout', function() {
            this.style.boxShadow = '0 0 10px rgba(0,0,0,0.1)';
        });
    });
});
