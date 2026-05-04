# Add an Event

Adds a new event card to `src/pages/events.html` and the gallery/events preview on `src/pages/index.html`.

## Usage
`/add-event <title> <date> <time> <description>`

## Event Card Template

```html
<div class="card-premium animate-on-scroll">
  <div class="flex items-center mb-4">
    <div class="w-12 h-12 bg-primary-100 rounded-xl flex items-center justify-center mr-4">
      <i class="fas fa-calendar-alt text-primary-600 text-xl" aria-hidden="true"></i>
    </div>
    <div>
      <div class="text-small text-primary-600 font-medium">DATE</div>
      <div class="text-small text-text-secondary">TIME</div>
    </div>
  </div>
  <h3 class="text-card font-semibold mb-3 text-text-primary">TITLE</h3>
  <p class="text-body text-text-secondary mb-4">DESCRIPTION</p>
  <button class="btn-primary w-full">
    <i class="fas fa-calendar-check mr-2" aria-hidden="true"></i>
    Register Now
  </button>
</div>
```

## Notes
- Events grid uses `class="grid md:grid-cols-2 lg:grid-cols-3 gap-6"`
- Add `style="animation-delay: 0.Xs;"` to stagger animations (0.1s increments)
- Past events should be moved to a "Past Events" section with `opacity-75` styling
