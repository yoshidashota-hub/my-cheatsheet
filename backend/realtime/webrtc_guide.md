# WebRTC リアルタイム通信ガイド

## 目次
- [概要](#概要)
- [WebRTCの基本概念](#webrtcの基本概念)
- [主要ライブラリ比較](#主要ライブラリ比較)
- [Simple Peer - 簡易P2P通信](#simple-peer---簡易p2p通信)
- [PeerJS - ブローカーサーバー付きP2P](#peerjs---ブローカーサーバー付きp2p)
- [Socket.io + WebRTC統合](#socketio--webrtc統合)
- [Next.js統合例](#nextjs統合例)
- [実践的な使用例](#実践的な使用例)
- [ベストプラクティス](#ベストプラクティス)

## 概要

WebRTC (Web Real-Time Communication) は、ブラウザ間でリアルタイムに音声・映像・データを直接やり取りできる技術です。ビデオ会議、画面共有、ファイル転送などに使用されます。

### WebRTCの主な用途

1. **ビデオ会議**: Zoom、Google Meetのような通話アプリ
2. **画面共有**: リモートサポート、オンライン教育
3. **ファイル転送**: P2Pファイル共有、大容量ファイル送信
4. **ライブストリーミング**: リアルタイム配信、ライブコマース
5. **ゲーム**: リアルタイムマルチプレイヤー

### WebRTCの利点

- **低遅延**: サーバーを経由せず直接通信
- **セキュア**: DTLS/SRTPによる暗号化
- **標準技術**: ブラウザネイティブサポート
- **帯域効率**: P2P接続で帯域コスト削減

## WebRTCの基本概念

### 1. シグナリング

P2P接続を確立するための事前通信（WebRTC仕様外）。通常はWebSocketやSocket.ioで実装します。

```typescript
// シグナリングの流れ
// 1. Offer作成 → 送信
// 2. Answer作成 → 送信
// 3. ICE Candidate交換
// 4. P2P接続確立
```

### 2. ICE (Interactive Connectivity Establishment)

NAT越えのためのネットワーク経路探索。

```typescript
// ICE Candidateの種類
// - host: ローカルIP
// - srflx: STUN経由の公開IP
// - relay: TURN経由の中継
```

### 3. STUN/TURNサーバー

- **STUN**: 公開IPアドレスの取得
- **TURN**: NAT越えできない場合の中継サーバー

```typescript
const configuration = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' }, // Google公開STUN
    {
      urls: 'turn:turnserver.com:3478',
      username: 'user',
      credential: 'pass',
    },
  ],
}
```

## 主要ライブラリ比較

| ライブラリ | 特徴 | サイズ | ユースケース |
|----------|------|--------|------------|
| Simple Peer | シンプル、軽量 | 7.4KB | 1対1通信、学習用 |
| PeerJS | ブローカーサーバー付き | 48KB | マルチピア、メッシュ接続 |
| mediasoup | SFU実装 | 大規模 | 多人数会議、配信 |
| Daily.co | フルマネージド | API | 商用ビデオ会議 |

### 選択基準

**Simple Peer を使用すべき場合**:
- 1対1のシンプルな通信
- 軽量なライブラリが必要
- WebRTCの学習

**PeerJS を使用すべき場合**:
- 複数ピアの接続管理
- シンプルなAPI
- 無料のブローカーサーバーを使いたい

**mediasoup を使用すべき場合**:
- 多人数ビデオ会議（3人以上）
- SFU（Selective Forwarding Unit）が必要
- スケーラブルな構成

## Simple Peer - 簡易P2P通信

### インストール

```bash
npm install simple-peer
npm install --save-dev @types/simple-peer
```

### 基本的な使用方法

#### 1. 1対1ビデオ通話

```typescript
'use client'

import { useEffect, useRef, useState } from 'react'
import SimplePeer from 'simple-peer'

export default function VideoCall({ socket }: { socket: any }) {
  const [peer, setPeer] = useState<SimplePeer.Instance | null>(null)
  const [stream, setStream] = useState<MediaStream | null>(null)
  const localVideoRef = useRef<HTMLVideoElement>(null)
  const remoteVideoRef = useRef<HTMLVideoElement>(null)

  // カメラ・マイクの取得
  const initMedia = async () => {
    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: true,
        audio: true,
      })
      setStream(mediaStream)

      if (localVideoRef.current) {
        localVideoRef.current.srcObject = mediaStream
      }
    } catch (error) {
      console.error('メディア取得エラー:', error)
    }
  }

  // 発信者（Initiator）
  const startCall = () => {
    if (!stream) return

    const p = new SimplePeer({
      initiator: true,
      trickle: false,
      stream: stream,
    })

    p.on('signal', (data) => {
      // Offerをシグナリングサーバーに送信
      socket.emit('call-user', { signal: data })
    })

    p.on('stream', (remoteStream) => {
      // リモートストリームを受信
      if (remoteVideoRef.current) {
        remoteVideoRef.current.srcObject = remoteStream
      }
    })

    setPeer(p)
  }

  // 受信者
  const answerCall = (incomingSignal: SimplePeer.SignalData) => {
    if (!stream) return

    const p = new SimplePeer({
      initiator: false,
      trickle: false,
      stream: stream,
    })

    p.on('signal', (data) => {
      // Answerをシグナリングサーバーに送信
      socket.emit('answer-call', { signal: data })
    })

    p.on('stream', (remoteStream) => {
      if (remoteVideoRef.current) {
        remoteVideoRef.current.srcObject = remoteStream
      }
    })

    p.signal(incomingSignal)
    setPeer(p)
  }

  // シグナリング受信
  useEffect(() => {
    socket.on('call-made', (data: { signal: SimplePeer.SignalData }) => {
      answerCall(data.signal)
    })

    socket.on('call-answered', (data: { signal: SimplePeer.SignalData }) => {
      peer?.signal(data.signal)
    })

    return () => {
      socket.off('call-made')
      socket.off('call-answered')
    }
  }, [socket, peer])

  useEffect(() => {
    initMedia()

    return () => {
      stream?.getTracks().forEach((track) => track.stop())
      peer?.destroy()
    }
  }, [])

  return (
    <div className="grid grid-cols-2 gap-4">
      <div>
        <h3 className="font-bold mb-2">あなた</h3>
        <video
          ref={localVideoRef}
          autoPlay
          muted
          className="w-full rounded-lg bg-black"
        />
      </div>
      <div>
        <h3 className="font-bold mb-2">相手</h3>
        <video
          ref={remoteVideoRef}
          autoPlay
          className="w-full rounded-lg bg-black"
        />
      </div>
      <button
        onClick={startCall}
        className="col-span-2 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
      >
        通話開始
      </button>
    </div>
  )
}
```

#### 2. データチャネル（ファイル転送）

```typescript
'use client'

import { useState } from 'react'
import SimplePeer from 'simple-peer'

export default function FileTransfer({ socket }: { socket: any }) {
  const [peer, setPeer] = useState<SimplePeer.Instance | null>(null)
  const [receivedData, setReceivedData] = useState<ArrayBuffer[]>([])
  const [transferProgress, setTransferProgress] = useState(0)

  // データチャネル付きピア作成
  const createPeer = (initiator: boolean) => {
    const p = new SimplePeer({
      initiator,
      trickle: false,
    })

    p.on('signal', (data) => {
      socket.emit('signal', { signal: data })
    })

    p.on('data', (data) => {
      // データ受信
      setReceivedData((prev) => [...prev, data.buffer])
    })

    p.on('error', (err) => {
      console.error('ピアエラー:', err)
    })

    setPeer(p)
    return p
  }

  // ファイル送信
  const sendFile = async (file: File) => {
    if (!peer) return

    const chunkSize = 16384 // 16KB
    const fileReader = new FileReader()
    let offset = 0

    fileReader.onload = (e) => {
      if (e.target?.result) {
        peer.send(e.target.result as ArrayBuffer)

        offset += chunkSize
        setTransferProgress((offset / file.size) * 100)

        if (offset < file.size) {
          readSlice(offset)
        } else {
          setTransferProgress(100)
        }
      }
    }

    const readSlice = (o: number) => {
      const slice = file.slice(o, o + chunkSize)
      fileReader.readAsArrayBuffer(slice)
    }

    // ファイルメタデータ送信
    peer.send(
      JSON.stringify({
        type: 'file-meta',
        name: file.name,
        size: file.size,
        mimeType: file.type,
      })
    )

    readSlice(0)
  }

  // 受信データをダウンロード
  const downloadReceivedFile = () => {
    const blob = new Blob(receivedData)
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'received-file'
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-4">
      <div>
        <input
          type="file"
          onChange={(e) => {
            const file = e.target.files?.[0]
            if (file) sendFile(file)
          }}
          className="block w-full text-sm"
        />
      </div>

      {transferProgress > 0 && (
        <div className="w-full bg-gray-200 rounded-full h-2">
          <div
            className="bg-blue-600 h-2 rounded-full transition-all"
            style={{ width: `${transferProgress}%` }}
          />
        </div>
      )}

      {receivedData.length > 0 && (
        <button
          onClick={downloadReceivedFile}
          className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
        >
          受信ファイルをダウンロード
        </button>
      )}
    </div>
  )
}
```

#### 3. 画面共有

```typescript
'use client'

import { useRef, useState } from 'react'
import SimplePeer from 'simple-peer'

export default function ScreenShare() {
  const [peer, setPeer] = useState<SimplePeer.Instance | null>(null)
  const [isSharing, setIsSharing] = useState(false)
  const localVideoRef = useRef<HTMLVideoElement>(null)
  const remoteVideoRef = useRef<HTMLVideoElement>(null)

  // 画面共有開始
  const startScreenShare = async () => {
    try {
      const screenStream = await navigator.mediaDevices.getDisplayMedia({
        video: {
          cursor: 'always',
        },
        audio: false,
      })

      if (localVideoRef.current) {
        localVideoRef.current.srcObject = screenStream
      }

      const p = new SimplePeer({
        initiator: true,
        trickle: false,
        stream: screenStream,
      })

      p.on('signal', (data) => {
        console.log('Share signal:', data)
        // シグナリングサーバーに送信
      })

      p.on('stream', (remoteStream) => {
        if (remoteVideoRef.current) {
          remoteVideoRef.current.srcObject = remoteStream
        }
      })

      // 画面共有停止時の処理
      screenStream.getVideoTracks()[0].onended = () => {
        stopScreenShare()
      }

      setPeer(p)
      setIsSharing(true)
    } catch (error) {
      console.error('画面共有エラー:', error)
    }
  }

  // 画面共有停止
  const stopScreenShare = () => {
    const stream = localVideoRef.current?.srcObject as MediaStream
    stream?.getTracks().forEach((track) => track.stop())
    peer?.destroy()
    setPeer(null)
    setIsSharing(false)
  }

  return (
    <div className="space-y-4">
      <button
        onClick={isSharing ? stopScreenShare : startScreenShare}
        className={`px-4 py-2 rounded text-white ${
          isSharing
            ? 'bg-red-600 hover:bg-red-700'
            : 'bg-blue-600 hover:bg-blue-700'
        }`}
      >
        {isSharing ? '共有停止' : '画面共有開始'}
      </button>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <h3 className="font-bold mb-2">共有画面</h3>
          <video
            ref={localVideoRef}
            autoPlay
            muted
            className="w-full rounded-lg bg-black"
          />
        </div>
        <div>
          <h3 className="font-bold mb-2">受信画面</h3>
          <video
            ref={remoteVideoRef}
            autoPlay
            className="w-full rounded-lg bg-black"
          />
        </div>
      </div>
    </div>
  )
}
```

## PeerJS - ブローカーサーバー付きP2P

### インストール

```bash
npm install peerjs
npm install --save-dev @types/peerjs
```

### 基本的な使用方法

#### 1. シンプルなビデオ通話

```typescript
'use client'

import { useEffect, useRef, useState } from 'react'
import Peer from 'peerjs'

export default function PeerJSVideoCall() {
  const [peer, setPeer] = useState<Peer | null>(null)
  const [myId, setMyId] = useState<string>('')
  const [remotePeerId, setRemotePeerId] = useState<string>('')
  const [stream, setStream] = useState<MediaStream | null>(null)
  const localVideoRef = useRef<HTMLVideoElement>(null)
  const remoteVideoRef = useRef<HTMLVideoElement>(null)

  useEffect(() => {
    // Peer初期化
    const p = new Peer()

    p.on('open', (id) => {
      setMyId(id)
      console.log('My peer ID:', id)
    })

    // 着信処理
    p.on('call', (call) => {
      navigator.mediaDevices
        .getUserMedia({ video: true, audio: true })
        .then((mediaStream) => {
          setStream(mediaStream)

          if (localVideoRef.current) {
            localVideoRef.current.srcObject = mediaStream
          }

          // 着信に応答
          call.answer(mediaStream)

          call.on('stream', (remoteStream) => {
            if (remoteVideoRef.current) {
              remoteVideoRef.current.srcObject = remoteStream
            }
          })
        })
        .catch((err) => console.error('メディア取得エラー:', err))
    })

    setPeer(p)

    return () => {
      p.destroy()
    }
  }, [])

  // 発信
  const callPeer = async () => {
    if (!peer || !remotePeerId) return

    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: true,
        audio: true,
      })

      setStream(mediaStream)

      if (localVideoRef.current) {
        localVideoRef.current.srcObject = mediaStream
      }

      const call = peer.call(remotePeerId, mediaStream)

      call.on('stream', (remoteStream) => {
        if (remoteVideoRef.current) {
          remoteVideoRef.current.srcObject = remoteStream
        }
      })
    } catch (error) {
      console.error('通話エラー:', error)
    }
  }

  return (
    <div className="space-y-4">
      <div className="p-4 bg-gray-100 rounded">
        <p className="text-sm">
          <strong>あなたのID:</strong> {myId}
        </p>
      </div>

      <div className="flex gap-2">
        <input
          type="text"
          value={remotePeerId}
          onChange={(e) => setRemotePeerId(e.target.value)}
          placeholder="相手のPeer IDを入力"
          className="flex-1 p-2 border rounded"
        />
        <button
          onClick={callPeer}
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
        >
          発信
        </button>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <h3 className="font-bold mb-2">あなた</h3>
          <video
            ref={localVideoRef}
            autoPlay
            muted
            className="w-full rounded-lg bg-black"
          />
        </div>
        <div>
          <h3 className="font-bold mb-2">相手</h3>
          <video
            ref={remoteVideoRef}
            autoPlay
            className="w-full rounded-lg bg-black"
          />
        </div>
      </div>
    </div>
  )
}
```

#### 2. データコネクション

```typescript
'use client'

import { useEffect, useState } from 'react'
import Peer, { DataConnection } from 'peerjs'

export default function PeerJSDataChannel() {
  const [peer, setPeer] = useState<Peer | null>(null)
  const [conn, setConn] = useState<DataConnection | null>(null)
  const [myId, setMyId] = useState<string>('')
  const [remotePeerId, setRemotePeerId] = useState<string>('')
  const [messages, setMessages] = useState<string[]>([])
  const [inputMessage, setInputMessage] = useState('')

  useEffect(() => {
    const p = new Peer()

    p.on('open', (id) => {
      setMyId(id)
    })

    p.on('connection', (connection) => {
      setConn(connection)
      setupDataHandlers(connection)
    })

    setPeer(p)

    return () => {
      p.destroy()
    }
  }, [])

  const setupDataHandlers = (connection: DataConnection) => {
    connection.on('data', (data) => {
      setMessages((prev) => [...prev, `相手: ${data}`])
    })

    connection.on('open', () => {
      console.log('データ接続確立')
    })
  }

  const connectToPeer = () => {
    if (!peer || !remotePeerId) return

    const connection = peer.connect(remotePeerId)
    setConn(connection)
    setupDataHandlers(connection)
  }

  const sendMessage = () => {
    if (!conn || !inputMessage) return

    conn.send(inputMessage)
    setMessages((prev) => [...prev, `あなた: ${inputMessage}`])
    setInputMessage('')
  }

  return (
    <div className="max-w-2xl mx-auto p-6 space-y-4">
      <div className="p-4 bg-gray-100 rounded">
        <p className="text-sm">
          <strong>あなたのID:</strong> {myId}
        </p>
      </div>

      <div className="flex gap-2">
        <input
          type="text"
          value={remotePeerId}
          onChange={(e) => setRemotePeerId(e.target.value)}
          placeholder="相手のPeer IDを入力"
          className="flex-1 p-2 border rounded"
        />
        <button
          onClick={connectToPeer}
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
        >
          接続
        </button>
      </div>

      <div className="border rounded p-4 h-64 overflow-y-auto bg-white">
        {messages.map((msg, index) => (
          <p key={index} className="mb-2">
            {msg}
          </p>
        ))}
      </div>

      <div className="flex gap-2">
        <input
          type="text"
          value={inputMessage}
          onChange={(e) => setInputMessage(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
          placeholder="メッセージを入力"
          className="flex-1 p-2 border rounded"
        />
        <button
          onClick={sendMessage}
          disabled={!conn}
          className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 disabled:bg-gray-300"
        >
          送信
        </button>
      </div>
    </div>
  )
}
```

## Socket.io + WebRTC統合

### シグナリングサーバー（Next.js API）

```typescript
// server.js (カスタムサーバー)
import { createServer } from 'http'
import { parse } from 'url'
import next from 'next'
import { Server } from 'socket.io'

const dev = process.env.NODE_ENV !== 'production'
const hostname = 'localhost'
const port = 3000

const app = next({ dev, hostname, port })
const handle = app.getRequestHandler()

app.prepare().then(() => {
  const server = createServer((req, res) => {
    const parsedUrl = parse(req.url!, true)
    handle(req, res, parsedUrl)
  })

  const io = new Server(server)

  const rooms = new Map<string, Set<string>>()

  io.on('connection', (socket) => {
    console.log('クライアント接続:', socket.id)

    // ルーム参加
    socket.on('join-room', (roomId: string) => {
      socket.join(roomId)

      if (!rooms.has(roomId)) {
        rooms.set(roomId, new Set())
      }
      rooms.get(roomId)!.add(socket.id)

      // 既存の参加者に通知
      socket.to(roomId).emit('user-joined', socket.id)

      console.log(`${socket.id} がルーム ${roomId} に参加`)
    })

    // Offer転送
    socket.on('offer', (data: { to: string; offer: RTCSessionDescriptionInit }) => {
      socket.to(data.to).emit('offer', {
        from: socket.id,
        offer: data.offer,
      })
    })

    // Answer転送
    socket.on('answer', (data: { to: string; answer: RTCSessionDescriptionInit }) => {
      socket.to(data.to).emit('answer', {
        from: socket.id,
        answer: data.answer,
      })
    })

    // ICE Candidate転送
    socket.on('ice-candidate', (data: { to: string; candidate: RTCIceCandidate }) => {
      socket.to(data.to).emit('ice-candidate', {
        from: socket.id,
        candidate: data.candidate,
      })
    })

    // 切断
    socket.on('disconnect', () => {
      rooms.forEach((users, roomId) => {
        if (users.has(socket.id)) {
          users.delete(socket.id)
          socket.to(roomId).emit('user-left', socket.id)
        }
      })
      console.log('クライアント切断:', socket.id)
    })
  })

  server.listen(port, () => {
    console.log(`> Ready on http://${hostname}:${port}`)
  })
})
```

### クライアント実装

```typescript
'use client'

import { useEffect, useRef, useState } from 'react'
import { io, Socket } from 'socket.io-client'

export default function WebRTCRoom({ roomId }: { roomId: string }) {
  const [socket, setSocket] = useState<Socket | null>(null)
  const [peers, setPeers] = useState<Map<string, RTCPeerConnection>>(new Map())
  const [localStream, setLocalStream] = useState<MediaStream | null>(null)
  const localVideoRef = useRef<HTMLVideoElement>(null)
  const remoteVideosRef = useRef<Map<string, HTMLVideoElement>>(new Map())

  // Socket.io初期化
  useEffect(() => {
    const s = io('http://localhost:3000')
    setSocket(s)

    return () => {
      s.disconnect()
    }
  }, [])

  // メディア取得
  useEffect(() => {
    navigator.mediaDevices
      .getUserMedia({ video: true, audio: true })
      .then((stream) => {
        setLocalStream(stream)
        if (localVideoRef.current) {
          localVideoRef.current.srcObject = stream
        }
      })
      .catch((err) => console.error('メディア取得エラー:', err))
  }, [])

  // ルーム参加とシグナリング処理
  useEffect(() => {
    if (!socket || !localStream) return

    socket.emit('join-room', roomId)

    // 新規参加者
    socket.on('user-joined', async (userId: string) => {
      const peer = createPeerConnection(userId)
      setPeers((prev) => new Map(prev).set(userId, peer))

      // Offer作成
      const offer = await peer.createOffer()
      await peer.setLocalDescription(offer)
      socket.emit('offer', { to: userId, offer })
    })

    // Offer受信
    socket.on(
      'offer',
      async (data: { from: string; offer: RTCSessionDescriptionInit }) => {
        const peer = createPeerConnection(data.from)
        setPeers((prev) => new Map(prev).set(data.from, peer))

        await peer.setRemoteDescription(new RTCSessionDescription(data.offer))

        // Answer作成
        const answer = await peer.createAnswer()
        await peer.setLocalDescription(answer)
        socket.emit('answer', { to: data.from, answer })
      }
    )

    // Answer受信
    socket.on(
      'answer',
      async (data: { from: string; answer: RTCSessionDescriptionInit }) => {
        const peer = peers.get(data.from)
        if (peer) {
          await peer.setRemoteDescription(new RTCSessionDescription(data.answer))
        }
      }
    )

    // ICE Candidate受信
    socket.on(
      'ice-candidate',
      async (data: { from: string; candidate: RTCIceCandidate }) => {
        const peer = peers.get(data.from)
        if (peer) {
          await peer.addIceCandidate(new RTCIceCandidate(data.candidate))
        }
      }
    )

    // ユーザー退出
    socket.on('user-left', (userId: string) => {
      const peer = peers.get(userId)
      if (peer) {
        peer.close()
        setPeers((prev) => {
          const newPeers = new Map(prev)
          newPeers.delete(userId)
          return newPeers
        })
      }
    })

    return () => {
      socket.off('user-joined')
      socket.off('offer')
      socket.off('answer')
      socket.off('ice-candidate')
      socket.off('user-left')
    }
  }, [socket, localStream, roomId])

  const createPeerConnection = (userId: string): RTCPeerConnection => {
    const peer = new RTCPeerConnection({
      iceServers: [{ urls: 'stun:stun.l.google.com:19302' }],
    })

    // ローカルストリームを追加
    localStream?.getTracks().forEach((track) => {
      peer.addTrack(track, localStream)
    })

    // リモートストリーム受信
    peer.ontrack = (event) => {
      const videoElement = document.getElementById(
        `video-${userId}`
      ) as HTMLVideoElement
      if (videoElement) {
        videoElement.srcObject = event.streams[0]
      }
    }

    // ICE Candidate
    peer.onicecandidate = (event) => {
      if (event.candidate && socket) {
        socket.emit('ice-candidate', {
          to: userId,
          candidate: event.candidate,
        })
      }
    }

    return peer
  }

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-4">ルーム: {roomId}</h1>

      <div className="grid grid-cols-3 gap-4">
        <div>
          <h3 className="font-bold mb-2">あなた</h3>
          <video
            ref={localVideoRef}
            autoPlay
            muted
            className="w-full rounded-lg bg-black"
          />
        </div>

        {Array.from(peers.keys()).map((userId) => (
          <div key={userId}>
            <h3 className="font-bold mb-2">参加者 {userId.slice(0, 6)}</h3>
            <video
              id={`video-${userId}`}
              autoPlay
              className="w-full rounded-lg bg-black"
            />
          </div>
        ))}
      </div>
    </div>
  )
}
```

## Next.js統合例

### 環境変数設定

```env
# .env.local
NEXT_PUBLIC_TURN_SERVER_URL=turn:turnserver.com:3478
NEXT_PUBLIC_TURN_USERNAME=user
NEXT_PUBLIC_TURN_CREDENTIAL=pass
```

### WebRTCコンテキストプロバイダー

```typescript
'use client'

import { createContext, useContext, useEffect, useState, ReactNode } from 'react'

interface WebRTCContextType {
  localStream: MediaStream | null
  startCamera: () => Promise<void>
  stopCamera: () => void
}

const WebRTCContext = createContext<WebRTCContextType | undefined>(undefined)

export function WebRTCProvider({ children }: { children: ReactNode }) {
  const [localStream, setLocalStream] = useState<MediaStream | null>(null)

  const startCamera = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: true,
        audio: true,
      })
      setLocalStream(stream)
    } catch (error) {
      console.error('カメラ起動エラー:', error)
      throw error
    }
  }

  const stopCamera = () => {
    localStream?.getTracks().forEach((track) => track.stop())
    setLocalStream(null)
  }

  useEffect(() => {
    return () => {
      stopCamera()
    }
  }, [])

  return (
    <WebRTCContext.Provider value={{ localStream, startCamera, stopCamera }}>
      {children}
    </WebRTCContext.Provider>
  )
}

