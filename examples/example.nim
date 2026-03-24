import
  std/[os],
  ../src/mosty

let client = newMostyClient(
  baseUrl = getEnv("MATTERMOST_URL"),
  token = getEnv("MATTERMOST_TOKEN")
)

let me = client.getMe()
echo "Logged in as: ", me.username

let channelId = getEnv("MATTERMOST_TEST_CHANNEL")
let post = client.createPost(channelId, "Hello from mosty!")
echo "Posted message: ", post.id

proc onPost(client: MostyClient, post: MattermostPost) {.gcsafe.} =
  echo "[", post.channel_id, "] ", post.user_id, ": ", post.message

echo "Starting gateway..."
client.startGateway(onPost = onPost)
