// Main JavaScript file for the website
document.addEventListener('DOMContentLoaded', function() {
  // Load header and footer components
  loadComponent('header-placeholder', 'components/nav.html');
  loadComponent('footer-placeholder', 'components/footer.html');

  // Theme toggle functionality
  const themeToggle = document.getElementById('theme-toggle');
  if (themeToggle) {
    themeToggle.addEventListener('click', toggleTheme);
  }

  // Mobile menu toggle
  const mobileMenuToggle = document.getElementById('mobile-menu-toggle');
  const mobileMenu = document.getElementById('mobile-menu');
  if (mobileMenuToggle && mobileMenu) {
    mobileMenuToggle.addEventListener('click', function() {
      mobileMenu.classList.toggle('hidden');
    });
  }

  // Smooth scrolling for anchor links
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      e.preventDefault();
      const target = document.querySelector(this.getAttribute('href'));
      if (target) {
        target.scrollIntoView({
          behavior: 'smooth'
        });
      }
    });
  });

  // Intersection Observer for animations
  const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  };

  const observer = new IntersectionObserver(function(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('animate-fade-in');
      }
    });
  }, observerOptions);

  // Observe elements with animation classes
  document.querySelectorAll('.animate-slide-up, .animate-fade-in').forEach(el => {
    observer.observe(el);
  });
});

// Function to load HTML components
function loadComponent(placeholderId, componentPath) {
  fetch(componentPath)
    .then(response => response.text())
    .then(data => {
      document.getElementById(placeholderId).innerHTML = data;
      // Re-initialize theme toggle after loading nav
      if (componentPath.includes('nav.html')) {
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
          themeToggle.addEventListener('click', toggleTheme);
        }
      }
    })
    .catch(error => console.error('Error loading component:', error));
}

// Theme toggle function
function toggleTheme() {
  document.documentElement.classList.toggle('dark');
  const themeIcon = document.querySelector('#theme-toggle i');
  if (themeIcon) {
    if (document.documentElement.classList.contains('dark')) {
      themeIcon.className = 'fas fa-sun';
    } else {
      themeIcon.className = 'fas fa-moon';
    }
  }
  // Save theme preference to localStorage
  localStorage.setItem('theme', document.documentElement.classList.contains('dark') ? 'dark' : 'light');
}

// Load saved theme on page load
if (localStorage.getItem('theme') === 'dark') {
  document.documentElement.classList.add('dark');
}