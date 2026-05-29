defmodule Qlock.Markdown do
  @moduledoc "Minimal markdown-to-HTML converter. No external dependencies."

  @doc "Convert markdown string to an HTML string. Safe — HTML in input is escaped."
  def to_html(nil), do: ""
  def to_html(""), do: ""

  def to_html(text) when is_binary(text) do
    text
    |> String.trim()
    |> String.split("\n")
    |> Enum.reduce({[], :none}, &process_line/2)
    |> then(fn {html, state} -> flush(state, html) end)
    |> then(fn {html, _} -> Enum.reverse(html) end)
    |> Enum.join("\n")
  end

  # --- Line processor (state machine) ---

  defp process_line(line, {html, state}) do
    trimmed = String.trim(line)

    cond do
      # Empty line → flush current block
      trimmed == "" ->
        {flushed, _} = flush(state, html)
        {flushed, :none}

      # Code fence toggle
      String.starts_with?(trimmed, "```") ->
        case state do
          {:code, lines} ->
            code = lines |> Enum.reverse() |> Enum.join("\n") |> escape_html()
            {["<pre><code>#{code}</code></pre>" | html], :none}

          _ ->
            {flushed, _} = flush(state, html)
            {flushed, {:code, []}}
        end

      # Inside code block — accumulate raw (no trimming)
      match?({:code, _}, state) ->
        {:code, lines} = state
        {html, {:code, [line | lines]}}

      # Headings — always start a new block
      String.starts_with?(trimmed, "#") ->
        {flushed, _} = flush(state, html)
        {level, text} = parse_heading(trimmed)
        {["<h#{level}>#{inline(text)}</h#{level}>" | flushed], :none}

      # Horizontal rule
      trimmed in ["---", "***", "___"] ->
        {flushed, _} = flush(state, html)
        {["<hr>" | flushed], :none}

      # Blockquote
      String.starts_with?(trimmed, "> ") ->
        content = String.slice(trimmed, 2..-1//1)

        case state do
          {:blockquote, lines} -> {html, {:blockquote, [content | lines]}}
          _ ->
            {flushed, _} = flush(state, html)
            {flushed, {:blockquote, [content]}}
        end

      # Unordered list
      Regex.match?(~r/^[-*] /, trimmed) ->
        item = String.slice(trimmed, 2..-1//1)

        case state do
          {:ul, items} -> {html, {:ul, [item | items]}}
          _ ->
            {flushed, _} = flush(state, html)
            {flushed, {:ul, [item]}}
        end

      # Ordered list
      Regex.match?(~r/^\d+\. /, trimmed) ->
        item = Regex.replace(~r/^\d+\. /, trimmed, "")

        case state do
          {:ol, items} -> {html, {:ol, [item | items]}}
          _ ->
            {flushed, _} = flush(state, html)
            {flushed, {:ol, [item]}}
        end

      # Paragraph — consecutive lines join with a space
      true ->
        case state do
          {:paragraph, lines} -> {html, {:paragraph, [trimmed | lines]}}
          _ ->
            {flushed, _} = flush(state, html)
            {flushed, {:paragraph, [trimmed]}}
        end
    end
  end

  # --- Block flushers ---

  defp flush(:none, html), do: {html, :none}

  defp flush({:paragraph, lines}, html) do
    text = lines |> Enum.reverse() |> Enum.join(" ")
    {["<p>#{inline(text)}</p>" | html], :none}
  end

  defp flush({:ul, items}, html) do
    lis = items |> Enum.reverse() |> Enum.map_join("", &"<li>#{inline(&1)}</li>")
    {["<ul>#{lis}</ul>" | html], :none}
  end

  defp flush({:ol, items}, html) do
    lis = items |> Enum.reverse() |> Enum.map_join("", &"<li>#{inline(&1)}</li>")
    {["<ol>#{lis}</ol>" | html], :none}
  end

  defp flush({:blockquote, lines}, html) do
    text = lines |> Enum.reverse() |> Enum.join(" ")
    {["<blockquote>#{inline(text)}</blockquote>" | html], :none}
  end

  defp flush({:code, lines}, html) do
    code = lines |> Enum.reverse() |> Enum.join("\n") |> escape_html()
    {["<pre><code>#{code}</code></pre>" | html], :none}
  end

  # --- Heading parser ---

  defp parse_heading(line) do
    case Regex.run(~r/^(#+)\s+(.+)$/, line) do
      [_, hashes, text] -> {min(String.length(hashes), 6), text}
      _ -> {1, String.trim_leading(line, "#")}
    end
  end

  # --- Inline formatting (applied AFTER html-escaping the input) ---

  defp inline(text) do
    text
    |> escape_html()
    |> apply_inline_code()
    |> apply_bold_italic()
    |> apply_bold()
    |> apply_italic()
    |> apply_strikethrough()
    |> apply_links()
  end

  defp apply_inline_code(t), do: Regex.replace(~r/`([^`]+)`/, t, "<code>\\1</code>")
  defp apply_bold_italic(t), do: Regex.replace(~r/\*\*\*(.+?)\*\*\*/, t, "<strong><em>\\1</em></strong>")
  defp apply_bold(t), do: Regex.replace(~r/\*\*(.+?)\*\*/, t, "<strong>\\1</strong>")
  defp apply_italic(t), do: Regex.replace(~r/\*(.+?)\*/, t, "<em>\\1</em>")
  defp apply_strikethrough(t), do: Regex.replace(~r/~~(.+?)~~/, t, "<del>\\1</del>")

  defp apply_links(t) do
    Regex.replace(~r/\[([^\]]+)\]\(([^)]+)\)/, t, fn _, label, url ->
      safe_url = if String.starts_with?(url, ["http://", "https://", "/"]), do: url, else: "#"
      "<a href=\"#{safe_url}\" target=\"_blank\" rel=\"noopener noreferrer\">#{label}</a>"
    end)
  end

  # --- HTML escape (prevents XSS) ---

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
