# Create a New Page

Creates a new HTML page in `src/pages/` following the project's design system conventions.

## Usage
`/new-page <page-name> <Page Title>`

## What this does
1. Creates `src/pages/<page-name>.html` with the standard page scaffold
2. Adds a `nav-link` entry in `src/components/nav.html` (desktop + mobile)
3. Copies the new file to `docs/pages/<page-name>.html`

## Standard Page Scaffold

Use this template — substitute `$ARGUMENTS` for the page title:

```html
<!DOCTYPE html>
<html lang="en" class="scroll-smooth">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$ARGUMENTS - UTA MACS</title>
  <meta name="description" content="">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <script src="https://cdn.tailwindcss.com"></script>
  <script src="https://kit.fontawesome.com/5a2b2f0b4f.js" crossorigin="anonymous"></script>
  <link rel="stylesheet" href="../css/styles.css">
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🏢</text></svg>">
</head>
<body class="bg-background text-text-primary overflow-x-hidden">
  <header id="header-placeholder"></header>

  <main>
    <!-- Page Hero -->
    <section class="section-hero py-20">
      <div class="container-custom text-center text-white">
        <h1 class="text-hero font-bold mb-4">$ARGUMENTS</h1>
        <p class="text-body-lg opacity-90 max-w-2xl mx-auto"></p>
      </div>
    </section>

    <!-- Main Content -->
    <section class="section">
      <div class="container-custom">
        <!-- Content goes here -->
      </div>
    </section>
  </main>

  <footer id="footer-placeholder"></footer>
  <script src="../js/main.js"></script>
</body>
</html>
```

## Key conventions
- CSS/JS paths from `src/pages/` use `../` prefix: `../css/styles.css`, `../js/main.js`
- Component paths in `main.js` `loadComponent()` calls auto-resolve relative to the HTML file
- Alternate section backgrounds: even sections use `section-alt`, odd use `bg-background`
- All images need descriptive `alt` text
- Icons get `aria-hidden="true"`
