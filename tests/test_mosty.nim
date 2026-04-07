import
  std/[unittest, json, options, tables, os, strutils],
  mosty,
  jsony

suite "json: renameHook for MattermostChannel":
  test "type field maps to channel_type":
    let j = """{"id":"ch1","type":"O","display_name":"General"}"""
    let ch = fromJson(j, MattermostChannel)
    check ch.id == "ch1"
    check ch.channel_type == "O"
    check ch.display_name == "General"

  test "missing type field leaves channel_type empty":
    let j = """{"id":"ch2","display_name":"Other"}"""
    let ch = fromJson(j, MattermostChannel)
    check ch.id == "ch2"
    check ch.channel_type == ""

suite "json: renameHook for MattermostPost":
  test "type field maps to post_type":
    let j = """{"id":"p1","channel_id":"ch1","message":"hello","type":"system_join"}"""
    let p = fromJson(j, MattermostPost)
    check p.id == "p1"
    check p.post_type == "system_join"
    check p.message == "hello"

  test "optional fields deserialize":
    let j = """{"id":"p2","channel_id":"ch1","message":"","props":{"key":"val"},"file_ids":["f1","f2"]}"""
    let p = fromJson(j, MattermostPost)
    check p.props.isSome
    check p.file_ids == @["f1", "f2"]

  test "missing optional fields":
    let j = """{"id":"p3","channel_id":"ch1","message":"hi"}"""
    let p = fromJson(j, MattermostPost)
    check p.props.isNone
    check p.metadata.isNone
    check p.file_ids.len == 0

suite "json: renameHook for MattermostTeam":
  test "type field maps to team_type":
    let j = """{"id":"t1","name":"myteam","type":"O"}"""
    let t = fromJson(j, MattermostTeam)
    check t.id == "t1"
    check t.team_type == "O"

suite "json: dumpHook for MattermostChannel":
  test "toJson outputs type not channel_type":
    let ch = MattermostChannel(id: "ch1", channel_type: "O")
    let j = toJson(ch)
    check j.contains("\"type\"")
    check not j.contains("\"channel_type\"")
    check j.contains("\"O\"")

suite "json: dumpHook for MattermostPost":
  test "toJson outputs type not post_type":
    let p = MattermostPost(id: "p1", post_type: "system_join")
    let j = toJson(p)
    check j.contains("\"type\"")
    check not j.contains("\"post_type\"")
    check j.contains("\"system_join\"")

suite "json: dumpHook for MattermostTeam":
  test "toJson outputs type not team_type":
    let t = MattermostTeam(id: "t1", team_type: "O")
    let j = toJson(t)
    check j.contains("\"type\"")
    check not j.contains("\"team_type\"")
    check j.contains("\"O\"")

suite "json: MattermostPostList":
  test "deserialize post list with posts table":
    let j = """{"order":["p1","p2"],"posts":{"p1":{"id":"p1","channel_id":"ch1","message":"first"},"p2":{"id":"p2","channel_id":"ch1","message":"second"}}}"""
    let pl = fromJson(j, MattermostPostList)
    check pl.order == @["p1", "p2"]
    check pl.posts.len == 2
    check pl.posts["p1"].message == "first"

suite "json: MattermostUser":
  test "deserialize user":
    let j = """{"id":"u1","username":"testuser","email":"test@example.com","roles":"system_user"}"""
    let u = fromJson(j, MattermostUser)
    check u.id == "u1"
    check u.username == "testuser"
    check u.email == "test@example.com"
    check u.roles == "system_user"

suite "json: MattermostReaction":
  test "deserialize reaction":
    let j = """{"user_id":"u1","post_id":"p1","emoji_name":"thumbsup","create_at":1234567890}"""
    let r = fromJson(j, MattermostReaction)
    check r.user_id == "u1"
    check r.post_id == "p1"
    check r.emoji_name == "thumbsup"
    check r.create_at == 1234567890

suite "json: MattermostBot":
  test "deserialize bot":
    let j = """{"user_id":"b1","username":"mybot","display_name":"My Bot","description":"A test bot","owner_id":"u1"}"""
    let b = fromJson(j, MattermostBot)
    check b.user_id == "b1"
    check b.username == "mybot"
    check b.display_name == "My Bot"
    check b.owner_id == "u1"

