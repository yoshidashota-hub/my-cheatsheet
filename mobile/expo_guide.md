# Expo 完全ガイド

## 目次
1. [Expoとは](#expoとは)
2. [セットアップ](#セットアップ)
3. [Expo Router](#expo-router)
4. [Expo SDK](#expo-sdk)
5. [OTA Updates](#ota-updates)
6. [ビルド & デプロイ](#ビルドデプロイ)
7. [開発ワークフロー](#開発ワークフロー)
8. [ベストプラクティス](#ベストプラクティス)

---

## Expoとは

Expoは、React Nativeアプリ開発を簡素化するフレームワークとプラットフォームです。

### 主な特徴

- **簡単なセットアップ**: XcodeやAndroid Studio不要
- **豊富なAPI**: カメラ、位置情報などすぐに使える
- **OTA Updates**: アプリストア不要で更新可能
- **EAS Build**: クラウドビルドサービス

---

## セットアップ

### 新規プロジェクト作成

```bash
npx create-expo-app my-app
cd my-app
```

### 実行

```bash
# 開発サーバー起動
npx expo start

# iOS Simulator
npx expo start --ios

# Android Emulator
npx expo start --android

# Web
npx expo start --web
```

### プロジェクト構成

```
my-app/
├── app/              # Expo Router (v3+)
│   ├── (tabs)/
│   │   ├── index.tsx
│   │   └── profile.tsx
│   └── _layout.tsx
├── components/
├── constants/
├── assets/
├── app.json
└── package.json
```

---

## Expo Router

### ファイルベースルーティング

```typescript
// app/_layout.tsx
import { Stack } from 'expo-router';

export default function RootLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Home' }} />
      <Stack.Screen name="details" options={{ title: 'Details' }} />
    </Stack>
  );
}

// app/index.tsx
import { View, Text, Button } from 'react-native';
import { router } from 'expo-router';

export default function HomeScreen() {
  return (
    <View>
      <Text>Home Screen</Text>
      <Button
        title="詳細へ"
        onPress={() => router.push('/details')}
      />
    </View>
  );
}

// app/details.tsx
export default function DetailsScreen() {
  return (
    <View>
      <Text>Details Screen</Text>
    </View>
  );
}
```

### タブナビゲーション

```typescript
// app/(tabs)/_layout.tsx
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: '#007AFF',
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="home" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="person" size={size} color={color} />
          ),
        }}
      />
    </Tabs>
  );
}
```

### 動的ルート

```typescript
// app/posts/[id].tsx
import { useLocalSearchParams } from 'expo-router';

export default function PostScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();

  return (
    <View>
      <Text>Post ID: {id}</Text>
    </View>
  );
}

// ナビゲーション
router.push(`/posts/${postId}`);
```

---

## Expo SDK

### カメラ

```bash
npx expo install expo-camera
```

```typescript
import { Camera, CameraType } from 'expo-camera';
import { useState } from 'react';

export function CameraScreen() {
  const [type, setType] = useState(CameraType.back);
  const [permission, requestPermission] = Camera.useCameraPermissions();

  if (!permission) {
    return <View />;
  }

  if (!permission.granted) {
    return (
      <View>
        <Text>カメラへのアクセスが必要です</Text>
        <Button title="許可する" onPress={requestPermission} />
      </View>
    );
  }

  return (
    <Camera style={{ flex: 1 }} type={type}>
      <Button
        title="カメラ切り替え"
        onPress={() => {
          setType(
            type === CameraType.back ? CameraType.front : CameraType.back
          );
        }}
      />
    </Camera>
  );
}
```

### Location

```bash
npx expo install expo-location
```

```typescript
import * as Location from 'expo-location';
import { useState, useEffect } from 'react';

export function useLocation() {
  const [location, setLocation] = useState<Location.LocationObject | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      const { status } = await Location.requestForegroundPermissionsAsync();

      if (status !== 'granted') {
        setError('Permission denied');
        return;
      }

      const location = await Location.getCurrentPositionAsync({});
      setLocation(location);
    })();
  }, []);

  return { location, error };
}

// 使用例
export function LocationScreen() {
  const { location, error } = useLocation();

  if (error) {
    return <Text>Error: {error}</Text>;
  }

  if (!location) {
    return <Text>Loading...</Text>;
  }

  return (
    <View>
      <Text>Latitude: {location.coords.latitude}</Text>
      <Text>Longitude: {location.coords.longitude}</Text>
    </View>
  );
}
```

### Notifications

```bash
npx expo install expo-notifications
```

```typescript
import * as Notifications from 'expo-notifications';
import { useState, useEffect, useRef } from 'react';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export function useNotifications() {
  const [expoPushToken, setExpoPushToken] = useState<string>('');
  const notificationListener = useRef<any>();
  const responseListener = useRef<any>();

  useEffect(() => {
    registerForPushNotificationsAsync().then((token) =>
      setExpoPushToken(token || '')
    );

    notificationListener.current = Notifications.addNotificationReceivedListener(
      (notification) => {
        console.log('Notification received:', notification);
      }
    );

    responseListener.current = Notifications.addNotificationResponseReceivedListener(
      (response) => {
        console.log('Notification response:', response);
      }
    );

    return () => {
      Notifications.removeNotificationSubscription(
        notificationListener.current
      );
      Notifications.removeNotificationSubscription(responseListener.current);
    };
  }, []);

  return expoPushToken;
}

async function registerForPushNotificationsAsync() {
  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;

  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }

  if (finalStatus !== 'granted') {
    return;
  }

  const token = (await Notifications.getExpoPushTokenAsync()).data;
  return token;
}

// ローカル通知送信
async function sendLocalNotification() {
  await Notifications.scheduleNotificationAsync({
    content: {
      title: 'タイトル',
      body: '本文',
      data: { data: 'goes here' },
    },
    trigger: { seconds: 2 },
  });
}
```

### Image Picker

```bash
npx expo install expo-image-picker
```

```typescript
import * as ImagePicker from 'expo-image-picker';
import { useState } from 'react';

export function ImagePickerScreen() {
  const [image, setImage] = useState<string | null>(null);

  const pickImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [4, 3],
      quality: 1,
    });

    if (!result.canceled) {
      setImage(result.assets[0].uri);
    }
  };

  return (
    <View>
      <Button title="画像を選択" onPress={pickImage} />
      {image && (
        <Image source={{ uri: image }} style={{ width: 200, height: 200 }} />
      )}
    </View>
  );
}
```

### SecureStore

```bash
npx expo install expo-secure-store
```

```typescript
import * as SecureStore from 'expo-secure-store';

// データ保存
export async function saveSecure(key: string, value: string) {
  await SecureStore.setItemAsync(key, value);
}

// データ取得
export async function getSecure(key: string) {
  return await SecureStore.getItemAsync(key);
}

// データ削除
export async function deleteSecure(key: string) {
  await SecureStore.deleteItemAsync(key);
}

// 使用例
await saveSecure('userToken', token);
const token = await getSecure('userToken');
```

---

## OTA Updates

### expo-updates設定

```bash
npx expo install expo-updates
```

```typescript
// app.json
{
  "expo": {
    "updates": {
      "enabled": true,
      "checkAutomatically": "ON_LOAD",
      "fallbackToCacheTimeout": 0
    },
    "runtimeVersion": {
      "policy": "sdkVersion"
    }
  }
}
```

### 更新チェック

```typescript
import * as Updates from 'expo-updates';
import { useEffect } from 'react';

export function useAppUpdates() {
  useEffect(() => {
    async function checkForUpdates() {
      try {
        const update = await Updates.checkForUpdateAsync();

        if (update.isAvailable) {
          await Updates.fetchUpdateAsync();
          await Updates.reloadAsync();
        }
      } catch (error) {
        console.error('Update check failed:', error);
      }
    }

    checkForUpdates();
  }, []);
}
```

---

## ビルド & デプロイ

### EAS Build セットアップ

```bash
npm install -g eas-cli
eas login
eas build:configure
```

### ビルド

```bash
# iOS
eas build --platform ios

# Android
eas build --platform android

# Both
eas build --platform all
```

### eas.json設定

```json
{
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal",
      "ios": {
        "simulator": true
      }
    },
    "production": {
      "autoIncrement": true
    }
  },
  "submit": {
    "production": {}
  }
}
```

### アプリストア提出

```bash
# iOS App Store
eas submit --platform ios

# Google Play
eas submit --platform android
```

---

## 開発ワークフロー

### 開発ビルド

```bash
# 開発ビルド作成
eas build --profile development --platform ios

# デバイスにインストール
eas build:run -p ios
```

### Expo Go vs Development Build

| 機能 | Expo Go | Development Build |
|------|---------|-------------------|
| カスタムネイティブコード | ❌ | ✅ |
| サードパーティライブラリ | 制限あり | 全て使用可能 |
| ビルド時間 | 不要 | 必要 |
| 開発速度 | 高速 | 中速 |

### 環境変数

```bash
# .env
API_URL=https://api.example.com
API_KEY=your-api-key
```

```typescript
import Constants from 'expo-constants';

const apiUrl = Constants.expoConfig?.extra?.apiUrl;
const apiKey = Constants.expoConfig?.extra?.apiKey;
```

```javascript
// app.config.js
export default {
  expo: {
    extra: {
      apiUrl: process.env.API_URL,
      apiKey: process.env.API_KEY,
    },
  },
};
```

---

## ベストプラクティス

### 1. プリロード

```typescript
import { useFonts } from 'expo-font';
import * as SplashScreen from 'expo-splash-screen';
import { useEffect } from 'react';

SplashScreen.preventAutoHideAsync();

export default function App() {
  const [fontsLoaded] = useFonts({
    'Inter-Regular': require('./assets/fonts/Inter-Regular.ttf'),
    'Inter-Bold': require('./assets/fonts/Inter-Bold.ttf'),
  });

  useEffect(() => {
    if (fontsLoaded) {
      SplashScreen.hideAsync();
    }
  }, [fontsLoaded]);

  if (!fontsLoaded) {
    return null;
  }

  return <RootNavigator />;
}
```

### 2. エラーハンドリング

```typescript
import * as Sentry from 'sentry-expo';

Sentry.init({
  dsn: 'YOUR_SENTRY_DSN',
  enableInExpoDevelopment: false,
  debug: __DEV__,
});

// エラーキャプチャ
try {
  await riskyOperation();
} catch (error) {
  Sentry.Native.captureException(error);
}
```

### 3. パフォーマンス監視

```typescript
import { startTransition } from 'react';

// 非緊急の更新を遅延
function handleChange(value: string) {
  startTransition(() => {
    setSearchQuery(value);
  });
}
```

### 4. アプリアイコン & スプラッシュ

```json
// app.json
{
  "expo": {
    "icon": "./assets/icon.png",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "ios": {
      "icon": "./assets/ios-icon.png"
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      }
    }
  }
}
```

### 5. テスト

```bash
npm install --save-dev jest @testing-library/react-native
```

```typescript
import { render, fireEvent } from '@testing-library/react-native';
import { Button } from './Button';

describe('Button', () => {
  it('should render correctly', () => {
    const { getByText } = render(<Button title="Test" />);
    expect(getByText('Test')).toBeTruthy();
  });

  it('should call onPress', () => {
    const onPress = jest.fn();
    const { getByText } = render(<Button title="Test" onPress={onPress} />);

    fireEvent.press(getByText('Test'));
    expect(onPress).toHaveBeenCalled();
  });
});
```

### 6. CI/CD (GitHub Actions)

```yaml
# .github/workflows/build.yml
name: EAS Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: actions/setup-node@v3
        with:
          node-version: 18

      - name: Setup Expo
        uses: expo/expo-github-action@v8
        with:
          expo-version: latest
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}

      - name: Install dependencies
        run: npm install

      - name: Build
        run: eas build --platform all --non-interactive
```

---

## 参考リンク

- [Expo Documentation](https://docs.expo.dev/)
- [Expo Router](https://docs.expo.dev/router/introduction/)
- [EAS Build](https://docs.expo.dev/build/introduction/)
- [Expo SDK](https://docs.expo.dev/versions/latest/)
