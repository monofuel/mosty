import
  std/[asyncnet, unittest]

include ../src/mosty

proc verifyGatewayTraffic() {.async.} =
  let listener = newAsyncSocket()
  listener.bindAddr(Port(0), "127.0.0.1")
  listener.listen()
  let
    pending = listener.accept()
    outgoing = newAsyncSocket()
  await outgoing.connect("127.0.0.1", listener.getLocalAddr()[1])
  let
    incoming = await pending
    clientSocket = WebSocket(tcpSocket: outgoing, readyState: Open, masked: true)
    serverSocket = WebSocket(tcpSocket: incoming, readyState: Open, masked: false)
    client = newMostyClient("http://127.0.0.1", "fixture")
    receiving = client.eventLoop(clientSocket, nil, nil, nil)
  defer:
    clientSocket.hangup()
    serverSocket.hangup()
    listener.close()
    client.close()
  doAssert client.lastHeartbeat == 0
  await serverSocket.send("heartbeat", Ping)
  let reply = serverSocket.receivePacket()
  doAssert await reply.withTimeout(2000)
  doAssert (await reply) == (Pong, "heartbeat")
  doAssert client.lastHeartbeat > 0
  let firstHeartbeat = client.lastHeartbeat
  await sleepAsync(10)
  await serverSocket.send("", Pong)
  await sleepAsync(20)
  doAssert client.lastHeartbeat > firstHeartbeat
  let beforeIdle = client.lastHeartbeat
  await sleepAsync(20)
  doAssert client.lastHeartbeat == beforeIdle
  client.running = false
  await serverSocket.send("{\"event\":\"hello\"}")
  doAssert await receiving.withTimeout(2000)
  await receiving

suite "gateway activity":
  test "control frames update heartbeat and ping replies preserve payload":
    waitFor verifyGatewayTraffic()
