defmodule PhoenixSrcset.Components do
  @moduledoc """
  HEEx components for rendering responsive images with srcset.
  """
  use Phoenix.Component

  @doc """
  Renders a responsive image with srcset for multiple widths.

  The component generates an `<img>` tag with a `srcset` attribute pointing to
  WebP variants at different widths, allowing browsers to choose the most
  appropriate size.

  ## Attributes

  - `src` (required) - The original image path (e.g., "/images/photo.png")
  - `alt` (required) - Alt text for accessibility
  - `widths` - List of widths for srcset (default: [400, 800, 1200, 1600])
  - `sizes` - The sizes attribute for responsive hints (default: "100vw")
  - `format` - Image format for variants (default: "webp")
  - `class` - CSS classes for the image
  - `loading` - Loading strategy: "lazy" or "eager" (default: "lazy")

  ## Examples

      <PhoenixSrcset.Components.responsive_img
        src="/images/hero.png"
        alt="Hero image"
        sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 800px"
        class="rounded-lg shadow-xl"
      />

      <PhoenixSrcset.Components.responsive_img
        src="/images/thumbnail.png"
        alt="Thumbnail"
        widths={[200, 400]}
        sizes="200px"
        loading="eager"
      />

  """
  attr :src, :string, required: true
  attr :alt, :string, required: true
  attr :widths, :list, default: nil
  attr :sizes, :string, default: "100vw"
  attr :format, :string, default: nil
  attr :class, :string, default: nil
  attr :loading, :string, default: "lazy"
  attr :rest, :global

  def responsive_img(assigns) do
    widths = assigns.widths || PhoenixSrcset.default_widths()
    format = assigns.format || PhoenixSrcset.default_format()

    assigns =
      assigns
      |> assign(:srcset, PhoenixSrcset.srcset(assigns.src, widths, format))
      |> assign(:default_src, PhoenixSrcset.variant_path(assigns.src, Enum.max(widths), format))

    ~H"""
    <img
      src={@default_src}
      srcset={@srcset}
      sizes={@sizes}
      alt={@alt}
      class={@class}
      loading={@loading}
      {@rest}
    />
    """
  end

  @doc """
  Renders a responsive picture element with WebP and fallback.

  Uses the `<picture>` element to serve WebP with a fallback to the original
  format for older browsers.

  ## Attributes

  Same as `responsive_img/1`, plus:
  - `fallback_format` - Fallback format if WebP not supported (default: original extension)

  ## Examples

      <PhoenixSrcset.Components.responsive_picture
        src="/images/hero.png"
        alt="Hero image"
        sizes="100vw"
      />

  """
  attr :src, :string, required: true
  attr :alt, :string, required: true
  attr :widths, :list, default: nil
  attr :sizes, :string, default: "100vw"
  attr :format, :string, default: nil
  attr :class, :string, default: nil
  attr :loading, :string, default: "lazy"
  attr :rest, :global

  def responsive_picture(assigns) do
    widths = assigns.widths || PhoenixSrcset.default_widths()
    format = assigns.format || PhoenixSrcset.default_format()
    fallback_ext = Path.extname(assigns.src) |> String.trim_leading(".")

    assigns =
      assigns
      |> assign(:srcset_webp, PhoenixSrcset.srcset(assigns.src, widths, format))
      |> assign(:srcset_fallback, PhoenixSrcset.srcset(assigns.src, widths, fallback_ext))
      |> assign(:default_src, PhoenixSrcset.variant_path(assigns.src, Enum.max(widths), format))
      |> assign(:mime_type, mime_type(format))

    ~H"""
    <picture>
      <source type={@mime_type} srcset={@srcset_webp} sizes={@sizes} />
      <img
        src={@default_src}
        srcset={@srcset_fallback}
        sizes={@sizes}
        alt={@alt}
        class={@class}
        loading={@loading}
        {@rest}
      />
    </picture>
    """
  end

  defp mime_type("webp"), do: "image/webp"
  defp mime_type("avif"), do: "image/avif"
  defp mime_type("png"), do: "image/png"
  defp mime_type("jpg"), do: "image/jpeg"
  defp mime_type("jpeg"), do: "image/jpeg"
  defp mime_type(_), do: "image/webp"
end
