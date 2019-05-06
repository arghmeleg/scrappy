defmodule Scrappy do
  alias Scrappy.Session

  defp debug(data) do
    if(Application.get_env(:scrappy, :verbose, true), do: IO.puts(data))
  end

  def element_attribute(html, attribute) do
    html
    |> Floki.attribute(attribute)
    |> List.first()
  end

  def find_element(html, css) do
    html
    |> Floki.find(css)
    |> List.first()
  end

  defp save_dir do
    Application.get_env(:scrappy, :save_dir, "save")
  end

  defp local_asset_ref(asset_url) do
    asset_url
    |> local_asset_name()
    |> String.trim_leading("#{save_dir()}/")
  end

  def save(session, body_mutator) do
    index_filename = Path.join(save_dir(), htmlize("#{session.url.path}?#{session.url.query}"))
    File.mkdir_p(save_dir())

    local_body =
      session.body
      |> body_mutator.()
      |> Floki.attr("link[rel='stylesheet']", "href", &local_asset_ref/1)
      |> Floki.attr("img[src]", "src", &local_asset_ref/1)
      |> Floki.attr("script[src]", "src", &local_asset_ref/1)
      |> Floki.raw_html()

    File.write(index_filename, local_body)

    css_urls =
      session.body
      |> Floki.find("link[rel='stylesheet']")
      |> Enum.map(fn link -> element_attribute(link, "href") end)

    img_urls =
      session.body
      |> Floki.find("img[src]")
      |> Enum.map(fn img -> element_attribute(img, "src") end)

    js_urls =
      session.body
      |> Floki.find("script[src]")
      |> Enum.map(fn script -> element_attribute(script, "src") end)

    (css_urls ++ img_urls ++ js_urls)
    |> Enum.each(fn asset_url -> save_asset(session, asset_url) end)
  end

  defp local_asset_name(asset_url) do
    uri = URI.parse(asset_url)

    extname =
      if Path.extname(uri.path) == "" do
        Path.extname(uri.query)
      else
        Path.extname(uri.path)
      end

    local_path =
      if uri.query do
        "#{uri.path}?#{uri.query}"
      else
        uri.path
      end

    local_path =
      local_path
      |> String.replace(~r/[^\w\/]+/, "-")
      |> String.replace(~r/\s+/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim_trailing(String.replace(extname, ".", ""))
      |> String.trim("-")
      |> Kernel.<>(extname)

    local_path =
      if local_path =~ "/" do
        local_path
      else
        local_path
        |> Path.extname()
        |> String.replace(".", "")
        |> Path.join(local_path)
      end

    Path.join(save_dir(), local_path)
  end

  def save_asset(session, asset_url) do
    local_filename = local_asset_name(asset_url)

    if !File.exists?(local_filename) do
      session = go_to(session, asset_url)

      if session.status != :error do
        File.mkdir_p(Path.dirname(local_filename))
        File.write(local_filename, session.body)

        if asset_url =~ ".css" do
          save_css_assets(session)
        end
      else
        debug("ERROR SAVING ASSET")
      end
    end
  end

  defp save_css_assets(session) do
    asset_urls =
      Regex.scan(~r/url\(['"]?(?<file>.*)['"]?\)/Um, session.body, capture: :all_names) || []

    dir_name = URI.parse(session.url).path |> Path.dirname()

    asset_urls
    |> Enum.each(fn [asset_url] ->
      asset_url = String.trim(asset_url, "'")
      asset_path = dir_name |> Path.join(asset_url) |> Path.expand() |> Path.relative_to_cwd()

      try do
        save_asset(session, asset_path)
      rescue
        _e ->
          debug("UNFETCHABLE #{asset_path}")
      end
    end)
  end

  defp htmlize(string) do
    string
    |> String.replace(~r/\W/, "-")
    |> String.trim("-")
    |> Kernel.<>(".html")
  end

  def go_to(url), do: go_to(%Session{}, url)

  def go_to(session, url) do
    url =
      session.url
      |> URI.merge(URI.parse(url))
      |> to_string()
      |> String.replace(" ", "%20")

    debug(to_string(url))

    response = HTTPoison.get!(url, %{}, hackney: [cookie: Enum.join(session.cookies, "; ")])
    session = %{session | url: URI.parse(url), body: response.body, status: nil}

    append_cookies_and_follow_redirect(session, response)
  end

  def submit_form(session, css, form_data \\ %{}) do
    form = Floki.find(session.body, css)
    form_action = form |> Floki.attribute("action") |> List.first() |> URI.parse()
    form_url = URI.merge(session.url, form_action)

    form_inputs =
      form
      |> Floki.find("input")
      |> Enum.into(%{}, &parse_input/1)
      |> Map.merge(form_data)
      |> URI.encode_query()

    response =
      HTTPoison.post!(form_url, form_inputs, %{
        "Content-Type" => "application/x-www-form-urlencoded"
      })

    session = %{session | url: form_url, body: response.body}

    append_cookies_and_follow_redirect(session, response)
  end

  defp parse_input(input) do
    name = input |> Floki.attribute("name") |> List.first()
    value = input |> Floki.attribute("value") |> List.first()
    {name, value}
  end

  defp append_cookies_and_follow_redirect(session, response) do
    append_cookies_and_follow_redirect(session, response, to_string(response.status_code))
  end

  defp append_cookies_and_follow_redirect(session, response, "2" <> _ok) do
    append_cookies(session, response)
  end

  defp append_cookies_and_follow_redirect(session, response, "3" <> _redirect) do
    session = append_cookies(session, response)

    location =
      Enum.find_value(response.headers, fn {name, value} -> name == "Location" && value end)

    if(to_string(session.url) == location, do: raise("Circular redirect"))
    go_to(session, location)
  end

  defp append_cookies_and_follow_redirect(session, _response, _error) do
    %{session | status: :error}
  end

  defp append_cookies(session, response) do
    cookies =
      response.headers
      |> Enum.filter(fn {header, _value} -> header == "Set-Cookie" end)
      |> Enum.map(fn {_header, value} ->
        value |> String.split(" ") |> List.first() |> String.trim(";")
      end)

    %{session | cookies: Enum.uniq(session.cookies ++ cookies)}
  end
end
