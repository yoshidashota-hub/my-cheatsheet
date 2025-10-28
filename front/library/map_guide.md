# 地図ライブラリ統合ガイド

## 目次
- [概要](#概要)
- [主要ライブラリ比較](#主要ライブラリ比較)
- [React Leaflet - オープンソース地図](#react-leaflet---オープンソース地図)
- [Google Maps API - Googleマップ](#google-maps-api---googleマップ)
- [Mapbox - カスタマイズ可能な地図](#mapbox---カスタマイズ可能な地図)
- [Next.js統合例](#nextjs統合例)
- [実践的な使用例](#実践的な使用例)
- [ベストプラクティス](#ベストプラクティス)

## 概要

地図機能は位置情報サービス、店舗検索、配送追跡など幅広いWebアプリケーションで必要とされます。このガイドでは、主要な地図ライブラリの使用方法とNext.jsでの統合を解説します。

### 地図ライブラリの主な用途

1. **店舗・施設検索**: 近隣店舗の表示、ルート案内
2. **配送追跡**: リアルタイム位置追跡、配達状況
3. **不動産**: 物件位置、周辺環境表示
4. **イベント**: 会場案内、駐車場情報
5. **データビジュアライゼーション**: ヒートマップ、統計表示

## 主要ライブラリ比較

| ライブラリ | ライセンス | 料金 | 特徴 | ユースケース |
|----------|----------|------|------|------------|
| React Leaflet | オープンソース | 無料 | 軽量、カスタマイズ性高 | 基本的な地図表示 |
| Google Maps | 商用 | 従量課金 | 高機能、データ豊富 | 店舗検索、ルート案内 |
| Mapbox | 商用 | 従量課金 | デザイン性高、3D対応 | カスタムデザイン地図 |
| OpenLayers | オープンソース | 無料 | 高機能、GIS対応 | 複雑な地図アプリ |

### 選択基準

**React Leaflet を使用すべき場合**:
- 無料で地図機能を実装したい
- OpenStreetMapデータで十分
- カスタマイズ性を重視
- 商用利用の制約を避けたい

**Google Maps を使用すべき場合**:
- 日本国内の詳細な地図が必要
- Places API、Directions APIを使いたい
- ストリートビュー機能が必要
- ユーザーがGoogleマップに慣れている

**Mapbox を使用すべき場合**:
- デザイン性の高い地図が必要
- 3D地形表示が必要
- カスタムスタイルを適用したい
- リアルタイムデータ表示が重要

## React Leaflet - オープンソース地図

### インストール

```bash
npm install react-leaflet leaflet
npm install --save-dev @types/leaflet
```

### CSS読み込み

Leafletの使用には専用CSSが必要です。

```typescript
// app/layout.tsx
import 'leaflet/dist/leaflet.css'

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  )
}
```

### 基本的な使用方法

#### 1. シンプルな地図表示

```typescript
'use client'

import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

// アイコンの設定（Next.jsで必要）
const icon = L.icon({
  iconUrl: '/marker-icon.png',
  iconRetinaUrl: '/marker-icon-2x.png',
  shadowUrl: '/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
})

export default function SimpleMap() {
  const position: [number, number] = [35.6812, 139.7671] // 東京

  return (
    <MapContainer
      center={position}
      zoom={13}
      style={{ height: '400px', width: '100%' }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Marker position={position} icon={icon}>
        <Popup>
          東京駅
        </Popup>
      </Marker>
    </MapContainer>
  )
}
```

#### 2. 複数マーカー表示

```typescript
'use client'

import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet'
import L from 'leaflet'

interface Location {
  id: string
  name: string
  position: [number, number]
  description: string
}

const locations: Location[] = [
  {
    id: '1',
    name: '東京駅',
    position: [35.6812, 139.7671],
    description: '東京の中心駅',
  },
  {
    id: '2',
    name: '新宿駅',
    position: [35.6896, 139.7006],
    description: '世界一利用者が多い駅',
  },
  {
    id: '3',
    name: '渋谷駅',
    position: [35.6580, 139.7016],
    description: '若者の街',
  },
]

const icon = L.icon({
  iconUrl: '/marker-icon.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
})

export default function MultipleMarkersMap() {
  return (
    <MapContainer
      center={[35.6812, 139.7671]}
      zoom={11}
      style={{ height: '500px', width: '100%' }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {locations.map((location) => (
        <Marker key={location.id} position={location.position} icon={icon}>
          <Popup>
            <div>
              <h3 className="font-bold">{location.name}</h3>
              <p>{location.description}</p>
            </div>
          </Popup>
        </Marker>
      ))}
    </MapContainer>
  )
}
```

#### 3. クリックイベント処理

```typescript
'use client'

import { MapContainer, TileLayer, useMapEvents } from 'react-leaflet'
import { useState } from 'react'
import L from 'leaflet'

function LocationMarker() {
  const [position, setPosition] = useState<[number, number] | null>(null)

  const map = useMapEvents({
    click(e) {
      setPosition([e.latlng.lat, e.latlng.lng])
      map.flyTo(e.latlng, map.getZoom())
    },
  })

  return position === null ? null : (
    <Marker position={position} icon={icon}>
      <Popup>クリックした位置</Popup>
    </Marker>
  )
}

export default function ClickableMap() {
  return (
    <div>
      <p className="mb-2 text-sm text-gray-600">
        地図をクリックしてマーカーを配置
      </p>
      <MapContainer
        center={[35.6812, 139.7671]}
        zoom={13}
        style={{ height: '400px', width: '100%' }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <LocationMarker />
      </MapContainer>
    </div>
  )
}
```

#### 4. カスタムアイコン

```typescript
import L from 'leaflet'

// カスタムアイコンの作成
const customIcon = L.icon({
  iconUrl: '/custom-marker.png',
  iconSize: [32, 32],
  iconAnchor: [16, 32],
  popupAnchor: [0, -32],
})

// SVGアイコンの作成
const svgIcon = L.divIcon({
  html: `
    <svg width="24" height="24" viewBox="0 0 24 24" fill="red">
      <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
    </svg>
  `,
  className: 'custom-svg-icon',
  iconSize: [24, 24],
  iconAnchor: [12, 24],
})

// 色分けされたアイコン
const createColoredIcon = (color: string) => {
  return L.divIcon({
    html: `
      <div style="
        background-color: ${color};
        width: 20px;
        height: 20px;
        border-radius: 50%;
        border: 2px solid white;
        box-shadow: 0 2px 4px rgba(0,0,0,0.3);
      "></div>
    `,
    className: 'colored-marker',
    iconSize: [20, 20],
    iconAnchor: [10, 10],
  })
}

// 使用例
<Marker position={[35.6812, 139.7671]} icon={createColoredIcon('#3b82f6')}>
  <Popup>青いマーカー</Popup>
</Marker>
```

#### 5. ポリゴン・サークル表示

```typescript
'use client'

import { MapContainer, TileLayer, Circle, Polygon, Polyline } from 'react-leaflet'

export default function ShapesMap() {
  const center: [number, number] = [35.6812, 139.7671]

  const polygonPositions: [number, number][] = [
    [35.6812, 139.7671],
    [35.6896, 139.7006],
    [35.6580, 139.7016],
  ]

  const polylinePositions: [number, number][] = [
    [35.6812, 139.7671],
    [35.6896, 139.7006],
  ]

  return (
    <MapContainer center={center} zoom={11} style={{ height: '500px' }}>
      <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />

      {/* 円形エリア */}
      <Circle
        center={center}
        radius={2000}
        pathOptions={{ color: 'blue', fillColor: 'blue', fillOpacity: 0.2 }}
      />

      {/* 多角形エリア */}
      <Polygon
        positions={polygonPositions}
        pathOptions={{ color: 'green', fillColor: 'green', fillOpacity: 0.3 }}
      />

      {/* 線（ルート） */}
      <Polyline
        positions={polylinePositions}
        pathOptions={{ color: 'red', weight: 4 }}
      />
    </MapContainer>
  )
}
```

#### 6. 現在位置の取得

```typescript
'use client'

import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet'
import { useState, useEffect } from 'react'
import L from 'leaflet'

function LocationFinder({ onLocationFound }: { onLocationFound: (pos: [number, number]) => void }) {
  const map = useMap()

  useEffect(() => {
    map.locate({ setView: true, maxZoom: 16 })

    map.on('locationfound', (e) => {
      onLocationFound([e.latlng.lat, e.latlng.lng])
    })

    return () => {
      map.off('locationfound')
    }
  }, [map, onLocationFound])

  return null
}

export default function CurrentLocationMap() {
  const [position, setPosition] = useState<[number, number] | null>(null)
  const defaultPosition: [number, number] = [35.6812, 139.7671]

  const icon = L.icon({
    iconUrl: '/marker-icon.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41],
  })

  return (
    <MapContainer
      center={defaultPosition}
      zoom={13}
      style={{ height: '400px', width: '100%' }}
    >
      <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
      <LocationFinder onLocationFound={setPosition} />
      {position && (
        <Marker position={position} icon={icon}>
          <Popup>現在地</Popup>
        </Marker>
      )}
    </MapContainer>
  )
}
```

## Google Maps API - Googleマップ

### インストール

```bash
npm install @vis.gl/react-google-maps
```

### 環境変数設定

```env
# .env.local
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_api_key_here
```

### 基本的な使用方法

#### 1. シンプルな地図表示

```typescript
'use client'

import { APIProvider, Map, Marker } from '@vis.gl/react-google-maps'

export default function GoogleMapSimple() {
  const position = { lat: 35.6812, lng: 139.7671 }

  return (
    <APIProvider apiKey={process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY!}>
      <div style={{ height: '400px', width: '100%' }}>
        <Map
          defaultCenter={position}
          defaultZoom={14}
          mapId="YOUR_MAP_ID" // Google Cloud Consoleで取得
        >
          <Marker position={position} />
        </Map>
      </div>
    </APIProvider>
  )
}
```

#### 2. 複数マーカーと情報ウィンドウ

```typescript
'use client'

import { APIProvider, Map, Marker, InfoWindow } from '@vis.gl/react-google-maps'
import { useState } from 'react'

interface Location {
  id: string
  name: string
  position: { lat: number; lng: number }
  description: string
}

const locations: Location[] = [
  {
    id: '1',
    name: '東京駅',
    position: { lat: 35.6812, lng: 139.7671 },
    description: '東京の中心駅',
  },
  {
    id: '2',
    name: '新宿駅',
    position: { lat: 35.6896, lng: 139.7006 },
    description: '世界一利用者が多い駅',
  },
]

export default function GoogleMapWithInfoWindow() {
  const [selectedLocation, setSelectedLocation] = useState<Location | null>(null)

  return (
    <APIProvider apiKey={process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY!}>
      <div style={{ height: '500px', width: '100%' }}>
        <Map
          defaultCenter={{ lat: 35.6812, lng: 139.7671 }}
          defaultZoom={12}
          mapId="YOUR_MAP_ID"
        >
          {locations.map((location) => (
            <Marker
              key={location.id}
              position={location.position}
              onClick={() => setSelectedLocation(location)}
            />
          ))}

          {selectedLocation && (
            <InfoWindow
              position={selectedLocation.position}
              onCloseClick={() => setSelectedLocation(null)}
            >
              <div>
                <h3 className="font-bold">{selectedLocation.name}</h3>
                <p>{selectedLocation.description}</p>
              </div>
            </InfoWindow>
          )}
        </Map>
      </div>
    </APIProvider>
  )
}
```

#### 3. Places API統合（店舗検索）

```typescript
// app/api/places/search/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const query = searchParams.get('query')
  const location = searchParams.get('location') // "lat,lng"

  if (!query || !location) {
    return NextResponse.json(
      { error: 'クエリと位置情報が必要です' },
      { status: 400 }
    )
  }

  const apiKey = process.env.GOOGLE_MAPS_API_KEY

  try {
    const response = await fetch(
      `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${encodeURIComponent(
        query
      )}&location=${location}&radius=2000&key=${apiKey}&language=ja`
    )

    const data = await response.json()

    if (data.status === 'OK') {
      return NextResponse.json({
        success: true,
        places: data.results.map((place: any) => ({
          id: place.place_id,
          name: place.name,
          address: place.formatted_address,
          position: {
            lat: place.geometry.location.lat,
            lng: place.geometry.location.lng,
          },
          rating: place.rating,
          photo: place.photos?.[0]?.photo_reference,
        })),
      })
    } else {
      return NextResponse.json(
        { error: data.status },
        { status: 500 }
      )
    }
  } catch (error) {
    console.error('Places API エラー:', error)
    return NextResponse.json(
      { error: '検索に失敗しました' },
      { status: 500 }
    )
  }
}
```

```typescript
'use client'

import { APIProvider, Map, Marker } from '@vis.gl/react-google-maps'
import { useState } from 'react'

interface Place {
  id: string
  name: string
  address: string
  position: { lat: number; lng: number }
  rating?: number
}

export default function PlacesSearch() {
  const [places, setPlaces] = useState<Place[]>([])
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(false)
  const center = { lat: 35.6812, lng: 139.7671 }

  const handleSearch = async () => {
    if (!query.trim()) return

    setLoading(true)
    try {
      const response = await fetch(
        `/api/places/search?query=${encodeURIComponent(query)}&location=${center.lat},${center.lng}`
      )
      const data = await response.json()

      if (data.success) {
        setPlaces(data.places)
      }
    } catch (error) {
      console.error('検索エラー:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="カフェ、レストランなど..."
          className="flex-1 p-2 border rounded"
          onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
        />
        <button
          onClick={handleSearch}
          disabled={loading}
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300"
        >
          {loading ? '検索中...' : '検索'}
        </button>
      </div>

      <APIProvider apiKey={process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY!}>
        <div style={{ height: '500px' }}>
          <Map defaultCenter={center} defaultZoom={14} mapId="YOUR_MAP_ID">
            {places.map((place) => (
              <Marker key={place.id} position={place.position} />
            ))}
          </Map>
        </div>
      </APIProvider>

      <div className="space-y-2">
        {places.map((place) => (
          <div key={place.id} className="p-3 border rounded">
            <h3 className="font-semibold">{place.name}</h3>
            <p className="text-sm text-gray-600">{place.address}</p>
            {place.rating && (
              <p className="text-sm">評価: {place.rating} ★</p>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
```

#### 4. Directions API（ルート検索）

```typescript
// app/api/directions/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const origin = searchParams.get('origin')
  const destination = searchParams.get('destination')
  const mode = searchParams.get('mode') || 'driving'

  if (!origin || !destination) {
    return NextResponse.json(
      { error: '出発地と目的地が必要です' },
      { status: 400 }
    )
  }

  const apiKey = process.env.GOOGLE_MAPS_API_KEY

  try {
    const response = await fetch(
      `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(
        origin
      )}&destination=${encodeURIComponent(
        destination
      )}&mode=${mode}&key=${apiKey}&language=ja`
    )

    const data = await response.json()

    if (data.status === 'OK') {
      const route = data.routes[0]
      const leg = route.legs[0]

      return NextResponse.json({
        success: true,
        distance: leg.distance.text,
        duration: leg.duration.text,
        steps: leg.steps.map((step: any) => ({
          instruction: step.html_instructions.replace(/<[^>]*>/g, ''),
          distance: step.distance.text,
          duration: step.duration.text,
        })),
        polyline: route.overview_polyline.points,
      })
    } else {
      return NextResponse.json(
        { error: data.status },
        { status: 500 }
      )
    }
  } catch (error) {
    console.error('Directions API エラー:', error)
    return NextResponse.json(
      { error: 'ルート検索に失敗しました' },
      { status: 500 }
    )
  }
}
```

## Mapbox - カスタマイズ可能な地図

### インストール

```bash
npm install react-map-gl mapbox-gl
npm install --save-dev @types/mapbox-gl
```

### 環境変数設定

```env
# .env.local
NEXT_PUBLIC_MAPBOX_TOKEN=your_mapbox_token_here
```

### 基本的な使用方法

#### 1. シンプルな地図表示

```typescript
'use client'

import Map from 'react-map-gl'
import 'mapbox-gl/dist/mapbox-gl.css'

export default function MapboxSimple() {
  return (
    <Map
      initialViewState={{
        longitude: 139.7671,
        latitude: 35.6812,
        zoom: 14,
      }}
      style={{ width: '100%', height: 400 }}
      mapStyle="mapbox://styles/mapbox/streets-v12"
      mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_TOKEN}
    />
  )
}
```

#### 2. マーカーとポップアップ

```typescript
'use client'

import Map, { Marker, Popup } from 'react-map-gl'
import { useState } from 'react'
import 'mapbox-gl/dist/mapbox-gl.css'

interface Location {
  id: string
  name: string
  longitude: number
  latitude: number
  description: string
}

const locations: Location[] = [
  {
    id: '1',
    name: '東京駅',
    longitude: 139.7671,
    latitude: 35.6812,
    description: '東京の中心駅',
  },
  {
    id: '2',
    name: '新宿駅',
    longitude: 139.7006,
    latitude: 35.6896,
    description: '世界一利用者が多い駅',
  },
]

export default function MapboxWithMarkers() {
  const [selectedLocation, setSelectedLocation] = useState<Location | null>(null)

  return (
    <Map
      initialViewState={{
        longitude: 139.7671,
        latitude: 35.6812,
        zoom: 11,
      }}
      style={{ width: '100%', height: 500 }}
      mapStyle="mapbox://styles/mapbox/streets-v12"
      mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_TOKEN}
    >
      {locations.map((location) => (
        <Marker
          key={location.id}
          longitude={location.longitude}
          latitude={location.latitude}
          anchor="bottom"
          onClick={(e) => {
            e.originalEvent.stopPropagation()
            setSelectedLocation(location)
          }}
        >
          <div className="w-6 h-6 bg-red-600 rounded-full border-2 border-white cursor-pointer" />
        </Marker>
      ))}

      {selectedLocation && (
        <Popup
          longitude={selectedLocation.longitude}
          latitude={selectedLocation.latitude}
          anchor="top"
          onClose={() => setSelectedLocation(null)}
        >
          <div className="p-2">
            <h3 className="font-bold">{selectedLocation.name}</h3>
            <p className="text-sm">{selectedLocation.description}</p>
          </div>
        </Popup>
      )}
    </Map>
  )
}
```

#### 3. カスタムスタイル

```typescript
'use client'

import Map from 'react-map-gl'
import { useState } from 'react'

type MapStyle =
  | 'streets-v12'
  | 'outdoors-v12'
  | 'light-v11'
  | 'dark-v11'
  | 'satellite-v9'
  | 'satellite-streets-v12'

export default function MapboxCustomStyle() {
  const [mapStyle, setMapStyle] = useState<MapStyle>('streets-v12')

  const styles: { label: string; value: MapStyle }[] = [
    { label: 'ストリート', value: 'streets-v12' },
    { label: 'アウトドア', value: 'outdoors-v12' },
    { label: 'ライト', value: 'light-v11' },
    { label: 'ダーク', value: 'dark-v11' },
    { label: '衛星', value: 'satellite-v9' },
    { label: '衛星+道路', value: 'satellite-streets-v12' },
  ]

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        {styles.map((style) => (
          <button
            key={style.value}
            onClick={() => setMapStyle(style.value)}
            className={`px-3 py-1 rounded ${
              mapStyle === style.value
                ? 'bg-blue-600 text-white'
                : 'bg-gray-200'
            }`}
          >
            {style.label}
          </button>
        ))}
      </div>

      <Map
        initialViewState={{
          longitude: 139.7671,
          latitude: 35.6812,
          zoom: 14,
        }}
        style={{ width: '100%', height: 500 }}
        mapStyle={`mapbox://styles/mapbox/${mapStyle}`}
        mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_TOKEN}
      />
    </div>
  )
}
```

#### 4. 3D地形表示

```typescript
'use client'

import Map from 'react-map-gl'

export default function Mapbox3DTerrain() {
  return (
    <Map
      initialViewState={{
        longitude: 138.2529,
        latitude: 36.2048,
        zoom: 11,
        pitch: 60, // 傾き
        bearing: 0, // 回転
      }}
      style={{ width: '100%', height: 600 }}
      mapStyle="mapbox://styles/mapbox/outdoors-v12"
      mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_TOKEN}
      terrain={{ source: 'mapbox-dem', exaggeration: 1.5 }}
    />
  )
}
```

## Next.js統合例

### 動的インポート（SSR回避）

Leafletやその他の地図ライブラリはブラウザAPIに依存するため、Next.jsでSSRを回避する必要があります。

```typescript
// app/map/page.tsx
'use client'

import dynamic from 'next/dynamic'

const MapWithNoSSR = dynamic(() => import('@/components/Map'), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-96 bg-gray-100">
      <p>地図を読み込み中...</p>
    </div>
  ),
})

export default function MapPage() {
  return (
    <div className="container mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">地図表示</h1>
      <MapWithNoSSR />
    </div>
  )
}
```

### Server Actions統合（ジオコーディング）

```typescript
// app/actions/geocoding.ts
'use server'

export async function geocodeAddress(address: string) {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY

  try {
    const response = await fetch(
      `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
        address
      )}&key=${apiKey}&language=ja`
    )

    const data = await response.json()

    if (data.status === 'OK') {
      const location = data.results[0].geometry.location
      return {
        success: true,
        latitude: location.lat,
        longitude: location.lng,
        formatted_address: data.results[0].formatted_address,
      }
    } else {
      return {
        success: false,
        error: data.status,
      }
    }
  } catch (error) {
    console.error('ジオコーディングエラー:', error)
    return {
      success: false,
      error: 'ジオコーディングに失敗しました',
    }
  }
}

export async function reverseGeocode(lat: number, lng: number) {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY

  try {
    const response = await fetch(
      `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${apiKey}&language=ja`
    )

    const data = await response.json()

    if (data.status === 'OK') {
      return {
        success: true,
        address: data.results[0].formatted_address,
      }
    } else {
      return {
        success: false,
        error: data.status,
      }
    }
  } catch (error) {
    console.error('逆ジオコーディングエラー:', error)
    return {
      success: false,
      error: '逆ジオコーディングに失敗しました',
    }
  }
}
```

```typescript
'use client'

import { useState } from 'react'
import { geocodeAddress } from '@/app/actions/geocoding'

export default function GeocodeForm() {
  const [address, setAddress] = useState('')
  const [result, setResult] = useState<any>(null)
  const [loading, setLoading] = useState(false)

  const handleGeocode = async () => {
    setLoading(true)
    const geocoded = await geocodeAddress(address)
    setResult(geocoded)
    setLoading(false)
  }

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        <input
          type="text"
          value={address}
          onChange={(e) => setAddress(e.target.value)}
          placeholder="住所を入力..."
          className="flex-1 p-2 border rounded"
        />
        <button
          onClick={handleGeocode}
          disabled={loading}
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
        >
          {loading ? '検索中...' : '座標取得'}
        </button>
      </div>

      {result?.success && (
        <div className="p-4 bg-green-50 border border-green-200 rounded">
          <p>緯度: {result.latitude}</p>
          <p>経度: {result.longitude}</p>
          <p>住所: {result.formatted_address}</p>
        </div>
      )}
    </div>
  )
}
```

## 実践的な使用例

### 1. 店舗検索システム

```typescript
// app/api/stores/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const lat = parseFloat(searchParams.get('lat') || '0')
  const lng = parseFloat(searchParams.get('lng') || '0')
  const radius = parseFloat(searchParams.get('radius') || '5') // km

  try {
    // Haversine式で近隣店舗を検索
    const stores = await prisma.$queryRaw`
      SELECT
        id,
        name,
        address,
        latitude,
        longitude,
        (
          6371 * acos(
            cos(radians(${lat})) *
            cos(radians(latitude)) *
            cos(radians(longitude) - radians(${lng})) +
            sin(radians(${lat})) *
            sin(radians(latitude))
          )
        ) AS distance
      FROM stores
      HAVING distance < ${radius}
      ORDER BY distance
      LIMIT 20
    `

    return NextResponse.json({ success: true, stores })
  } catch (error) {
    console.error('店舗検索エラー:', error)
    return NextResponse.json(
      { success: false, error: '検索に失敗しました' },
      { status: 500 }
    )
  }
}
```

```typescript
'use client'