suite "json: MattermostFileInfo":
  test "deserialize file info":
    let j = """{"id":"f1","name":"test.png","size":12345,"mime_type":"image/png","has_preview_image":true}"""
    let f = fromJson(j, MattermostFileInfo)
    check f.id == "f1"
    check f.name == "test.png"
    check f.size == 12345
    check f.mime_type == "image/png"
    check f.has_preview_image == true

suite "client: newMostyClient defaults":
  test "strips trailing slash from url":
    let client = newMostyClient("https://mm.example.com/", "test-token")
    check client.baseUrl == "https://mm.example.com/api/v4"
    client.close()

  test "appends api/v4 to clean url":
    let client = newMostyClient("https://mm.example.com", "test-token")
    check client.baseUrl == "https://mm.example.com/api/v4"
    client.close()

  test "falls back to MATTERMOST_TOKEN env var":
    putEnv("MATTERMOST_TOKEN", "env-token")
    let client = newMostyClient("https://mm.example.com")
    check client.token == "env-token"
    client.close()
    delEnv("MATTERMOST_TOKEN")

  test "raises on missing token":
    delEnv("MATTERMOST_TOKEN")
    expect MostyError:
      discard newMostyClient("https://mm.example.com", "")

suite "MostyError: exception type":
  test "can be raised and caught as CatchableError":
    var caught = false
    try:
      raise newException(MostyError, "test error")
    except CatchableError as e:
      caught = true
      check e.msg == "test error"
    check caught

  test "raises on empty url and token":
    expect MostyError:
      discard newMostyClient("", "")

suite "client: meId field":
  test "meId starts empty on new client":
    let client = newMostyClient("https://mm.example.com", "test-token")
    check client.meId == ""
    client.close()

suite "client: websocketUrl derivation":
  test "https becomes wss":
    let client = newMostyClient("https://mm.example.com", "test-token")
    check client.websocketUrl() == "wss://mm.example.com/api/v4/websocket"
    client.close()

  test "http becomes ws":
    let client = newMostyClient("http://mm.example.com", "test-token")
    check client.websocketUrl() == "ws://mm.example.com/api/v4/websocket"
    client.close()