export function useWebRTC() {
  const context = useContext(WebRTCContext)
  if (!context) {
    throw new Error('useWebRTC must be used within WebRTCProvider')
  }
  return context
}
```

## 実践的な使用例

### 1. グループビデオ会議

```typescript
'use client'

import { useEffect, useRef, useState } from 'react'
import { io, Socket } from 'socket.io-client'

interface Participant {
  id: string
  stream: MediaStream | null
  isMuted: boolean
  isVideoOff: boolean
}

export default function GroupVideoCall({ roomId }: { roomId: string }) {
  const [socket, setSocket] = useState<Socket | null>(null)
  const [participants, setParticipants] = useState<Map<string, Participant>>(
    new Map()
  )
  const [localStream, setLocalStream] = useState<MediaStream | null>(null)
  const [isMuted, setIsMuted] = useState(false)
  const [isVideoOff, setIsVideoOff] = useState(false)
  const localVideoRef = useRef<HTMLVideoElement>(null)

  // カメラ・マイク制御
  const toggleMute = () => {
    if (localStream) {
      localStream.getAudioTracks().forEach((track) => {
        track.enabled = !track.enabled
      })
      setIsMuted(!isMuted)
      socket?.emit('toggle-audio', { roomId, isMuted: !isMuted })
    }
  }

  const toggleVideo = () => {
    if (localStream) {
      localStream.getVideoTracks().forEach((track) => {
        track.enabled = !track.enabled
      })
      setIsVideoOff(!isVideoOff)
      socket?.emit('toggle-video', { roomId, isVideoOff: !isVideoOff })
    }
  }

  const leaveRoom = () => {
    localStream?.getTracks().forEach((track) => track.stop())
    socket?.emit('leave-room', roomId)
    socket?.disconnect()
  }

  return (
    <div className="flex flex-col h-screen bg-gray-900">
      {/* メインビデオエリア */}
      <div className="flex-1 grid grid-cols-3 gap-2 p-4">
        {/* 自分のビデオ */}
        <div className="relative bg-black rounded-lg overflow-hidden">
          <video
            ref={localVideoRef}
            autoPlay
            muted
            className="w-full h-full object-cover"
          />
          <div className="absolute bottom-2 left-2 px-2 py-1 bg-black bg-opacity-50 rounded text-white text-sm">
            あなた {isMuted && '🔇'} {isVideoOff && '📷'}
          </div>
        </div>

        {/* 参加者のビデオ */}
        {Array.from(participants.values()).map((participant) => (
          <div
            key={participant.id}
            className="relative bg-black rounded-lg overflow-hidden"
          >
            <video
              id={`video-${participant.id}`}
              autoPlay
              className="w-full h-full object-cover"
            />
            <div className="absolute bottom-2 left-2 px-2 py-1 bg-black bg-opacity-50 rounded text-white text-sm">
              {participant.id.slice(0, 6)}
              {participant.isMuted && ' 🔇'}
              {participant.isVideoOff && ' 📷'}
            </div>
          </div>
        ))}
      </div>

      {/* コントロールバー */}
      <div className="flex justify-center items-center gap-4 p-4 bg-gray-800">
        <button
          onClick={toggleMute}
          className={`p-4 rounded-full ${
            isMuted ? 'bg-red-600' : 'bg-gray-600'
          } text-white hover:opacity-80`}
        >
          {isMuted ? '🔇' : '🎤'}
        </button>

        <button
          onClick={toggleVideo}
          className={`p-4 rounded-full ${
            isVideoOff ? 'bg-red-600' : 'bg-gray-600'
          } text-white hover:opacity-80`}
        >
          {isVideoOff ? '📷' : '🎥'}
        </button>

        <button
          onClick={leaveRoom}
          className="p-4 rounded-full bg-red-600 text-white hover:bg-red-700"
        >
          退出
        </button>
      </div>
    </div>
  )
}
```

### 2. P2Pファイル共有

```typescript
'use client'