import { MapContainer, TileLayer, Marker, Popup, Circle } from 'react-leaflet'
import { useState, useEffect } from 'react'
import L from 'leaflet'

interface Store {
  id: string
  name: string
  address: string
  latitude: number
  longitude: number
  distance: number
}

export default function StoreLocator() {
  const [currentLocation, setCurrentLocation] = useState<[number, number] | null>(null)
  const [stores, setStores] = useState<Store[]>([])
  const [radius, setRadius] = useState(5)

  useEffect(() => {
    if (currentLocation) {
      searchStores()
    }
  }, [currentLocation, radius])

  const getCurrentLocation = () => {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setCurrentLocation([position.coords.latitude, position.coords.longitude])
      },
      (error) => {
        console.error('位置情報取得エラー:', error)
      }
    )
  }

  const searchStores = async () => {
    if (!currentLocation) return

    const response = await fetch(
      `/api/stores?lat=${currentLocation[0]}&lng=${currentLocation[1]}&radius=${radius}`
    )
    const data = await response.json()

    if (data.success) {
      setStores(data.stores)
    }
  }

  const icon = L.icon({
    iconUrl: '/marker-icon.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41],
  })

  return (
    <div className="space-y-4">
      <div className="flex gap-4 items-center">
        <button
          onClick={getCurrentLocation}
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
        >
          現在地を取得
        </button>

        <div className="flex items-center gap-2">
          <label>検索半径:</label>
          <select
            value={radius}
            onChange={(e) => setRadius(Number(e.target.value))}
            className="p-2 border rounded"
          >
            <option value={1}>1 km</option>
            <option value={3}>3 km</option>
            <option value={5}>5 km</option>
            <option value={10}>10 km</option>
          </select>
        </div>
      </div>

      {currentLocation && (
        <MapContainer
          center={currentLocation}
          zoom={13}
          style={{ height: '500px' }}
        >
          <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />

          <Circle
            center={currentLocation}
            radius={radius * 1000}
            pathOptions={{ color: 'blue', fillOpacity: 0.1 }}
          />

          <Marker position={currentLocation} icon={icon}>
            <Popup>現在地</Popup>
          </Marker>

          {stores.map((store) => (
            <Marker
              key={store.id}
              position={[store.latitude, store.longitude]}
              icon={icon}
            >
              <Popup>
                <div>
                  <h3 className="font-bold">{store.name}</h3>
                  <p className="text-sm">{store.address}</p>
                  <p className="text-sm text-gray-600">
                    距離: {store.distance.toFixed(2)} km
                  </p>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      )}

      <div className="space-y-2">
        <h2 className="text-xl font-bold">検索結果 ({stores.length}件)</h2>
        {stores.map((store) => (
          <div key={store.id} className="p-3 border rounded">
            <h3 className="font-semibold">{store.name}</h3>
            <p className="text-sm text-gray-600">{store.address}</p>
            <p className="text-sm">距離: {store.distance.toFixed(2)} km</p>
          </div>
        ))}
      </div>
    </div>
  )
}
```

### 2. 配送追跡システム

```typescript
'use client'

import Map, { Marker, Source, Layer } from 'react-map-gl'
import { useState, useEffect } from 'react'
import 'mapbox-gl/dist/mapbox-gl.css'

interface DeliveryStatus {
  driverId: string
  currentLocation: { lng: number; lat: number }
  destination: { lng: number; lat: number }
  route: number[][]
  estimatedArrival: string
  status: 'pickup' | 'in_transit' | 'arriving' | 'delivered'
}

export default function DeliveryTracking({ orderId }: { orderId: string }) {
  const [delivery, setDelivery] = useState<DeliveryStatus | null>(null)

  useEffect(() => {
    // リアルタイム更新（WebSocketまたはポーリング）
    const interval = setInterval(async () => {
      const response = await fetch(`/api/delivery/${orderId}`)
      const data = await response.json()
      if (data.success) {
        setDelivery(data.delivery)
      }
    }, 5000) // 5秒ごとに更新

    return () => clearInterval(interval)
  }, [orderId])

  if (!delivery) {
    return <div>配送情報を読み込み中...</div>
  }

  const routeGeoJSON = {
    type: 'Feature' as const,
    geometry: {
      type: 'LineString' as const,
      coordinates: delivery.route,
    },
    properties: {},
  }

  const lineLayerStyle = {
    id: 'route',
    type: 'line' as const,
    paint: {
      'line-color': '#3b82f6',
      'line-width': 4,
    },
  }

  return (
    <div className="space-y-4">
      <div className="p-4 bg-blue-50 border border-blue-200 rounded">
        <p className="font-semibold">配送状況: {delivery.status}</p>
        <p className="text-sm">到着予定: {delivery.estimatedArrival}</p>
      </div>

      <Map
        initialViewState={{
          longitude: delivery.currentLocation.lng,
          latitude: delivery.currentLocation.lat,
          zoom: 13,
        }}
        style={{ width: '100%', height: 500 }}
        mapStyle="mapbox://styles/mapbox/streets-v12"
        mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_TOKEN}
      >
        <Source id="route-source" type="geojson" data={routeGeoJSON}>
          <Layer {...lineLayerStyle} />
        </Source>

        {/* ドライバー位置 */}
        <Marker
          longitude={delivery.currentLocation.lng}
          latitude={delivery.currentLocation.lat}
        >
          <div className="w-8 h-8 bg-blue-600 rounded-full border-4 border-white shadow-lg flex items-center justify-center text-white font-bold">
            🚚
          </div>
        </Marker>

        {/* 配送先 */}
        <Marker
          longitude={delivery.destination.lng}
          latitude={delivery.destination.lat}
        >
          <div className="w-8 h-8 bg-green-600 rounded-full border-4 border-white shadow-lg flex items-center justify-center text-white">
            📍
          </div>
        </Marker>
      </Map>
    </div>
  )
}
```

## ベストプラクティス

### 1. APIキーの保護

```typescript
// ❌ 悪い例: クライアントサイドで直接APIキーを使用
const apiKey = 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXX'

// ✅ 良い例: 環境変数を使用
const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY

// さらに良い: サーバーサイドでプロキシ
// app/api/maps/proxy/route.ts
export async function POST(request: NextRequest) {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY // NEXT_PUBLIC_なし
  // サーバーサイドでGoogle Maps APIを呼び出し
}
```

### 2. パフォーマンス最適化

```typescript
// マーカークラスタリング（react-leaflet）
npm install react-leaflet-cluster

import MarkerClusterGroup from 'react-leaflet-cluster'

<MapContainer>
  <TileLayer />
  <MarkerClusterGroup>
    {locations.map((loc) => (
      <Marker key={loc.id} position={loc.position} />
    ))}
  </MarkerClusterGroup>
</MapContainer>

// 遅延読み込み
const Map = dynamic(() => import('@/components/Map'), {
  ssr: false,
  loading: () => <MapSkeleton />,
})
```

### 3. エラーハンドリング

```typescript
'use client'

import { MapContainer, TileLayer } from 'react-leaflet'
import { useState } from 'react'

export default function MapWithErrorBoundary() {
  const [mapError, setMapError] = useState<Error | null>(null)

  if (mapError) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 rounded">
        <p className="font-semibold">地図の読み込みに失敗しました</p>
        <p className="text-sm">{mapError.message}</p>
        <button
          onClick={() => setMapError(null)}
          className="mt-2 px-3 py-1 bg-red-600 text-white rounded"
        >
          再試行
        </button>
      </div>
    )
  }

  return (
    <MapContainer
      center={[35.6812, 139.7671]}
      zoom={13}
      style={{ height: '400px' }}
      whenReady={() => console.log('地図準備完了')}
    >
      <TileLayer
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        eventHandlers={{
          tileerror: (error) => {
            console.error('タイル読み込みエラー:', error)
            setMapError(new Error('地図タイルの読み込みに失敗しました'))
          },
        }}
      />
    </MapContainer>
  )
}
```

### 4. アクセシビリティ

```typescript
<MapContainer
  aria-label="店舗所在地マップ"
  role="application"