suite "handleEvent: dispatch logic":
  test "seq_reply skips all callbacks":
    let client = newMostyClient("https://mm.example.com", "test-token")
    var rawCalled = false
    let event = parseJson("""{"seq_reply":1,"status":"OK"}""")
    client.handleEvent(
      event,
      proc(c: MostyClient, e: JsonNode) {.gcsafe.} =
        {.cast(gcsafe).}: rawCalled = true,
      nil,
      nil
    )
    check not rawCalled
    client.close()

  test "hello event calls onRaw only":
    let client = newMostyClient("https://mm.example.com", "test-token")
    var rawCalled = false
    var postCalled = false
    let event = parseJson("""{"event":"hello","data":{}}""")
    client.handleEvent(
      event,
      proc(c: MostyClient, e: JsonNode) {.gcsafe.} =
        {.cast(gcsafe).}: rawCalled = true,
      proc(c: MostyClient, p: MattermostPost) {.gcsafe.} =
        {.cast(gcsafe).}: postCalled = true,
      nil
    )
    check rawCalled
    check not postCalled
    client.close()

  test "posted event calls onPost then onRaw":
    let client = newMostyClient("https://mm.example.com", "test-token")
    var order: seq[string]
    let postData = %*{"id": "p1", "channel_id": "ch1", "message": "hi"}
    let event = %*{"event": "posted", "data": {"post": $postData}}
    client.handleEvent(
      event,
      proc(c: MostyClient, e: JsonNode) {.gcsafe.} =
        {.cast(gcsafe).}: order.add("raw"),
      proc(c: MostyClient, p: MattermostPost) {.gcsafe.} =
        {.cast(gcsafe).}:
          check p.id == "p1"
          check p.message == "hi"
          order.add("post"),
      nil
    )
    check order == @["post", "raw"]
    client.close()

  test "post_edited dispatches like posted":
    let client = newMostyClient("https://mm.example.com", "test-token")
    var postCalled = false
    let postData = %*{"id": "p2", "channel_id": "ch1", "message": "edited"}
    let event = %*{"event": "post_edited", "data": {"post": $postData}}
    client.handleEvent(
      event,
      nil,
      proc(c: MostyClient, p: MattermostPost) {.gcsafe.} =
        {.cast(gcsafe).}:
          check p.id == "p2"
          postCalled = true,
      nil
    )
    check postCalled
    client.close()

  test "post_deleted dispatches like posted":
    let client = newMostyClient("https://mm.example.com", "test-token")
    var postCalled = false
    let postData = %*{"id": "p3", "channel_id": "ch1", "message": ""}
    let event = %*{"event": "post_deleted", "data": {"post": $postData}}
    client.handleEvent(
      event,
      nil,
      proc(c: MostyClient, p: MattermostPost) {.gcsafe.} =
        {.cast(gcsafe).}:
          check p.id == "p3"
          postCalled = true,
      nil
    )
    check postCalled
    client.close()

  test "reaction_added calls onReaction then onRaw":
    let client = newMostyClient("https://mm.example.com", "test-token")
    var order: seq[string]
    let reactionData = %*{"user_id": "u1", "post_id": "p1", "emoji_name": "thumbsup", "create_at": 0}
    let event = %*{"event": "reaction_added", "data": {"reaction": $reactionData}}
    client.handleEvent(
      event,
      proc(c: MostyClient, e: JsonNode) {.gcsafe.} =
        {.cast(gcsafe).}: order.add("raw"),
      nil,
      proc(c: MostyClient, r: MattermostReaction) {.gcsafe.} =
        {.cast(gcsafe).}:
          check r.emoji_name == "thumbsup"
          order.add("reaction")
    )
    check order == @["reaction", "raw"]
    client.close()

  test "reaction_removed dispatches like reaction_added":
    let client = newMostyClient("https://mm.example.com", "test-token")
    var reactionCalled = false
    let reactionData = %*{"user_id": "u1", "post_id": "p1", "emoji_name": "heart", "create_at": 0}
    let event = %*{"event": "reaction_removed", "data": {"reaction": $reactionData}}
    client.handleEvent(
      event,
      nil,
      nil,
      proc(c: MostyClient, r: MattermostReaction) {.gcsafe.} =
        {.cast(gcsafe).}:
          check r.emoji_name == "heart"
          reactionCalled = true
    )
    check reactionCalled
    client.close()

  test "unknown event type calls onRaw only":
    let client = newMostyClient("https://mm.example.com", "test-token")
    var rawCalled = false
    var postCalled = false
    let event = parseJson("""{"event":"user_updated","data":{}}""")
    client.handleEvent(
      event,
      proc(c: MostyClient, e: JsonNode) {.gcsafe.} =
        {.cast(gcsafe).}: rawCalled = true,
      proc(c: MostyClient, p: MattermostPost) {.gcsafe.} =
        {.cast(gcsafe).}: postCalled = true,
      nil
    )
    check rawCalled
    check not postCalled
    client.close()

  test "nil onPost with posted event does not crash, onRaw still called":
    let client = newMostyClient("https://mm.example.com", "test-token")
    var rawCalled = false
    let postData = %*{"id": "p4", "channel_id": "ch1", "message": "safe"}
    let event = %*{"event": "posted", "data": {"post": $postData}}
    client.handleEvent(
      event,
      proc(c: MostyClient, e: JsonNode) {.gcsafe.} =
        {.cast(gcsafe).}: rawCalled = true,
      nil,
      nil
    )
    check rawCalled
    client.close()

suite "json: seq[MattermostUser]":
  test "deserializes array of users":
    let j = """[{"id":"u1","username":"alice","email":"alice@example.com","roles":"system_user"},{"id":"u2","username":"bob","email":"bob@example.com","roles":"system_admin"}]"""
    let users = fromJson(j, seq[MattermostUser])
    check users.len == 2
    check users[0].id == "u1"
    check users[0].username == "alice"
    check users[1].id == "u2"
    check users[1].username == "bob"

suite "json: seq[MattermostChannel]":
  test "deserializes array of channels with renameHook":
    let j = """[{"id":"ch1","type":"O","display_name":"General"},{"id":"ch2","type":"P","display_name":"Private"}]"""
    let channels = fromJson(j, seq[MattermostChannel])
    check channels.len == 2
    check channels[0].id == "ch1"
    check channels[0].channel_type == "O"
    check channels[1].id == "ch2"
    check channels[1].channel_type == "P"

suite "json: seq[MattermostBot]":
  test "deserializes array of bots":
    let j = """[{"user_id":"b1","username":"bot1","display_name":"Bot One","owner_id":"u1"},{"user_id":"b2","username":"bot2","display_name":"Bot Two","owner_id":"u2"}]"""
    let bots = fromJson(j, seq[MattermostBot])
    check bots.len == 2
    check bots[0].user_id == "b1"
    check bots[0].username == "bot1"
    check bots[0].display_name == "Bot One"
    check bots[1].user_id == "b2"
    check bots[1].display_name == "Bot Two"

