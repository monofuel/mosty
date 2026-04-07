import
  std/[unittest, json, options, tables, os],
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

suite "client: websocketUrl derivation":
  test "https becomes wss":
    let client = newMostyClient("https://mm.example.com", "test-token")
    check client.websocketUrl() == "wss://mm.example.com/api/v4/websocket"
    client.close()

  test "http becomes ws":
    let client = newMostyClient("http://mm.example.com", "test-token")
    check client.websocketUrl() == "ws://mm.example.com/api/v4/websocket"
    client.close()
