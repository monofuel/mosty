## Mosty — Mattermost API client library for Nim.
## Provides REST and WebSocket gateway access for bot accounts.

import
  std/[strformat, json, os, strutils, asyncdispatch, random, locks],
  curly, ws, jsony,
  mosty/models
export models

# -------------------------------
# Client

type
  MostyError* = object of CatchableError

  MostyClientObj* = object
    curly*: Curly
    lock*: Lock
    baseUrl*: string
    token*: string
    curlTimeout*: int
    meId*: string
    # Gateway
    ws*: ws.WebSocket
    running*: bool

  MostyClient* = ptr MostyClientObj

const
  DefaultCurlTimeout = 60 * 3
  DefaultMaxInFlight = 16

template sync*(a: Lock, body: untyped) =
  ## Acquire the lock, run the body, and release the lock.
  acquire(a)
  try:
    body
  finally:
    release(a)

proc newMostyClient*(
  baseUrl: string,
  token: string = "",
  maxInFlight: int = DefaultMaxInFlight,
  curlTimeout: int = DefaultCurlTimeout
): MostyClient =
  ## Create a new Mattermost API client.
  ## Uses the provided token, or falls back to MATTERMOST_TOKEN env var.
  var tokenVar = token
  if tokenVar == "":
    tokenVar = getEnv("MATTERMOST_TOKEN", "")
  if tokenVar == "":
    raise newException(MostyError, "Missing Mattermost token")
  randomize()
  result = cast[MostyClient](allocShared0(sizeof(MostyClientObj)))
  result.curly = newCurly(maxInFlight)
  initLock(result.lock)
  # Strip trailing slash and append /api/v4
  var cleanUrl = baseUrl
  if cleanUrl.endsWith("/"):
    cleanUrl = cleanUrl[0..^2]
  result.baseUrl = cleanUrl & "/api/v4"
  result.token = tokenVar
  result.curlTimeout = curlTimeout
  result.running = true

proc close*(client: MostyClient) =
  ## Clean up the Mattermost client.
  client.curly.close()
  deallocShared(client)

# -------------------------------
# REST helpers

proc get*(client: MostyClient, path: string): Response =
  ## Make a GET request to the Mattermost API.
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  client.lock.sync:
    headers["Authorization"] = "Bearer " & client.token
  let resp = client.curly.get(client.baseUrl & path, headers, client.curlTimeout)
  if resp.code != 200:
    raise newException(MostyError, &"mattermost error: {resp.code} {resp.body}")
  result = resp

proc post*(client: MostyClient, path: string, body: string): Response =
  ## Make a POST request to the Mattermost API.
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  client.lock.sync:
    headers["Authorization"] = "Bearer " & client.token
  let resp = client.curly.post(client.baseUrl & path, headers, body, client.curlTimeout)
  if resp.code notin [200, 201]:
    raise newException(MostyError, &"mattermost error: {resp.code} {resp.body}")
  result = resp

proc put*(client: MostyClient, path: string, body: string): Response =
  ## Make a PUT request to the Mattermost API.
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  client.lock.sync:
    headers["Authorization"] = "Bearer " & client.token
  let resp = client.curly.put(client.baseUrl & path, headers, body, client.curlTimeout)
  if resp.code != 200:
    raise newException(MostyError, &"mattermost error: {resp.code} {resp.body}")
  result = resp

proc delete*(client: MostyClient, path: string): Response =
  ## Make a DELETE request to the Mattermost API.
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  client.lock.sync:
    headers["Authorization"] = "Bearer " & client.token
  let resp = client.curly.delete(client.baseUrl & path, headers, client.curlTimeout)
  if resp.code notin [200, 204]:
    raise newException(MostyError, &"mattermost error: {resp.code} {resp.body}")
  result = resp

# -------------------------------
# Users

proc getMe*(client: MostyClient): MattermostUser =
  ## Get the authenticated user profile.
  let resp = client.get("/users/me")
  result = fromJson(resp.body, MattermostUser)

proc getMeId*(client: MostyClient): string =
  ## Return the cached authenticated user ID, fetching it once if needed.
  client.lock.sync:
    result = client.meId
  if result != "":
    return
  let me = client.getMe()
  client.lock.sync:
    client.meId = me.id
  result = me.id

proc getUser*(client: MostyClient, userId: string): MattermostUser =
  ## Get a user by ID.
  let resp = client.get(&"/users/{userId}")
  result = fromJson(resp.body, MattermostUser)

proc getUsersByIds*(client: MostyClient, userIds: seq[string]): seq[MattermostUser] =
  ## Get multiple users by their IDs.
  let body = toJson(userIds)
  let resp = client.post("/users/ids", body)
  result = fromJson(resp.body, seq[MattermostUser])

proc sendTyping*(client: MostyClient, channelId: string, parentId: string = "") =
  ## Publish a typing indicator in a channel or thread.
  let meId = client.getMeId()
  var body = %*{"channel_id": channelId}
  if parentId != "":
    body["parent_id"] = %parentId
  discard client.post(&"/users/{meId}/typing", $body)

# -------------------------------
# Teams

