import
  std/[unittest, os, strutils, tables, times],
  ../src/mosty

proc loadDotEnv(path: string): Table[string, string] =
  result = initTable[string, string]()
  if path == "" or not fileExists(path): return
  for rawLine in readFile(path).splitLines():
    let line = rawLine.strip()
    if line.len == 0 or line.startsWith("#"): continue
    let eq = line.find('=')
    if eq <= 0: continue
    let key = line[0..<eq].strip()
    var value = line[eq+1..^1].strip()
    if value.len >= 2 and ((value.startsWith('"') and value.endsWith('"')) or (value.startsWith('\'') and value.endsWith('\''))):
      value = value[1..^2]
    result[key] = value

var
  baseUrl: string
  token: string
  testChannelId: string

proc ensureEnv() =
  if getEnv("MATTERMOST_URL", "") != "": return
  let kv = loadDotEnv(".env")
  for k, v in kv.pairs:
    if getEnv(k, "") == "":
      putEnv(k, v)
  baseUrl = getEnv("MATTERMOST_URL", "")
  token = getEnv("MATTERMOST_TOKEN", "")
  testChannelId = getEnv("MATTERMOST_TEST_CHANNEL", "")

suite "mosty":
  ensureEnv()

  test "user: get me":
    let client = newMostyClient(baseUrl, token)
    let me = client.getMe()
    check me.id.len > 0
    check me.username.len > 0
    client.close()

  test "post: create and delete":
    let client = newMostyClient(baseUrl, token)
    let post = client.createPost(testChannelId, "[mosty test] hello at " & $now())
    check post.id.len > 0
    check post.channel_id == testChannelId
    client.deletePost(post.id)
    client.close()

  test "post: list channel posts":
    let client = newMostyClient(baseUrl, token)
    let posts = client.getChannelPosts(testChannelId)
    check posts.order.len >= 0
    client.close()

  test "post: create and update":
    let client = newMostyClient(baseUrl, token)
    let post = client.createPost(testChannelId, "[mosty test] original at " & $now())
    check post.id.len > 0
    let updated = client.updatePost(post.id, "[mosty test] updated at " & $now())
    check updated.id == post.id
    client.deletePost(post.id)
    client.close()
