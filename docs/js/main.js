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

  // Enhanced Intersection Observer for scroll animations
  const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  };

  const observer = new IntersectionObserver(function(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('revealed');
        entry.target.style.animationDelay = Math.random() * 0.3 + 's';
      }
    });
  }, observerOptions);

  // Observe elements with scroll-reveal class
  document.querySelectorAll('.scroll-reveal').forEach(el => {
    observer.observe(el);
  });

  // Add floating particles to hero section
  createFloatingParticles();

  // Add morphing shapes to background
  createMorphingShapes();

  // Enhanced card hover effects
  document.querySelectorAll('.card-hover').forEach(card => {
    card.addEventListener('mouseenter', function() {
      this.style.transform = 'translateY(-8px) scale(1.02)';
    });

    card.addEventListener('mouseleave', function() {
      this.style.transform = 'translateY(0) scale(1)';
    });
  });

  // Parallax effect for hero section
  window.addEventListener('scroll', function() {
    const scrolled = window.pageYOffset;
    const hero = document.querySelector('.hero-section');
    if (hero) {
      hero.style.transform = `translateY(${scrolled * 0.5}px)`;
    }
  });

  // Typing effect for hero text
  const heroText = document.querySelector('.hero-text');
  if (heroText) {
    typeWriter(heroText, "Welcome to Urban Trilla Apartments Residents Association", 50);
  }

  // Counter animation for statistics
  const counters = document.querySelectorAll('.counter');
  counters.forEach(counter => {
    const target = parseInt(counter.getAttribute('data-target'));
    animateCounter(counter, target);
  });

  // Add shimmer effect to buttons on hover
  document.querySelectorAll('.btn-modern').forEach(btn => {
    btn.addEventListener('mouseenter', function() {
      this.classList.add('shimmer-effect');
    });

    btn.addEventListener('mouseleave', function() {
      this.classList.remove('shimmer-effect');
    });
  });

  // Enhanced mobile menu with slide animation
  const mobileMenuLinks = document.querySelectorAll('#mobile-menu a');
  mobileMenuLinks.forEach(link => {
    link.addEventListener('click', function() {
      mobileMenu.classList.add('hidden');
    });
  });

  // Add loading animation for page transitions
  document.querySelectorAll('a:not([href^="#"])').forEach(link => {
    link.addEventListener('click', function(e) {
      if (!e.ctrlKey && !e.metaKey) {
        e.preventDefault();
        document.body.classList.add('page-transition');
        setTimeout(() => {
          window.location.href = this.href;
        }, 300);
      }
    });
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

// Theme toggle function with enhanced animation
function toggleTheme() {
  document.documentElement.classList.toggle('dark');
  const themeIcon = document.querySelector('#theme-toggle i');
  if (themeIcon) {
    themeIcon.style.transform = 'rotate(360deg)';
    setTimeout(() => {
      if (document.documentElement.classList.contains('dark')) {
        themeIcon.className = 'fas fa-sun';
      } else {
        themeIcon.className = 'fas fa-moon';
      }
      themeIcon.style.transform = 'rotate(0deg)';
    }, 150);
  }
  // Save theme preference to localStorage
  localStorage.setItem('theme', document.documentElement.classList.contains('dark') ? 'dark' : 'light');
}

// Load saved theme on page load
if (localStorage.getItem('theme') === 'dark') {
  document.documentElement.classList.add('dark');
}

// Create floating particles for hero section
function createFloatingParticles() {
  const hero = document.querySelector('.hero-section');
  if (!hero) return;

  const particlesContainer = document.createElement('div');
  particlesContainer.className = 'particles';
  hero.appendChild(particlesContainer);

  for (let i = 0; i < 20; i++) {
    const particle = document.createElement('div');
    particle.className = 'particle';
    particle.style.left = Math.random() * 100 + '%';
    particle.style.top = Math.random() * 100 + '%';
    particle.style.animationDelay = Math.random() * 6 + 's';
    particle.style.animationDuration = (Math.random() * 4 + 4) + 's';
    particlesContainer.appendChild(particle);
  }
}

// Create morphing shapes for background
function createMorphingShapes() {
  const body = document.body;
  for (let i = 0; i < 3; i++) {
    const shape = document.createElement('div');
    shape.className = 'morphing-shape';
    shape.style.position = 'fixed';
    shape.style.width = '200px';
    shape.style.height = '200px';
    shape.style.borderRadius = '50%';
    shape.style.left = Math.random() * 80 + '%';
    shape.style.top = Math.random() * 80 + '%';
    shape.style.zIndex = '-1';
    shape.style.opacity = '0.1';
    shape.style.animationDelay = i * 2 + 's';
    body.appendChild(shape);
  }
}

// Typewriter effect
function typeWriter(element, text, speed) {
  let i = 0;
  element.textContent = '';
  function type() {
    if (i < text.length) {
      element.textContent += text.charAt(i);
      i++;
      setTimeout(type, speed);
    }
  }
  type();
}

// Counter animation
function animateCounter(element, target) {
  let current = 0;
  const increment = target / 100;
  const timer = setInterval(() => {
    current += increment;
    if (current >= target) {
      element.textContent = target;
      clearInterval(timer);
    } else {
      element.textContent = Math.floor(current);
    }
  }, 30);
}

// Add page transition styles
const style = document.createElement('style');
style.textContent = `
  .page-transition {
    opacity: 0;
    transition: opacity 0.3s ease;
  }

  @keyframes morph {
    0%, 100% { border-radius: 50%; transform: scale(1); }
    25% { border-radius: 25%; transform: scale(1.1); }
    50% { border-radius: 0%; transform: scale(0.9); }
    75% { border-radius: 75%; transform: scale(1.05); }
  }

  @keyframes float {
    0%, 100% { transform: translateY(0px); }
    50% { transform: translateY(-20px); }
  }

  @keyframes shimmer {
    0% { left: -100%; }
    100% { left: 100%; }
  }
`;
document.head.appendChild(style);