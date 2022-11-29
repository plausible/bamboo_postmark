# bamboo_postmark

[Postmark](https://postmarkapp.com/) adapter for the [Bamboo](https://github.com/thoughtbot/bamboo) e-mail library.

## Installation

The package can be installed by adding `:bamboo_postmark` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bamboo, github: "thoughtbot/bamboo"},
    {:bamboo_postmark, github: "plausible/bamboo_postmark"}
  ]
end
```

Add your Postmark API key to your config. You can find this key as `Server API
token` under the `Credentials` tab in each Postmark server.

```elixir
config :my_app, MyApp.Mailer,
      adapter: Bamboo.PostmarkAdapter,
      api_key: "my_api_key"
      # Or if you want to use an ENV variable:
      # api_key: {:system, "POSTMARK_API_KEY"}
```

## Examples

### Using templates

The Postmark adapter provides a helper module for setting the template of an
email.

```elixir
defmodule MyApp.Mail do
  import Bamboo.PostmarkHelper

  def some_email do
    template(
      email,
      "id_of_template",
      %{name: "John Doe", confirm_link: "http://www.link.com"}
    )
  end
end
```

### Exception warning

Postmark templates include a subject, HTML body and text body and thus these shouldn't be included in the email as they will raise an API exception.

```elixir
email
|> template("id", %{value: "Some value"})
|> subject("Will raise exception")
|> html_body("<p>Will raise exception</p>")
|> text_body("Will raise exception")
```

### Tagging emails

The Postmark adapter provides a helper module for tagging emails.

```elixir
defmodule MyApp.Mail do
  import Bamboo.PostmarkHelper

  def some_email do
    tag(email, "some-tag")
  end
end
```

### Sending extra parameters

You can send other extra parameters to Postmark with the `put_param` helper.

See Postmark's API for a complete list of parameters supported.

```elixir
email
|> put_param("TrackLinks", "HtmlAndText")
|> put_param("TrackOpens", true)
|> put_param("Attachments", [
  %{
    Name: "file.txt",
    Content: "/some/file.txt" |> File.read!() |> Base.encode64(),
    ContentType: "txt"
  }
])
```

### Changing the underlying request configuration

You can specify the options that are passed to the underlying HTTP client
[hackney](https://github.com/benoitc/hackney) by using the `request_options` key
in the configuration.

```elixir
config :my_app, MyApp.Mailer,
      adapter: Bamboo.PostmarkAdapter,
      api_key: "my_api_key",
      request_options: [recv_timeout: 10_000]
```

### JSON support

Bamboo comes with JSON support out of the box, see [Bamboo JSON support](https://github.com/thoughtbot/bamboo#json-support).

## Fork

This repository is a fork of [pablo-co/bamboo_postmark](https://github.com/pablo-co/bamboo_postmark). We've decided to fork because upstream didn't seem to be under active development. The main reason was that sender/recipient names were not encoded properly, [and despite issues and open pull requests](https://github.com/pablo-co/bamboo_postmark/issues/32), the bug wasn't fixed timely.