import { useState } from 'react'
import Peer, { DataConnection } from 'peerjs'

interface FileMetadata {
  name: string
  size: number
  type: string
}

export default function P2PFileShare() {
  const [peer, setPeer] = useState<Peer | null>(null)
  const [conn, setConn] = useState<DataConnection | null>(null)
  const [myId, setMyId] = useState('')
  const [remotePeerId, setRemotePeerId] = useState('')
  const [transferProgress, setTransferProgress] = useState(0)
  const [receivingFile, setReceivingFile] = useState<FileMetadata | null>(null)
  const [receivedChunks, setReceivedChunks] = useState<ArrayBuffer[]>([])

  // Peer初期化
  useState(() => {
    const p = new Peer()

    p.on('open', (id) => {
      setMyId(id)
    })

    p.on('connection', (connection) => {
      setupConnection(connection)
    })

    setPeer(p)
  })

  const setupConnection = (connection: DataConnection) => {
    setConn(connection)

    connection.on('data', (data: any) => {
      if (data.type === 'file-metadata') {
        setReceivingFile({
          name: data.name,
          size: data.size,
          type: data.mimeType,
        })
        setReceivedChunks([])
      } else if (data instanceof ArrayBuffer) {
        setReceivedChunks((prev) => [...prev, data])

        if (receivingFile) {
          const received = receivedChunks.reduce(
            (acc, chunk) => acc + chunk.byteLength,
            0
          )
          setTransferProgress((received / receivingFile.size) * 100)
        }
      }
    })

    connection.on('open', () => {
      console.log('データ接続確立')
    })
  }

  const connectToPeer = () => {
    if (!peer || !remotePeerId) return

    const connection = peer.connect(remotePeerId, {
      reliable: true,
    })
    setupConnection(connection)
  }

  const sendFile = async (file: File) => {
    if (!conn) return

    // メタデータ送信
    conn.send({
      type: 'file-metadata',
      name: file.name,
      size: file.size,
      mimeType: file.type,
    })

    // チャンク送信
    const chunkSize = 16 * 1024 // 16KB
    let offset = 0

    while (offset < file.size) {
      const chunk = file.slice(offset, offset + chunkSize)
      const arrayBuffer = await chunk.arrayBuffer()
      conn.send(arrayBuffer)

      offset += chunkSize
      setTransferProgress((offset / file.size) * 100)
    }

    setTransferProgress(100)
  }

  const downloadReceivedFile = () => {
    if (!receivingFile || receivedChunks.length === 0) return

    const blob = new Blob(receivedChunks, { type: receivingFile.type })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = receivingFile.name
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="max-w-2xl mx-auto p-6 space-y-6">
      <div className="p-4 bg-blue-50 border border-blue-200 rounded">
        <p className="font-mono text-sm">
          <strong>あなたのID:</strong> {myId}
        </p>
      </div>

      <div className="space-y-2">
        <label className="block font-medium">相手のIDを入力</label>
        <div className="flex gap-2">
          <input
            type="text"
            value={remotePeerId}
            onChange={(e) => setRemotePeerId(e.target.value)}
            placeholder="Peer ID"
            className="flex-1 p-2 border rounded"
          />
          <button
            onClick={connectToPeer}
            className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            接続
          </button>
        </div>
      </div>

      <div className="border-2 border-dashed rounded-lg p-8 text-center">
        <input
          type="file"
          onChange={(e) => {
            const file = e.target.files?.[0]
            if (file && conn) {
              sendFile(file)
            }
          }}
          className="hidden"
          id="file-input"
        />
        <label
          htmlFor="file-input"
          className="cursor-pointer px-6 py-3 bg-green-600 text-white rounded hover:bg-green-700 inline-block"
        >
          ファイルを選択して送信
        </label>
      </div>

      {transferProgress > 0 && transferProgress < 100 && (
        <div>
          <p className="text-sm mb-2">転送中: {Math.round(transferProgress)}%</p>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className="bg-blue-600 h-2 rounded-full transition-all"
              style={{ width: `${transferProgress}%` }}
            />
          </div>
        </div>
      )}

      {receivingFile && receivedChunks.length > 0 && (
        <div className="p-4 bg-green-50 border border-green-200 rounded">
          <p className="font-semibold">ファイルを受信しました</p>
          <p className="text-sm">
            {receivingFile.name} ({(receivingFile.size / 1024).toFixed(2)} KB)
          </p>
          <button
            onClick={downloadReceivedFile}
            className="mt-2 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
          >
            ダウンロード
          </button>
        </div>
      )}
    </div>
  )
}
```

## ベストプラクティス

### 1. エラーハンドリング

```typescript
const createPeerConnectionWithErrorHandling = (userId: string) => {
  const peer = new RTCPeerConnection(configuration)

  peer.oniceconnectionstatechange = () => {
    console.log('ICE接続状態:', peer.iceConnectionState)

    if (peer.iceConnectionState === 'failed') {
      console.error('ICE接続失敗 - TURN サーバーが必要かもしれません')
      // フォールバック処理
    }

    if (peer.iceConnectionState === 'disconnected') {
      console.warn('接続が切断されました')
      // 再接続処理
    }
  }

  peer.onconnectionstatechange = () => {
    console.log('接続状態:', peer.connectionState)

    if (peer.connectionState === 'failed') {
      console.error('接続失敗')
      peer.close()
      // 再試行ロジック
    }
  }

  return peer
}
```

### 2. 帯域制御

```typescript
const applyBandwidthConstraints = async (sender: RTCRtpSender) => {
  const params = sender.getParameters()

  if (!params.encodings) {
    params.encodings = [{}]
  }

  params.encodings[0].maxBitrate = 500000 // 500 kbps

  await sender.setParameters(params)
}

