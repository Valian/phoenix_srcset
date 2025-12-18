# PhoenixSrcset

A dead-simple solution for responsive images in Phoenix. No cloud services, no complex pipelines—just ImageMagick and a mix task.

## Why?

Most image optimization solutions are overkill. You don't need a CDN, a build pipeline, or a SaaS subscription. You need:

1. Multiple image sizes for `srcset`
2. WebP format for compression
3. A component that renders the right HTML

That's it. This library does exactly that.

## Requirements

- ImageMagick (`brew install imagemagick`)

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_srcset, "~> 0.1.0"}
  ]
end
```

## Usage

### 1. Generate variants

```bash
# Single image
mix phoenix_srcset.generate priv/static/images/hero.png

# All images in a directory
mix phoenix_srcset.generate priv/static/images/

# Custom widths
mix phoenix_srcset.generate priv/static/images/ --widths=320,640,960
```

This creates WebP variants alongside your originals:
- `hero_400w.webp`
- `hero_800w.webp`
- `hero_1200w.webp`
- `hero_1600w.webp`

### 2. Use the component

```heex
<PhoenixSrcset.Components.responsive_img
  src="/images/hero.png"
  alt="Hero image"
  sizes="(max-width: 640px) 100vw, 50vw"
  class="rounded-lg"
/>
```

Renders:
```html
<img
  src="/images/hero_1600w.webp"
  srcset="/images/hero_400w.webp 400w, /images/hero_800w.webp 800w, /images/hero_1200w.webp 1200w, /images/hero_1600w.webp 1600w"
  sizes="(max-width: 640px) 100vw, 50vw"
  alt="Hero image"
  class="rounded-lg"
  loading="lazy"
/>
```

### Picture element with fallback

For browsers that don't support WebP:

```heex
<PhoenixSrcset.Components.responsive_picture
  src="/images/hero.png"
  alt="Hero image"
  sizes="100vw"
/>
```

## Configuration

Optional—sensible defaults are built in.

```elixir
# config/config.exs
config :phoenix_srcset,
  widths: [400, 800, 1200, 1600],
  format: "webp",
  quality: 85
```

## Mix Task Options

```
mix phoenix_srcset.generate PATH [OPTIONS]

Options:
  --widths    Comma-separated widths (default: 400,800,1200,1600)
  --format    Output format: webp, avif, jpg, png (default: webp)
  --quality   Output quality 1-100 (default: 85)
  --force     Regenerate existing variants
```

## License

MIT
