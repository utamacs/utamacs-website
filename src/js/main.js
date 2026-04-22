/**
 * Main JavaScript file for UTA MACS website
 * Enhanced with accessibility, performance, and modern UX features
 */

// Global state management
const AppState = {
  theme: localStorage.getItem('theme') || 'light',
  mobileMenuOpen: false,
  componentsLoaded: false
};

// DOM Content Loaded
document.addEventListener('DOMContentLoaded', function() {
  console.log('🚀 UTA MACS Website Initialized');

  // Initialize core functionality
  initializeComponents();
  initializeTheme();
  initializeMobileMenu();
  initializeScrollEffects();
  initializeAccessibility();
  initializePerformance();

  // Mark initialization complete
  console.log('✅ All systems initialized');
});

/**
 * Load and initialize header/footer components
 */
function initializeComponents() {
  loadComponent('header-placeholder', 'components/nav.html');
  loadComponent('footer-placeholder', 'components/footer.html');

  // Wait for components to load, then initialize dependent features
  setTimeout(() => {
    AppState.componentsLoaded = true;
    initializePostLoadFeatures();
  }, 100);
}

/**
 * Features that require components to be loaded first
 */
function initializePostLoadFeatures() {
  initializeNavigation();
  initializeKeyboardNavigation();
}

/**
 * Enhanced component loading with error handling
 */
function loadComponent(placeholderId, componentPath) {
  const placeholder = document.getElementById(placeholderId);
  if (!placeholder) {
    console.warn(`Placeholder ${placeholderId} not found`);
    return;
  }

  fetch(componentPath)
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.text();
    })
    .then(html => {
      placeholder.innerHTML = html;
      placeholder.id = ''; // Remove placeholder ID

      // Dispatch custom event for component loaded
      const event = new CustomEvent('componentLoaded', {
        detail: { id: placeholderId, path: componentPath }
      });
      document.dispatchEvent(event);
    })
    .catch(error => {
      console.error(`Failed to load component ${componentPath}:`, error);
      placeholder.innerHTML = `
        <div class="text-center py-8 text-red-600">
          <i class="fas fa-exclamation-triangle text-2xl mb-2"></i>
          <p>Failed to load component. Please refresh the page.</p>
        </div>
      `;
    });
}

/**
 * Theme management system
 */
function initializeTheme() {
  const themeToggle = document.getElementById('theme-toggle');

  // Apply saved theme
  applyTheme(AppState.theme);

  // Theme toggle event listener
  if (themeToggle) {
    themeToggle.addEventListener('click', function(e) {
      e.preventDefault();
      toggleTheme();
    });

    // Update toggle button icon
    updateThemeToggleIcon();
  }

  // Listen for system theme changes
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (!localStorage.getItem('theme')) {
      AppState.theme = e.matches ? 'dark' : 'light';
      applyTheme(AppState.theme);
    }
  });
}

function toggleTheme() {
  AppState.theme = AppState.theme === 'light' ? 'dark' : 'light';
  localStorage.setItem('theme', AppState.theme);
  applyTheme(AppState.theme);
  updateThemeToggleIcon();

  // Announce theme change to screen readers
  announceToScreenReader(`Theme changed to ${AppState.theme} mode`);
}

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);

  if (theme === 'dark') {
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
  }
}

function updateThemeToggleIcon() {
  const themeToggle = document.getElementById('theme-toggle');
  if (!themeToggle) return;

  const icon = themeToggle.querySelector('i');
  if (!icon) return;

  if (AppState.theme === 'dark') {
    icon.className = 'fas fa-sun text-lg';
    themeToggle.setAttribute('aria-label', 'Switch to light mode');
  } else {
    icon.className = 'fas fa-moon text-lg';
    themeToggle.setAttribute('aria-label', 'Switch to dark mode');
  }
}

/**
 * Enhanced mobile menu system
 */
function initializeMobileMenu() {
  const mobileMenuToggle = document.getElementById('mobile-menu-toggle');
  const mobileMenu = document.getElementById('mobile-menu');
  const mobileMenuClose = document.getElementById('mobile-menu-close');

  if (!mobileMenuToggle || !mobileMenu) return;

  // Toggle menu
  mobileMenuToggle.addEventListener('click', function(e) {
    e.preventDefault();
    toggleMobileMenu();
  });

  // Close menu button
  if (mobileMenuClose) {
    mobileMenuClose.addEventListener('click', function(e) {
      e.preventDefault();
      closeMobileMenu();
    });
  }

  // Close on overlay click
  mobileMenu.addEventListener('click', function(e) {
    if (e.target === mobileMenu) {
      closeMobileMenu();
    }
  });

  // Close on escape key
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && AppState.mobileMenuOpen) {
      closeMobileMenu();
    }
  });

  // Close on window resize (if desktop size)
  window.addEventListener('resize', function() {
    if (window.innerWidth >= 1024 && AppState.mobileMenuOpen) {
      closeMobileMenu();
    }
  });
}

function toggleMobileMenu() {
  if (AppState.mobileMenuOpen) {
    closeMobileMenu();
  } else {
    openMobileMenu();
  }
}

function openMobileMenu() {
  const mobileMenu = document.getElementById('mobile-menu');
  const mobileMenuToggle = document.getElementById('mobile-menu-toggle');

  if (!mobileMenu || !mobileMenuToggle) return;

  AppState.mobileMenuOpen = true;
  mobileMenu.classList.remove('hidden');
  mobileMenuToggle.setAttribute('aria-expanded', 'true');

  // Prevent body scroll
  document.body.style.overflow = 'hidden';

  // Focus management
  const firstFocusable = mobileMenu.querySelector('a, button');
  if (firstFocusable) {
    firstFocusable.focus();
  }

  // Announce to screen readers
  announceToScreenReader('Mobile menu opened');
}