proc getTeamChannels*(client: MostyClient, teamId: string): seq[MattermostChannel] =
  ## Get the list of channels for a team.
  let resp = client.get(&"/teams/{teamId}/channels")
  result = fromJson(resp.body, seq[MattermostChannel])

proc getChannelByName*(client: MostyClient, teamId: string, channelName: string): MattermostChannel =
  ## Get a channel by its name within a team.
  let resp = client.get(&"/teams/{teamId}/channels/name/{channelName}")
  result = fromJson(resp.body, MattermostChannel)

# -------------------------------
# Channels

proc getChannel*(client: MostyClient, channelId: string): MattermostChannel =
  ## Get a channel by ID.
  let resp = client.get(&"/channels/{channelId}")
  result = fromJson(resp.body, MattermostChannel)

proc createDirectChannel*(client: MostyClient, userId: string): MattermostChannel =
  ## Create a direct message channel between the authenticated user and the given user.
  let myId = client.getMeId()
  let body = toJson(@[myId, userId])
  let resp = client.post("/channels/direct", body)
  result = fromJson(resp.body, MattermostChannel)

# -------------------------------
# Posts

proc getChannelPosts*(client: MostyClient, channelId: string, page: int = 0, perPage: int = 60): MattermostPostList =
  ## Get a page of posts from a channel.
  let resp = client.get(&"/channels/{channelId}/posts?page={page}&per_page={perPage}")
  result = fromJson(resp.body, MattermostPostList)

proc createPost*(client: MostyClient, channelId: string, message: string, rootId: string = ""): MattermostPost =
  ## Create a new post in a channel.
  var body = %*{
    "channel_id": channelId,
    "message": message,
  }
  if rootId != "":
    body["root_id"] = %rootId
  let resp = client.post("/posts", $body)
  result = fromJson(resp.body, MattermostPost)

proc getPost*(client: MostyClient, postId: string): MattermostPost =
  ## Get a post by ID.
  let resp = client.get(&"/posts/{postId}")
  result = fromJson(resp.body, MattermostPost)

proc updatePost*(client: MostyClient, postId: string, message: string): MattermostPost =
  ## Update a post's message.
  let body = %*{
    "id": postId,
    "message": message,
  }
  let resp = client.put(&"/posts/{postId}", $body)
  result = fromJson(resp.body, MattermostPost)

proc deletePost*(client: MostyClient, postId: string) =
  ## Delete a post by ID.
  discard client.delete(&"/posts/{postId}")

# -------------------------------
# Reactions

proc addReaction*(client: MostyClient, postId: string, emojiName: string): MattermostReaction =
  ## Add a reaction to a post.
  let myId = client.getMeId()
  let body = %*{
    "user_id": myId,
    "post_id": postId,
    "emoji_name": emojiName,
  }
  let resp = client.post("/reactions", $body)
  result = fromJson(resp.body, MattermostReaction)

proc removeReaction*(client: MostyClient, userId: string, postId: string, emojiName: string) =
  ## Remove a reaction from a post.
  discard client.delete(&"/users/{userId}/posts/{postId}/reactions/{emojiName}")

# -------------------------------
# Bots

proc createBot*(client: MostyClient, username: string, displayName: string = "", description: string = ""): MattermostBot =
  ## Create a new bot account.
  var body = %*{"username": username}
  if displayName != "":
    body["display_name"] = %displayName
  if description != "":
    body["description"] = %description
  let resp = client.post("/bots", $body)
  result = fromJson(resp.body, MattermostBot)

proc getBots*(client: MostyClient, page: int = 0, perPage: int = 60): seq[MattermostBot] =
  ## Get a paginated list of bots.
  let resp = client.get(&"/bots?page={page}&per_page={perPage}")
  result = fromJson(resp.body, seq[MattermostBot])

proc getBot*(client: MostyClient, botUserId: string): MattermostBot =
  ## Get a bot by its user ID.
  let resp = client.get(&"/bots/{botUserId}")
  result = fromJson(resp.body, MattermostBot)

proc updateBot*(client: MostyClient, botUserId: string, username: string, displayName: string = "", description: string = ""): MattermostBot =
  ## Update a bot account.
  var body = %*{"username": username}
  if displayName != "":
    body["display_name"] = %displayName
  if description != "":
    body["description"] = %description
  let resp = client.put(&"/bots/{botUserId}", $body)
  result = fromJson(resp.body, MattermostBot)

proc disableBot*(client: MostyClient, botUserId: string): MattermostBot =
  ## Disable a bot account.
  let resp = client.post(&"/bots/{botUserId}/disable", "{}")
  result = fromJson(resp.body, MattermostBot)

proc enableBot*(client: MostyClient, botUserId: string): MattermostBot =
  ## Enable a bot account.
  let resp = client.post(&"/bots/{botUserId}/enable", "{}")
  result = fromJson(resp.body, MattermostBot)

# -------------------------------
# Files

proc getFileInfo*(client: MostyClient, fileId: string): MattermostFileInfo =
  ## Get file metadata by ID.
  let resp = client.get(&"/files/{fileId}/info")
  result = fromJson(resp.body, MattermostFileInfo)

