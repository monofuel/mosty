# Mosty

- mosty is a nim API client library for mattermost
- it is kind of similar to guildy, the discord API library (../guildy)

- https://developers.mattermost.com/integrate/reference/bot-accounts/
- https://developers.mattermost.com/api-documentation/#tag/bots

## Example

```nim
import std/os, mosty

let client = newMostyClient(
  baseUrl = getEnv("MATTERMOST_URL"),
  token = getEnv("MATTERMOST_TOKEN")
)

let me = client.getMe()
echo "Logged in as: ", me.username

let post = client.createPost("channel-id", "Hello from mosty!")
echo "Posted: ", post.id

proc onPost(client: MostyClient, post: MattermostPost) {.gcsafe.} =
  echo post.user_id, ": ", post.message

client.startGateway(onPost = onPost)
```

## Dependencies

- Nim >= 2.0.0
- curly (HTTP client)
- jsony (JSON serialization)
- ws (WebSocket)

## Testing

- Set environment variables: `MATTERMOST_URL`, `MATTERMOST_TOKEN`, `MATTERMOST_TEST_CHANNEL`
- Run `make test`
