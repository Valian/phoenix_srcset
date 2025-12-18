defmodule PhoenixSrcset.Generator do
  @moduledoc """
  Generates responsive image variants using ImageMagick.
  """

  @doc """
  Generates image variants at specified widths.

  ## Options

  - `:widths` - List of widths to generate (default: from config or [400, 800, 1200, 1600])
  - `:format` - Output format (default: "webp")
  - `:quality` - Output quality 1-100 (default: 85)
  - `:force` - Regenerate even if variants exist (default: false)

  ## Returns

  - `{:ok, generated_files}` - List of generated file paths
  - `{:error, reason}` - Error message

  """
  def generate(source_path, opts \\ []) do
    widths = Keyword.get(opts, :widths, PhoenixSrcset.default_widths())
    format = Keyword.get(opts, :format, PhoenixSrcset.default_format())
    quality = Keyword.get(opts, :quality, PhoenixSrcset.default_quality())
    force = Keyword.get(opts, :force, false)

    with :ok <- check_imagemagick(),
         :ok <- check_source_exists(source_path),
         {:ok, source_width} <- get_image_width(source_path) do
      # Filter out widths larger than source
      valid_widths = Enum.filter(widths, &(&1 <= source_width))

      if valid_widths == [] do
        {:error, "Source image (#{source_width}px) is smaller than all requested widths"}
      else
        results =
          valid_widths
          |> Enum.map(fn width ->
            output_path = build_output_path(source_path, width, format)

            if force || !File.exists?(output_path) do
              generate_variant(source_path, output_path, width, quality)
            else
              {:skipped, output_path}
            end
          end)

        errors = Enum.filter(results, &match?({:error, _}, &1))

        if errors == [] do
          generated =
            results
            |> Enum.filter(&match?({:ok, _}, &1))
            |> Enum.map(fn {:ok, path} -> path end)

          skipped =
            results
            |> Enum.filter(&match?({:skipped, _}, &1))
            |> Enum.map(fn {:skipped, path} -> path end)

          {:ok, %{generated: generated, skipped: skipped}}
        else
          {:error, "Failed to generate some variants: #{inspect(errors)}"}
        end
      end
    end
  end

  defp check_imagemagick do
    case System.find_executable("convert") do
      nil -> {:error, "ImageMagick not found. Install with: brew install imagemagick"}
      _ -> :ok
    end
  end

  defp check_source_exists(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Source file not found: #{path}"}
    end
  end

  defp get_image_width(path) do
    case System.cmd("identify", ["-format", "%w", path], stderr_to_stdout: true) do
      {output, 0} ->
        case Integer.parse(String.trim(output)) do
          {width, _} -> {:ok, width}
          :error -> {:error, "Could not parse image width from: #{output}"}
        end

      {error, _} ->
        {:error, "Failed to identify image: #{error}"}
    end
  end

  defp build_output_path(source_path, width, format) do
    dir = Path.dirname(source_path)
    base = Path.basename(source_path, Path.extname(source_path))
    Path.join(dir, "#{base}_#{width}w.#{format}")
  end

  defp generate_variant(source_path, output_path, width, quality) do
    args = [
      source_path,
      "-resize",
      "#{width}x",
      "-quality",
      "#{quality}",
      "-strip",
      output_path
    ]

    case System.cmd("convert", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, output_path}
      {error, _} -> {:error, "Failed to convert #{source_path}: #{error}"}
    end
  end
end
