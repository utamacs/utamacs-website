# Update Committee Member

Adds, updates, or removes a committee member in `src/pages/committee.html`.

## Usage
`/update-committee add <name> <role> <initials>`
`/update-committee remove <name>`
`/update-committee update <name> <field> <value>`

## Member Card Template

```html
<div class="card-premium animate-on-scroll text-center">
  <div class="w-20 h-20 bg-primary-100 rounded-full flex items-center justify-center mx-auto mb-4">
    <span class="text-primary-600 text-2xl font-bold">XX</span>
  </div>
  <h3 class="text-card font-semibold text-text-primary mb-1">Full Name</h3>
  <p class="text-small text-primary-600 font-medium mb-3">Role / Designation</p>
  <p class="text-body text-text-secondary">Brief description or responsibility area.</p>
</div>
```

## Initials convention
- Use first letter of first name + first letter of last name (e.g., "Rajesh Kumar" → "RK")
- Keep initials to 2 characters maximum

## Color rotation for variety
Rotate through these background colors so cards look varied:
- `bg-primary-100` / `text-primary-600`
- `bg-secondary-100` / `text-secondary-600`
- `bg-accent-100` / `text-accent-600`

## Grid layout
Committee grid: `class="grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"`
