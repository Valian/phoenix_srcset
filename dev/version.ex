defmodule Mix.Tasks.Version do
  @shortdoc "Release a new version (bump, tag, publish)"
  @moduledoc """
  Releases a new version of the package.

  ## Usage

      mix version BUMP

  Where BUMP is one of:
    - `major` - Bump major version (X.0.0)
    - `minor` - Bump minor version (0.X.0)
    - `patch` - Bump patch version (0.0.X)
    - `X.Y.Z` - Set explicit version

  ## What it does

  1. Validates the repository is clean (no uncommitted changes)
  2. Validates new version is greater than current version
  3. Runs tests to ensure everything works
  4. Updates version in:
     - mix.exs (@version attribute)
     - README.md (dependency example)
     - CHANGELOG.md (replaces UNRELEASED or adds new entry)
  5. Creates git commit with version bump
  6. Creates git tag (vX.Y.Z)
  7. Pushes commit and tag to origin
  8. Creates GitHub release via `gh` CLI
  9. Publishes to Hex.pm

  ## Examples

      # Bump patch version (0.1.0 -> 0.1.1)
      mix version patch

      # Bump minor version (0.1.0 -> 0.2.0)
      mix version minor

      # Bump major version (0.1.0 -> 1.0.0)
      mix version major

      # Set explicit version
      mix version 2.0.0

  ## Options

      --dry-run    Show what would happen without making changes
      --skip-tests Skip running tests (not recommended)
      --yes        Skip confirmation prompt
  """

  use Mix.Task

  @mix_exs_path "mix.exs"
  @readme_path "README.md"
  @changelog_path "CHANGELOG.md"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [dry_run: :boolean, skip_tests: :boolean, yes: :boolean],
        aliases: [n: :dry_run, y: :yes]
      )

    dry_run? = Keyword.get(opts, :dry_run, false)
    skip_tests? = Keyword.get(opts, :skip_tests, false)
    auto_yes? = Keyword.get(opts, :yes, false)

    case args do
      [bump] ->
        do_release(bump, dry_run?, skip_tests?, auto_yes?)

      [] ->
        Mix.raise("Usage: mix version BUMP (major|minor|patch|X.Y.Z)")

      _ ->
        Mix.raise("Too many arguments. Usage: mix version BUMP")
    end
  end

  defp do_release(bump, dry_run?, skip_tests?, auto_yes?) do
    current_version = get_current_version()
    new_version = calculate_new_version(current_version, bump)

    Mix.shell().info([
      :cyan,
      "Releasing ",
      :bright,
      current_version,
      :reset,
      :cyan,
      " → ",
      :bright,
      :green,
      new_version,
      :reset
    ])

    if dry_run? do
      Mix.shell().info([:yellow, "\n[DRY RUN] No changes will be made\n"])
    end

    # Step 1: Check repo is clean
    step("Checking repository is clean", fn ->
      check_repo_clean()
    end)

    # Step 2: Validate version
    step("Validating version", fn ->
      validate_version_bump(current_version, new_version)
    end)

    # Step 3: Run tests (unless skipped)
    unless skip_tests? do
      step("Running tests", fn ->
        run_tests()
      end)
    end

    # Confirm before making changes
    unless auto_yes? or dry_run? do
      unless Mix.shell().yes?("\nProceed with release?") do
        Mix.raise("Aborted")
      end
    end

    # Step 4: Update version in files
    step("Updating mix.exs", fn ->
      update_mix_exs(new_version, dry_run?)
    end)

    step("Updating README.md", fn ->
      update_readme(new_version, dry_run?)
    end)

    step("Updating CHANGELOG.md", fn ->
      update_changelog(new_version, dry_run?)
    end)

    # Step 5: Git commit
    step("Creating git commit", fn ->
      git_commit(new_version, dry_run?)
    end)

    # Step 6: Git tag
    step("Creating git tag v#{new_version}", fn ->
      git_tag(new_version, dry_run?)
    end)

    # Step 7: Push to origin
    step("Pushing to origin", fn ->
      git_push(new_version, dry_run?)
    end)

    # Step 8: Create GitHub release
    step("Creating GitHub release", fn ->
      create_github_release(new_version, dry_run?)
    end)

    # Step 9: Publish to Hex
    step("Publishing to Hex.pm", fn ->
      publish_to_hex(dry_run?)
    end)

    Mix.shell().info([
      :green,
      :bright,
      "\n✓ Successfully released v#{new_version}!"
    ])
  end

  defp step(name, fun) do
    Mix.shell().info([:cyan, "→ ", :reset, name])

    case fun.() do
      :ok -> Mix.shell().info([:green, "  ✓ Done"])
      {:ok, _} -> Mix.shell().info([:green, "  ✓ Done"])
      {:error, reason} -> Mix.raise("Failed: #{reason}")
    end
  end

  defp get_current_version do
    config = Mix.Project.config()
    config[:version] || Mix.raise("Could not determine current version from mix.exs")
  end

  defp calculate_new_version(current, bump) do
    case Version.parse(current) do
      {:ok, %Version{major: major, minor: minor, patch: patch}} ->
        case bump do
          "major" -> "#{major + 1}.0.0"
          "minor" -> "#{major}.#{minor + 1}.0"
          "patch" -> "#{major}.#{minor}.#{patch + 1}"
          explicit -> validate_explicit_version(explicit)
        end

      :error ->
        Mix.raise("Current version '#{current}' is not valid semver")
    end
  end

  defp validate_explicit_version(version) do
    case Version.parse(version) do
      {:ok, _} -> version
      :error -> Mix.raise("Invalid version format: #{version}")
    end
  end

  defp validate_version_bump(current, new) do
    case {Version.parse(current), Version.parse(new)} do
      {{:ok, current_v}, {:ok, new_v}} ->
        if Version.compare(new_v, current_v) == :gt do
          :ok
        else
          Mix.raise("New version #{new} must be greater than current version #{current}")
        end

      _ ->
        Mix.raise("Invalid version format")
    end
  end

  defp check_repo_clean do
    case System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true) do
      {"", 0} ->
        :ok

      {output, 0} ->
        Mix.raise("Repository has uncommitted changes:\n#{output}\nCommit or stash them first.")

      {error, _} ->
        Mix.raise("Failed to check git status: #{error}")
    end
  end

  defp run_tests do
    Mix.shell().info("")

    case run_cmd("mix", ["test", "--color"], env: [{"MIX_ENV", "test"}]) do
      {:ok, 0} -> :ok
      {:ok, _} -> Mix.raise("Tests failed")
      {:error, reason} -> Mix.raise("Failed to run tests: #{reason}")
    end
  end

  defp collect_port_output(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        collect_port_output(port)

      {^port, {:exit_status, status}} ->
        {:ok, status}
    after
      300_000 ->
        Port.close(port)
        {:error, :timeout}
    end
  end

  # Run a command with streaming output and optional interactivity
  defp run_cmd(cmd, args, opts \\ []) do
    env = Keyword.get(opts, :env, [])
    interactive? = Keyword.get(opts, :interactive, false)

    if interactive? do
      # For interactive commands, use :os.cmd which connects to the TTY
      # or use Port with proper stdin handling
      run_interactive_cmd(cmd, args, env)
    else
      run_streaming_cmd(cmd, args, env)
    end
  end

  defp run_streaming_cmd(cmd, args, env) do
    executable = System.find_executable(cmd) || Mix.raise("Command not found: #{cmd}")

    port =
      Port.open({:spawn_executable, executable}, [
        :exit_status,
        :binary,
        :stderr_to_stdout,
        args: args,
        env: Enum.map(env, fn {k, v} -> {to_charlist(k), to_charlist(v)} end)
      ])

    collect_port_output(port)
  end

  defp run_interactive_cmd(cmd, args, env) do
    # Build command string for shell execution
    escaped_args = Enum.map(args, &escape_shell_arg/1)
    cmd_string = Enum.join([cmd | escaped_args], " ")

    # Set environment variables
    env_prefix =
      env
      |> Enum.map(fn {k, v} -> "#{k}=#{escape_shell_arg(v)}" end)
      |> Enum.join(" ")

    full_cmd = if env_prefix == "", do: cmd_string, else: "#{env_prefix} #{cmd_string}"

    # Use Mix.shell().cmd which handles TTY correctly
    case Mix.shell().cmd(full_cmd) do
      0 -> {:ok, 0}
      code -> {:ok, code}
    end
  end

  defp escape_shell_arg(arg) when is_binary(arg) do
    if String.contains?(arg, [" ", "\"", "'", "$", "`", "\\", "\n"]) do
      "'" <> String.replace(arg, "'", "'\\''") <> "'"
    else
      arg
    end
  end

  defp update_mix_exs(new_version, dry_run?) do
    content = File.read!(@mix_exs_path)

    # Match @version "X.Y.Z" pattern
    updated =
      Regex.replace(
        ~r/@version\s+"[^"]+"/,
        content,
        ~s(@version "#{new_version}")
      )

    if updated == content do
      Mix.raise("Could not find @version in mix.exs")
    end

    unless dry_run?, do: File.write!(@mix_exs_path, updated)
    :ok
  end

  defp update_readme(new_version, dry_run?) do
    content = File.read!(@readme_path)

    # Match {:phoenix_srcset, "~> X.Y.Z"} or {:phoenix_srcset, "~> X.Y"}
    updated =
      Regex.replace(
        ~r/\{:phoenix_srcset,\s*"~>\s*[\d.]+"\}/,
        content,
        ~s({:phoenix_srcset, "~> #{major_minor(new_version)}"})
      )

    unless dry_run?, do: File.write!(@readme_path, updated)
    :ok
  end

  defp major_minor(version) do
    case Version.parse(version) do
      {:ok, %Version{major: major, minor: minor}} -> "#{major}.#{minor}"
      _ -> version
    end
  end

  defp update_changelog(new_version, dry_run?) do
    content = File.read!(@changelog_path)
    today = Date.utc_today() |> Date.to_string()
    new_header = "## #{new_version} - #{today}"

    updated =
      cond do
        # Replace UNRELEASED with version and date
        String.contains?(content, "## UNRELEASED") ->
          String.replace(content, "## UNRELEASED", new_header)

        String.contains?(content, "## Unreleased") ->
          String.replace(content, "## Unreleased", new_header)

        # Add new entry after the marker comment
        String.contains?(content, "<!-- %% CHANGELOG_ENTRIES %% -->") ->
          String.replace(
            content,
            "<!-- %% CHANGELOG_ENTRIES %% -->",
            "<!-- %% CHANGELOG_ENTRIES %% -->\n\n#{new_header}\n\n- Release #{new_version}"
          )

        # Fallback: add after the header section (after semver line)
        true ->
          String.replace(
            content,
            ~r/(adheres to \[Semantic Versioning\].*?\n)/,
            "\\1\n#{new_header}\n\n- Release #{new_version}\n"
          )
      end

    unless dry_run?, do: File.write!(@changelog_path, updated)
    :ok
  end

  defp git_commit(new_version, dry_run?) do
    files = [@mix_exs_path, @readme_path, @changelog_path]

    unless dry_run? do
      case run_cmd("git", ["add" | files]) do
        {:ok, 0} -> :ok
        _ -> Mix.raise("Failed to stage files")
      end

      case run_cmd("git", ["commit", "-m", "Release v#{new_version}"]) do
        {:ok, 0} -> :ok
        _ -> Mix.raise("Failed to create commit")
      end
    end

    :ok
  end

  defp git_tag(new_version, dry_run?) do
    tag = "v#{new_version}"

    unless dry_run? do
      case run_cmd("git", ["tag", "-a", tag, "-m", "Release #{tag}"]) do
        {:ok, 0} -> :ok
        _ -> Mix.raise("Failed to create tag")
      end
    end

    :ok
  end

  defp git_push(new_version, dry_run?) do
    tag = "v#{new_version}"

    unless dry_run? do
      case run_cmd("git", ["push", "origin", "HEAD"]) do
        {:ok, 0} -> :ok
        _ -> Mix.raise("Failed to push commit")
      end

      case run_cmd("git", ["push", "origin", tag]) do
        {:ok, 0} -> :ok
        _ -> Mix.raise("Failed to push tag")
      end
    end

    :ok
  end

  defp create_github_release(new_version, dry_run?) do
    tag = "v#{new_version}"
    changelog_section = extract_changelog_section(new_version)

    unless dry_run? do
      args = [
        "release",
        "create",
        tag,
        "--title",
        tag,
        "--notes",
        changelog_section
      ]

      case run_cmd("gh", args) do
        {:ok, 0} -> :ok
        _ -> Mix.raise("Failed to create GitHub release")
      end
    end

    :ok
  end

  defp extract_changelog_section(version) do
    content = File.read!(@changelog_path)

    # Find the section for this version
    case Regex.run(
           ~r/## #{Regex.escape(version)}[^\n]*\n(.*?)(?=\n## |\z)/s,
           content
         ) do
      [_, section] -> String.trim(section)
      nil -> "Release #{version}"
    end
  end

  defp publish_to_hex(dry_run?) do
    unless dry_run? do
      # Interactive to allow password prompts if needed
      case run_cmd("mix", ["hex.publish"], interactive: true) do
        {:ok, 0} -> :ok
        _ -> Mix.raise("Failed to publish to Hex")
      end
    end

    :ok
  end
end
