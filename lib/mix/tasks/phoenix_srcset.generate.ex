defmodule Mix.Tasks.PhoenixSrcset.Generate do
  @shortdoc "Generates responsive image variants"
  @moduledoc """
  Generates responsive image variants from source images.

  ## Usage

      mix phoenix_srcset.generate PATH [OPTIONS]

  ## Arguments

  - `PATH` - Path to image file or directory containing images

  ## Options

  - `--widths` - Comma-separated list of widths (default: 400,800,1200,1600)
  - `--format` - Output format: webp, avif, jpg, png (default: webp)
  - `--quality` - Output quality 1-100 (default: 85)
  - `--force` - Regenerate existing variants

  ## Examples

      # Generate variants for a single image
      mix phoenix_srcset.generate assets/public/images/photo.png

      # Generate variants for all images in a directory
      mix phoenix_srcset.generate assets/public/images/

      # Custom widths and format
      mix phoenix_srcset.generate assets/public/images/ --widths=320,640,960 --format=avif

      # Force regeneration
      mix phoenix_srcset.generate assets/public/images/ --force

  """
  use Mix.Task

  @image_extensions ~w(.png .jpg .jpeg .gif .webp)

  @impl Mix.Task
  def run(args) do
    {opts, paths, _} =
      OptionParser.parse(args,
        strict: [
          widths: :string,
          format: :string,
          quality: :integer,
          force: :boolean
        ]
      )

    if paths == [] do
      Mix.raise("Usage: mix phoenix_srcset.generate PATH [OPTIONS]")
    end

    generator_opts = build_generator_opts(opts)

    paths
    |> Enum.flat_map(&expand_path/1)
    |> Enum.each(fn path ->
      Mix.shell().info("Processing: #{path}")

      case PhoenixSrcset.Generator.generate(path, generator_opts) do
        {:ok, %{generated: generated, skipped: skipped}} ->
          Enum.each(generated, fn file ->
            size = File.stat!(file).size |> format_size()
            Mix.shell().info("  ✓ Generated: #{Path.basename(file)} (#{size})")
          end)

          Enum.each(skipped, fn file ->
            Mix.shell().info("  ○ Skipped: #{Path.basename(file)} (exists)")
          end)

        {:error, reason} ->
          Mix.shell().error("  ✗ Error: #{reason}")
      end
    end)
  end

  defp build_generator_opts(opts) do
    []
    |> maybe_add_widths(opts[:widths])
    |> maybe_add_opt(:format, opts[:format])
    |> maybe_add_opt(:quality, opts[:quality])
    |> maybe_add_opt(:force, opts[:force])
  end

  defp maybe_add_widths(acc, nil), do: acc

  defp maybe_add_widths(acc, widths_string) do
    widths =
      widths_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_integer/1)

    Keyword.put(acc, :widths, widths)
  end

  defp maybe_add_opt(acc, _key, nil), do: acc
  defp maybe_add_opt(acc, key, value), do: Keyword.put(acc, key, value)

  defp expand_path(path) do
    cond do
      File.dir?(path) ->
        path
        |> File.ls!()
        |> Enum.map(&Path.join(path, &1))
        |> Enum.filter(&is_source_image?/1)

      is_source_image?(path) ->
        [path]

      true ->
        Mix.shell().error("Skipping non-image file: #{path}")
        []
    end
  end

  defp is_source_image?(path) do
    ext = Path.extname(path) |> String.downcase()
    # Skip already generated variants
    ext in @image_extensions && !String.contains?(path, "_w.")
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"
end
