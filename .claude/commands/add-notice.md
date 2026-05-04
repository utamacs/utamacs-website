# Add a Notice Card

Adds a new notice/announcement card to `src/pages/notices.html` and the preview on `src/pages/index.html`.

## Usage
`/add-notice <title> <date> <category> <description>`

Categories: `Important` | `Meeting` | `Event` | `Maintenance` | `General`

## Card Template (notices.html)

```html
<div class="card-premium animate-on-scroll">
  <div class="flex items-start space-x-4">
    <div class="w-12 h-12 bg-primary-100 rounded-lg flex items-center justify-center flex-shrink-0">
      <i class="fas fa-exclamation-triangle text-primary-600" aria-hidden="true"></i>
    </div>
    <div class="flex-1">
      <h3 class="text-card font-semibold mb-2">TITLE</h3>
      <p class="text-body text-text-secondary mb-3">DESCRIPTION</p>
      <div class="flex items-center justify-between">
        <span class="text-small text-text-secondary">DATE</span>
        <span class="text-small bg-primary-100 text-primary-700 px-2 py-1 rounded">CATEGORY</span>
      </div>
    </div>
  </div>
</div>
```

## Icon mapping by category
| Category | Icon class |
|----------|-----------|
| Important | `fa-exclamation-triangle` + `text-primary-600` |
| Meeting | `fa-calendar-check` + `text-secondary-600` |
| Event | `fa-gift` + `text-accent-600` |
| Maintenance | `fa-tools` + `text-primary-600` |
| General | `fa-info-circle` + `text-text-secondary` |

## Color mapping by category
| Category | bg class | text class |
|----------|----------|------------|
| Important | `bg-primary-100` | `text-primary-700` |
| Meeting | `bg-secondary-100` | `text-secondary-700` |
| Event | `bg-accent-100` | `text-accent-700` |
| Maintenance | `bg-primary-100` | `text-primary-700` |