// 使用例
peer.getSenders().forEach((sender) => {
  if (sender.track?.kind === 'video') {
    applyBandwidthConstraints(sender)
  }
})
```

### 3. メモリリーク防止

```typescript
useEffect(() => {
  let peer: RTCPeerConnection | null = null
  let stream: MediaStream | null = null

  const init = async () => {
    stream = await navigator.mediaDevices.getUserMedia({
      video: true,
      audio: true,
    })

    peer = new RTCPeerConnection()
    // setup peer...
  }

  init()

  return () => {
    // クリーンアップ
    stream?.getTracks().forEach((track) => track.stop())
    peer?.close()
  }
}, [])
```

### 4. モバイル対応

```typescript
const getMediaConstraints = () => {
  const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent)

  return {
    video: {
      width: isMobile ? { ideal: 640 } : { ideal: 1280 },
      height: isMobile ? { ideal: 480 } : { ideal: 720 },
      facingMode: 'user',
    },
    audio: {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    },
  }
}

const stream = await navigator.mediaDevices.getUserMedia(getMediaConstraints())
```

## まとめ

### 用途別推奨構成

| 用途 | ライブラリ | シグナリング | ユースケース |
|------|----------|------------|------------|
| 1対1通話 | Simple Peer | Socket.io | ビデオチャット |
| マルチピア | PeerJS | PeerServer | グループ通話 |
| スケーラブル | mediasoup | Socket.io | 大規模会議 |
| 商用サービス | Daily.co API | マネージド | SaaS製品 |

### 実装時のチェックリスト

- [ ] STUNサーバーの設定
- [ ] TURNサーバーの用意（商用環境）
- [ ] シグナリングサーバーの実装
- [ ] エラーハンドリング
- [ ] 接続状態の監視
- [ ] メモリリーク対策
- [ ] モバイル対応
- [ ] 帯域制御
- [ ] セキュリティ（HTTPS必須）
- [ ] ユーザー権限（カメラ・マイク）

このガイドを参考に、WebRTCを活用したリアルタイム通信機能を実装してください。
