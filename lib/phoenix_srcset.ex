defmodule PhoenixSrcset do
  @moduledoc """
  A minimal library for generating responsive image variants and serving them
  with proper srcset attributes.

  ## Features

  - Generates multiple image sizes from source images using ImageMagick
  - Converts to WebP format for better compression
  - Provides a HEEx component for responsive `<img>` tags with srcset

  ## Usage

  ### Generate variants

      mix phoenix_srcset.generate assets/public/images/photo.png

  This creates variants in the same directory:
  - photo_400w.webp
  - photo_800w.webp
  - photo_1200w.webp
  - photo_1600w.webp

  ### Use in templates

      <PhoenixSrcset.Components.responsive_img
        src="/images/photo.png"
        widths={[400, 800, 1200, 1600]}
        sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 800px"
        alt="A beautiful photo"
        class="rounded-lg"
      />

  ## Configuration

  Configure default widths in config.exs:

      config :phoenix_srcset,
        widths: [400, 800, 1200, 1600],
        format: "webp",
        quality: 85

  """

  @default_widths [400, 800, 1200, 1600]
  @default_format "webp"
  @default_quality 85

  def default_widths, do: Application.get_env(:phoenix_srcset, :widths, @default_widths)
  def default_format, do: Application.get_env(:phoenix_srcset, :format, @default_format)
  def default_quality, do: Application.get_env(:phoenix_srcset, :quality, @default_quality)

  @doc """
  Generates the variant filename for a given source path and width.

  ## Examples

      iex> PhoenixSrcset.variant_path("/images/photo.png", 800)
      "/images/photo_800w.webp"

      iex> PhoenixSrcset.variant_path("/images/photo.png", 800, "avif")
      "/images/photo_800w.avif"

  """
  def variant_path(src, width, format \\ nil) do
    format = format || default_format()
    dir = Path.dirname(src)
    base = Path.basename(src, Path.extname(src))
    Path.join(dir, "#{base}_#{width}w.#{format}")
  end

  @doc """
  Builds a srcset string for the given source and widths.

  ## Examples

      iex> PhoenixSrcset.srcset("/images/photo.png", [400, 800, 1200])
      "/images/photo_400w.webp 400w, /images/photo_800w.webp 800w, /images/photo_1200w.webp 1200w"

  """
  def srcset(src, widths, format \\ nil) do
    widths
    |> Enum.map(fn width ->
      "#{variant_path(src, width, format)} #{width}w"
    end)
    |> Enum.join(", ")
  end
end
