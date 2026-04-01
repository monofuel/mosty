## WebSocket connection with X509_V_FLAG_PARTIAL_CHAIN support.
##
## Separated into its own module to avoid the curly.Response vs
## httpclient.Response type conflict in the main mosty module.
##
## TODO: upstream a fix to Nim's std/net newContext() to support partial chain
## verification (or expose an option for it). We have merged PRs to Nim before
## and this is a reasonable enhancement.

import
  std/[asyncdispatch, base64, httpclient, net, openssl, random, strutils, uri],
  ws

const X509VFlagPartialChain = 0x80000.culong

proc SSL_CTX_get0_param(ctx: SslCtx): pointer
  {.cdecl, dynlib: DLLSSLName, importc.}

proc X509_VERIFY_PARAM_set_flags(param: pointer, flags: culong): cint
  {.cdecl, dynlib: DLLUtilName, importc.}

proc newWebSocketPartialChain*(url: string): Future[WebSocket] {.async.} =
  ## Create a WebSocket with X509_V_FLAG_PARTIAL_CHAIN enabled on the SSL context.
  ## This allows trusting intermediate CAs directly without a complete chain to a
  ## self-signed root.
  let ctx = newContext(verifyMode = CVerifyPeer)
  let param = SSL_CTX_get0_param(ctx.context)
  discard X509_VERIFY_PARAM_set_flags(param, X509VFlagPartialChain)
  var httpClient = newAsyncHttpClient(sslContext = ctx)

  var secStr = newString(16)
  for i in 0 ..< secStr.len:
    secStr[i] = char(rand(255))
  let secKey = base64.encode(secStr)

  httpClient.headers = newHttpHeaders({
    "Connection": "Upgrade",
    "Upgrade": "websocket",
    "Sec-WebSocket-Version": "13",
    "Sec-WebSocket-Key": secKey,
  })

  var parsed = parseUri(url)
  case parsed.scheme
  of "wss":
    parsed.scheme = "https"
  of "ws":
    parsed.scheme = "http"
  else:
    raise newException(WebSocketError, "Unsupported scheme: " & parsed.scheme)

  discard await httpClient.get($parsed)

  var wsObj = WebSocket()
  wsObj.masked = true
  wsObj.tcpSocket = httpClient.getSocket()
  wsObj.readyState = Open
  result = wsObj