function closeMobileMenu() {
  const mobileMenu = document.getElementById('mobile-menu');
  const mobileMenuToggle = document.getElementById('mobile-menu-toggle');

  if (!mobileMenu || !mobileMenuToggle) return;

  AppState.mobileMenuOpen = false;
  mobileMenu.classList.add('hidden');
  mobileMenuToggle.setAttribute('aria-expanded', 'false');

  // Restore body scroll
  document.body.style.overflow = '';

  // Return focus to toggle button
  mobileMenuToggle.focus();

  // Announce to screen readers
  announceToScreenReader('Mobile menu closed');
}

/**
 * Navigation enhancements
 */
function initializeNavigation() {
  // Active link highlighting
  updateActiveNavLink();

  // Smooth scroll for anchor links
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
      const href = this.getAttribute('href');

      // Only prevent default for same-page anchors
      if (href.startsWith('#')) {
        e.preventDefault();
        const target = document.querySelector(href);
        if (target) {
          target.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
          });

          // Close mobile menu if open
          if (AppState.mobileMenuOpen) {
            closeMobileMenu();
          }
        }
      }
    });
  });

  // Update active link on scroll
  window.addEventListener('scroll', debounce(updateActiveNavLink, 100));
}

function updateActiveNavLink() {
  const sections = document.querySelectorAll('section[id]');
  const navLinks = document.querySelectorAll('.nav-link');

  let current = '';

  sections.forEach(section => {
    const sectionTop = section.offsetTop;
    const sectionHeight = section.clientHeight;

    if (window.pageYOffset >= sectionTop - sectionHeight / 3) {
      current = section.getAttribute('id');
    }
  });

  navLinks.forEach(link => {
    link.classList.remove('active');
    const href = link.getAttribute('href');

    if (href === `#${current}` || (href === 'index.html' && current === '')) {
      link.classList.add('active');
    }
  });
}

/**
 * Scroll effects and animations
 */
function initializeScrollEffects() {
  // Intersection Observer for animations
  const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('animate');
      }
    });
  }, observerOptions);

  // Observe all animate-on-scroll elements
  document.querySelectorAll('.animate-on-scroll').forEach(el => {
    observer.observe(el);
  });

  // Parallax effect for hero section (if exists)
  const heroSection = document.querySelector('.section-hero');
  if (heroSection) {
    window.addEventListener('scroll', function() {
      const scrolled = window.pageYOffset;
      const rate = scrolled * -0.5;
      heroSection.style.transform = `translateY(${rate}px)`;
    });
  }
}

/**
 * Accessibility enhancements
 */
function initializeAccessibility() {
  // Skip to main content link
  const skipLink = document.createElement('a');
  skipLink.href = '#main';
  skipLink.className = 'sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 bg-primary-600 text-white px-4 py-2 rounded z-50';
  skipLink.textContent = 'Skip to main content';
  document.body.insertBefore(skipLink, document.body.firstChild);

  // Focus trap for mobile menu
  document.addEventListener('keydown', function(e) {
    if (!AppState.mobileMenuOpen) return;

    const mobileMenu = document.getElementById('mobile-menu');
    if (!mobileMenu) return;

    const focusableElements = mobileMenu.querySelectorAll('a, button, input, select, textarea');
    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];

    if (e.key === 'Tab') {
      if (e.shiftKey) {
        if (document.activeElement === firstElement) {
          lastElement.focus();
          e.preventDefault();
        }
      } else {
        if (document.activeElement === lastElement) {
          firstElement.focus();
          e.preventDefault();
        }
      }
    }
  });
}

function initializeKeyboardNavigation() {
  // Enhanced keyboard navigation for custom components
  document.addEventListener('keydown', function(e) {
    // Ctrl/Cmd + / for search (if search exists)
    if ((e.ctrlKey || e.metaKey) && e.key === '/') {
      const searchInput = document.querySelector('input[type="search"], input[placeholder*="search" i]');
      if (searchInput) {
        e.preventDefault();
        searchInput.focus();
      }
    }
  });
}

/**
 * Performance optimizations
 */
function initializePerformance() {
  // Lazy load images
  const images = document.querySelectorAll('img[data-src]');
  if ('IntersectionObserver' in window) {
    const imageObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const img = entry.target;
          img.src = img.dataset.src;
          img.classList.remove('lazy');
          imageObserver.unobserve(img);
        }
      });
    });

    images.forEach(img => imageObserver.observe(img));
  }

  // Preload critical resources
  const criticalResources = [
    'css/styles.css',
    'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap'
  ];

  criticalResources.forEach(resource => {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.href = resource;
    link.as = 'style';
    document.head.appendChild(link);
  });
}

/**
 * Utility functions
 */
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

function announceToScreenReader(message) {
  const announcement = document.createElement('div');
  announcement.setAttribute('aria-live', 'polite');
  announcement.setAttribute('aria-atomic', 'true');
  announcement.className = 'sr-only';
  announcement.textContent = message;

  document.body.appendChild(announcement);

  setTimeout(() => {
    document.body.removeChild(announcement);
  }, 1000);
}

// Export for potential use in other scripts
window.UTAMACS = {
  toggleTheme,
  toggleMobileMenu,
  announceToScreenReader
};