defmodule Bamboo.PostmarkAdapter do
  @moduledoc """
  Sends email using Postmarks's API.

  Use this adapter to send emails through Postmark's API. Requires that an API
  key is set in the config.

  ## Example

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.PostmarkAdapter,
        api_key: "my_api_key" or {:system, "POSTMARK_API_KEY"}

  """

  @behaviour Bamboo.Adapter

  @default_base_uri "https://api.postmarkapp.com"
  @send_email_path "email"
  @send_email_template_path "email/withTemplate"

  defmodule Error do
    @moduledoc """
    Custom error struct for Postmark API errors.
    """
    defexception [:reason, :email]

    def is_hard_bounce(%{reason: %{"ErrorCode" => 406}}), do: true
    def is_hard_bounce(_), do: false

    def message(%{reason: reason}) do
      "delivery error: #{inspect(reason)}"
    end
  end

  def deliver(email, config) do
    api_key = get_key(config)
    params = email |> convert_to_postmark_params() |> json_library().encode!()
    uri = [base_uri(), "/", api_path(email)]

    case :hackney.post(uri, headers(api_key), params, options(config)) do
      {:ok, status, _headers, response} when status > 299 ->
        error =
          case Jason.decode(response) do
            {:ok, reason} ->
              # if the response is JSON, we return our custom error for better introspection
              Bamboo.PostmarkAdapter.Error.exception(reason: reason, email: email)

            {:error, _} ->
              Bamboo.ApiError.build_api_error("Postmark", response, params)
          end

        {:error, error}

      {:ok, status, headers, response} ->
        {:ok, %{status_code: status, headers: headers, body: response}}

      {:error, reason} ->
        {:error, Bamboo.ApiError.build_api_error("Postmark", reason, params)}
    end
  end

  def handle_config(config) do
    # build the api key - will raise if there are errors
    Map.merge(config, %{api_key: get_key(config)})
  end

  @doc false
  def supports_attachments?, do: true

  defp get_key(config) do
    api_key =
      case Map.get(config, :api_key) do
        {:system, var} -> System.get_env(var)
        key -> key
      end

    if api_key in [nil, ""] do
      raise_api_key_error(config)
    else
      api_key
    end
  end

  def json_library do
    Bamboo.json_library()
  end

  defp raise_api_key_error(config) do
    raise ArgumentError, """
    There was no API key set for the Postmark adapter.
    * Here are the config options that were passed in:
    #{inspect(config)}
    """
  end

  defp convert_to_postmark_params(email) do
    email
    |> email_params()
    |> maybe_put_template_params(email)
    |> maybe_put_tag_params(email)
    |> maybe_put_attachments(email)
  end

  def maybe_put_attachments(params, %{attachments: []}) do
    params
  end

  def maybe_put_attachments(params, %{attachments: attachments}) do
    params
    |> Map.put(
      :Attachments,
      Enum.map(attachments, fn attachment ->
        %{
          Name: attachment.filename,
          Content: attachment.data |> Base.encode64(),
          ContentType: attachment.content_type,
          ContentId: attachment.content_id
        }
      end)
    )
  end

  defp maybe_put_template_params(params, %{
         private: %{template_id: template_name, template_model: template_model}
       }) do
    params
    |> Map.put(:TemplateId, template_name)
    |> Map.put(:TemplateModel, template_model)
    |> Map.put(:InlineCss, true)
  end

  defp maybe_put_template_params(params, _) do
    params
  end

  defp maybe_put_tag_params(params, %{private: %{tag: tag}}) do
    Map.put(params, :Tag, tag)
  end

  defp maybe_put_tag_params(params, _) do
    params
  end

  defp email_params(email) do
    recipients = recipients(email)

    add_message_params(
      %{
        From: email_from(email),
        To: recipients_to_string(recipients, "To"),
        Cc: recipients_to_string(recipients, "Cc"),
        Bcc: recipients_to_string(recipients, "Bcc"),
        Subject: email.subject,
        TextBody: email.text_body,
        HtmlBody: email.html_body,
        Headers: email_headers(email),
        TrackOpens: true
      },
      email
    )
  end

  defp add_message_params(params, %{private: %{message_params: message_params}}) do
    Enum.reduce(message_params, params, fn {key, value}, params ->
      Map.put(params, key, value)
    end)
  end

  defp add_message_params(params, _), do: params

  defp email_from(email) do
    name = elem(email.from, 0)
    email = elem(email.from, 1)
    encode_name_and_email(name, email)
  end

  defp email_headers(email) do
    Enum.map(
      email.headers,
      fn {header, value} -> %{Name: header, Value: value} end
    )
  end

  defp recipients(email) do
    []
    |> add_recipients(email.to, type: "To")
    |> add_recipients(email.cc, type: "Cc")
    |> add_recipients(email.bcc, type: "Bcc")
  end

  defp add_recipients(recipients, new_recipients, type: recipient_type) do
    Enum.reduce(new_recipients, recipients, fn recipient, recipients ->
      recipients ++
        [
          %{
            name: elem(recipient, 0),
            email: elem(recipient, 1),
            type: recipient_type
          }
        ]
    end)
  end

  defp recipients_to_string(recipients, type) do
    recipients
    |> Enum.filter(fn recipient -> recipient[:type] == type end)
    |> Enum.map_join(",", &encode_name_and_email(&1.name, &1.email))
  end

  defp encode_name_and_email(name, email) do
    encoded =
      if name do
        name = String.replace(name, ~s("), ~s(\\"))
        ~s("#{name}" <#{email}>)
      else
        email
      end

    String.trim(encoded)
  end

  defp headers(api_key) do
    [
      {"accept", "application/json"},
      {"content-type", "application/json"},
      {"x-postmark-server-token", api_key}
    ]
  end

  defp api_path(%{private: %{template_id: _}}), do: @send_email_template_path
  defp api_path(_), do: @send_email_path

  defp base_uri do
    Application.get_env(:bamboo, :postmark_base_uri) || @default_base_uri
  end

  defp options(config) do
    Keyword.merge(config[:request_options] || [], with_body: true)
  end
end