# -------------------------------
# Gateway (WebSocket)

type
  OnRawEvent* = proc(client: MostyClient, event: JsonNode) {.gcsafe.}
  OnPostEvent* = proc(client: MostyClient, post: MattermostPost) {.gcsafe.}
  OnReactionEvent* = proc(client: MostyClient, reaction: MattermostReaction) {.gcsafe.}

proc stop*(client: MostyClient) =
  ## Stop the gateway connection.
  client.running = false
  if client.ws != nil:
    try: client.ws.close() except CatchableError: discard

proc websocketUrl*(client: MostyClient): string =
  ## Derive the WebSocket URL from the REST base URL.
  var url = client.baseUrl.replace("/api/v4", "")
  if url.startsWith("https://"):
    url = "wss://" & url[8..^1]
  elif url.startsWith("http://"):
    url = "ws://" & url[7..^1]
  result = url & "/api/v4/websocket"

proc handleEvent*(
  client: MostyClient,
  event: JsonNode,
  onRaw: OnRawEvent,
  onPost: OnPostEvent,
  onReaction: OnReactionEvent
) =
  ## Dispatch a WebSocket event to the appropriate callback.
  if event.hasKey("seq_reply"):
    # Auth response or other reply, skip dispatch.
    return

  let eventType = if event.hasKey("event"): event["event"].getStr else: ""

  if eventType == "hello":
    discard
  elif eventType in ["posted", "post_edited", "post_deleted"]:
    if onPost != nil and event.hasKey("data") and event["data"].hasKey("post"):
      # Mattermost double-encodes: data.post is a JSON string.
      let postJson = event["data"]["post"].getStr
      let post = fromJson(postJson, MattermostPost)
      onPost(client, post)
  elif eventType in ["reaction_added", "reaction_removed"]:
    if onReaction != nil and event.hasKey("data") and event["data"].hasKey("reaction"):
      let reactionJson = event["data"]["reaction"].getStr
      let reaction = fromJson(reactionJson, MattermostReaction)
      onReaction(client, reaction)

  if onRaw != nil:
    onRaw(client, event)

proc eventLoop(
  client: MostyClient,
  wsClient: ws.WebSocket,
  onRaw: OnRawEvent,
  onPost: OnPostEvent,
  onReaction: OnReactionEvent
) {.async.} =
  ## Read WebSocket messages and dispatch events.
  while wsClient.readyState == ReadyState.Open and client.running:
    let packet = await wsClient.receiveStrPacket()
    if packet.len == 0:
      continue
    let event = parseJson(packet)
    client.handleEvent(event, onRaw, onPost, onReaction)

# Workaround: Nim's std/net newContext() does not set X509_V_FLAG_PARTIAL_CHAIN,
# so SSL verification fails when only an intermediate CA is in the trust store
# (no full chain to a self-signed root). This is common with internal PKI setups.
# The ws library creates its own SSL context internally via newAsyncHttpClient(),
# so we reimplement the WebSocket handshake in a separate module with a custom
# SSL context that has partial chain enabled.
#
# TODO: upstream a fix to Nim's std/net newContext() to support partial chain
# verification (or expose an option for it). We have merged PRs to Nim before
# and this is a reasonable enhancement.

import mosty/ws_partial_chain

var partialChainEnabled* = false

proc enablePartialChainVerification*() =
  ## Enable X509_V_FLAG_PARTIAL_CHAIN for WebSocket connections.
  ## Call this once at startup before calling startGateway.
  partialChainEnabled = true

proc connectWebSocket(url: string): Future[WebSocket] {.async.} =
  ## Create a WebSocket, using partial chain SSL when enabled.
  if partialChainEnabled:
    result = await newWebSocketPartialChain(url)
  else:
    result = await newWebSocket(url)

proc connectGateway(
  client: MostyClient,
  onRaw: OnRawEvent,
  onPost: OnPostEvent,
  onReaction: OnReactionEvent
) {.async.} =
  ## Establish a WebSocket connection and authenticate.
  let url = client.websocketUrl()
  echo "Connecting to Mattermost Gateway: ", url
  let wsClient = await connectWebSocket(url)
  client.ws = wsClient
  echo "Gateway connected"

  # Authenticate
  let authPayload = %*{
    "seq": 1,
    "action": "authentication_challenge",
    "data": {
      "token": client.token
    }
  }
  await wsClient.send($authPayload)

  await client.eventLoop(wsClient, onRaw, onPost, onReaction)
  try: wsClient.close() except CatchableError: discard

proc startGateway*(
  client: MostyClient,
  onRaw: OnRawEvent = nil,
  onPost: OnPostEvent = nil,
  onReaction: OnReactionEvent = nil
) =
  ## Blocking loop that maintains a gateway connection and auto-reconnects.
  while client.running:
    try:
      waitFor client.connectGateway(onRaw, onPost, onReaction)
    except WebSocketClosedError:
      echo "WebSocket closed; will reconnect"
      if client.running:
        sleep(1000)
    except CatchableError as e:
      echo "Gateway error: ", e.msg
      if client.running:
        sleep(3000)