suite "round-trip: MattermostChannel":
  test "round-trip MattermostChannel preserves type field":
    let orig = MattermostChannel(id: "ch1", team_id: "t1", channel_type: "O", display_name: "General", name: "general")
    let rt = fromJson(toJson(orig), MattermostChannel)
    check rt.id == orig.id
    check rt.team_id == orig.team_id
    check rt.channel_type == orig.channel_type
    check rt.display_name == orig.display_name
    check rt.name == orig.name

suite "round-trip: MattermostPost":
  test "round-trip MattermostPost without optional fields":
    let orig = MattermostPost(id: "p1", channel_id: "ch1", user_id: "u1", message: "hello", post_type: "system_join", props: none(JsonNode), metadata: none(JsonNode))
    let rt = fromJson(toJson(orig), MattermostPost)
    check rt.id == orig.id
    check rt.channel_id == orig.channel_id
    check rt.user_id == orig.user_id
    check rt.message == orig.message
    check rt.post_type == orig.post_type
    check rt.props.isNone
    check rt.metadata.isNone

  test "round-trip MattermostPost with optional fields":
    let propsNode = %*{"key": "val"}
    let metaNode = %*{"images": {}}
    let orig = MattermostPost(id: "p2", channel_id: "ch1", message: "hi", file_ids: @["f1", "f2"], props: some(propsNode), metadata: some(metaNode))
    let rt = fromJson(toJson(orig), MattermostPost)
    check rt.id == orig.id
    check rt.message == orig.message
    check rt.file_ids == @["f1", "f2"]
    check rt.props.isSome
    check rt.metadata.isSome

suite "round-trip: MattermostTeam":
  test "round-trip MattermostTeam preserves type field":
    let orig = MattermostTeam(id: "t1", display_name: "My Team", name: "myteam", team_type: "O")
    let rt = fromJson(toJson(orig), MattermostTeam)
    check rt.id == orig.id
    check rt.display_name == orig.display_name
    check rt.name == orig.name
    check rt.team_type == orig.team_type

suite "round-trip: MattermostPostList":
  test "round-trip MattermostPostList with posts table":
    var orig = MattermostPostList()
    orig.order = @["p1", "p2"]
    orig.posts = {"p1": MattermostPost(id: "p1", channel_id: "ch1", message: "first"), "p2": MattermostPost(id: "p2", channel_id: "ch1", message: "second")}.toTable
    let rt = fromJson(toJson(orig), MattermostPostList)
    check rt.order == @["p1", "p2"]
    check rt.posts.len == 2
    check rt.posts["p1"].message == "first"
    check rt.posts["p2"].message == "second"

suite "round-trip: MattermostUser":
  test "round-trip MattermostUser":
    let orig = MattermostUser(id: "u1", username: "alice", email: "alice@example.com", roles: "system_user")
    let rt = fromJson(toJson(orig), MattermostUser)
    check rt.id == orig.id
    check rt.username == orig.username
    check rt.email == orig.email
    check rt.roles == orig.roles

suite "round-trip: MattermostReaction":
  test "round-trip MattermostReaction":
    let orig = MattermostReaction(user_id: "u1", post_id: "p1", emoji_name: "thumbsup", create_at: 1234567890)
    let rt = fromJson(toJson(orig), MattermostReaction)
    check rt.user_id == orig.user_id
    check rt.post_id == orig.post_id
    check rt.emoji_name == orig.emoji_name
    check rt.create_at == orig.create_at

suite "round-trip: MattermostBot":
  test "round-trip MattermostBot":
    let orig = MattermostBot(user_id: "b1", username: "mybot", display_name: "My Bot", description: "A test bot", owner_id: "u1")
    let rt = fromJson(toJson(orig), MattermostBot)
    check rt.user_id == orig.user_id
    check rt.username == orig.username
    check rt.display_name == orig.display_name
    check rt.description == orig.description
    check rt.owner_id == orig.owner_id

suite "round-trip: MattermostFileInfo":
  test "round-trip MattermostFileInfo":
    let orig = MattermostFileInfo(id: "f1", name: "test.png", size: 12345, mime_type: "image/png", has_preview_image: true)
    let rt = fromJson(toJson(orig), MattermostFileInfo)
    check rt.id == orig.id
    check rt.name == orig.name
    check rt.size == orig.size
    check rt.mime_type == orig.mime_type
    check rt.has_preview_image == orig.has_preview_image