>
  <TileLayer />
  <Marker position={position}>
    <Popup aria-label="店舗情報">
      <h3>店舗名</h3>
      <p>住所情報</p>
    </Popup>
  </Marker>
</MapContainer>

// キーボード操作のサポート
<div
  role="button"
  tabIndex={0}
  onKeyPress={(e) => e.key === 'Enter' && handleMarkerClick()}
  onClick={handleMarkerClick}
>
  マーカー
</div>
```

## まとめ

### 用途別推奨ライブラリ

| 用途 | 推奨ライブラリ | 理由 |
|------|--------------|------|
| 基本的な地図表示 | React Leaflet | 無料、軽量、十分な機能 |
| 日本国内サービス | Google Maps | 詳細な日本地図、Places API |
| デザイン重視 | Mapbox | 美しいスタイル、3D対応 |
| リアルタイム追跡 | Mapbox | パフォーマンス、WebGL |

### 実装時のチェックリスト

- [ ] APIキーを環境変数で管理
- [ ] 動的インポートでSSR回避（Next.js）
- [ ] エラーハンドリングを実装
- [ ] レスポンシブ対応
- [ ] アクセシビリティ考慮
- [ ] マーカークラスタリング（大量マーカー時）
- [ ] 位置情報の権限リクエスト
- [ ] 利用規約の遵守

このガイドを参考に、地図機能を適切に実装してください。
