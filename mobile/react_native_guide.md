# React Native 完全ガイド

## 目次
1. [React Nativeとは](#react-nativeとは)
2. [セットアップ](#セットアップ)
3. [コンポーネント](#コンポーネント)
4. [ナビゲーション](#ナビゲーション)
5. [状態管理](#状態管理)
6. [ネイティブモジュール](#ネイティブモジュール)
7. [パフォーマンス最適化](#パフォーマンス最適化)
8. [ベストプラクティス](#ベストプラクティス)

---

## React Nativeとは

React Nativeは、JavaScriptとReactを使ってネイティブモバイルアプリを開発できるフレームワークです。

### 主な特徴

- **クロスプラットフォーム**: iOS/Android両対応
- **ネイティブパフォーマンス**: ネイティブコンポーネントを使用
- **Hot Reloading**: 高速な開発サイクル
- **大規模エコシステム**: 豊富なライブラリ

---

## セットアップ

### 新規プロジェクト作成

```bash
npx react-native init MyApp --template react-native-template-typescript
cd MyApp
```

### 実行

```bash
# iOS
npx react-native run-ios

# Android
npx react-native run-android
```

### 基本構成

```typescript
// App.tsx
import React from 'react';
import { SafeAreaView, StyleSheet, Text, StatusBar } from 'react-native';

function App(): React.JSX.Element {
  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" />
      <Text style={styles.text}>Hello React Native!</Text>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  text: {
    fontSize: 20,
    fontWeight: 'bold',
  },
});

export default App;
```

---

## コンポーネント

### 基本コンポーネント

```typescript
import { View, Text, Image, ScrollView, TextInput, Button } from 'react-native';

export function BasicComponents() {
  return (
    <ScrollView>
      <View style={{ padding: 20 }}>
        <Text>テキスト</Text>

        <Image
          source={{ uri: 'https://example.com/image.png' }}
          style={{ width: 200, height: 200 }}
        />

        <TextInput
          placeholder="入力してください"
          style={{
            borderWidth: 1,
            borderColor: '#ccc',
            padding: 10,
          }}
        />

        <Button title="ボタン" onPress={() => console.log('Pressed')} />
      </View>
    </ScrollView>
  );
}
```

### FlatList

```typescript
import { FlatList, Text, View } from 'react-native';

interface Item {
  id: string;
  title: string;
}

export function ItemList({ items }: { items: Item[] }) {
  return (
    <FlatList
      data={items}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => (
        <View style={{ padding: 10 }}>
          <Text>{item.title}</Text>
        </View>
      )}
      ItemSeparatorComponent={() => (
        <View style={{ height: 1, backgroundColor: '#ccc' }} />
      )}
      ListEmptyComponent={() => <Text>データがありません</Text>}
      onEndReached={() => console.log('End reached')}
      onEndReachedThreshold={0.5}
    />
  );
}
```

### TouchableOpacity

```typescript
import { TouchableOpacity, Text } from 'react-native';

export function CustomButton({ title, onPress }: { title: string; onPress: () => void }) {
  return (
    <TouchableOpacity
      onPress={onPress}
      style={{
        backgroundColor: '#007AFF',
        padding: 15,
        borderRadius: 8,
        alignItems: 'center',
      }}
    >
      <Text style={{ color: 'white', fontSize: 16, fontWeight: 'bold' }}>
        {title}
      </Text>
    </TouchableOpacity>
  );
}
```

---

## ナビゲーション

### React Navigation セットアップ

```bash
npm install @react-navigation/native
npm install react-native-screens react-native-safe-area-context
npm install @react-navigation/native-stack
```

### Stack Navigator

```typescript
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

type RootStackParamList = {
  Home: undefined;
  Details: { itemId: string; title: string };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen name="Home" component={HomeScreen} />
        <Stack.Screen name="Details" component={DetailsScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

function HomeScreen({ navigation }: any) {
  return (
    <View>
      <Button
        title="詳細へ"
        onPress={() =>
          navigation.navigate('Details', {
            itemId: '123',
            title: 'アイテム詳細',
          })
        }
      />
    </View>
  );
}

function DetailsScreen({ route, navigation }: any) {
  const { itemId, title } = route.params;

  return (
    <View>
      <Text>{title}</Text>
      <Text>Item ID: {itemId}</Text>
      <Button title="戻る" onPress={() => navigation.goBack()} />
    </View>
  );
}
```

### Tab Navigator

```bash
npm install @react-navigation/bottom-tabs
```

```typescript
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import Icon from 'react-native-vector-icons/Ionicons';

const Tab = createBottomTabNavigator();

export function TabNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: string = '';

          if (route.name === 'Home') {
            iconName = focused ? 'home' : 'home-outline';
          } else if (route.name === 'Settings') {
            iconName = focused ? 'settings' : 'settings-outline';
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#007AFF',
        tabBarInactiveTintColor: 'gray',
      })}
    >
      <Tab.Screen name="Home" component={HomeScreen} />
      <Tab.Screen name="Settings" component={SettingsScreen} />
    </Tab.Navigator>
  );
}
```

---

## 状態管理

### Context API

```typescript
import React, { createContext, useContext, useState } from 'react';

interface AuthContextType {
  user: { id: string; name: string } | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<{ id: string; name: string } | null>(null);

  const login = async (email: string, password: string) => {
    // ログイン処理
    const user = await authAPI.login(email, password);
    setUser(user);
  };

  const logout = () => {
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}

// 使用例
function ProfileScreen() {
  const { user, logout } = useAuth();

  return (
    <View>
      <Text>{user?.name}</Text>
      <Button title="ログアウト" onPress={logout} />
    </View>
  );
}
```

### Redux Toolkit

```bash
npm install @reduxjs/toolkit react-redux
```

```typescript
import { configureStore, createSlice, PayloadAction } from '@reduxjs/toolkit';
import { Provider, useDispatch, useSelector } from 'react-redux';

interface CounterState {
  value: number;
}

const counterSlice = createSlice({
  name: 'counter',
  initialState: { value: 0 } as CounterState,
  reducers: {
    increment: (state) => {
      state.value += 1;
    },
    decrement: (state) => {
      state.value -= 1;
    },
    incrementByAmount: (state, action: PayloadAction<number>) => {
      state.value += action.payload;
    },
  },
});

export const { increment, decrement, incrementByAmount } = counterSlice.actions;

const store = configureStore({
  reducer: {
    counter: counterSlice.reducer,
  },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

// App
export function App() {
  return (
    <Provider store={store}>
      <CounterScreen />
    </Provider>
  );
}

// コンポーネント
function CounterScreen() {
  const count = useSelector((state: RootState) => state.counter.value);
  const dispatch = useDispatch<AppDispatch>();

  return (
    <View>
      <Text>{count}</Text>
      <Button title="+" onPress={() => dispatch(increment())} />
      <Button title="-" onPress={() => dispatch(decrement())} />
    </View>
  );
}
```

---

## ネイティブモジュール

### AsyncStorage

```bash
npm install @react-native-async-storage/async-storage
```

```typescript
import AsyncStorage from '@react-native-async-storage/async-storage';

// データ保存
export async function saveData(key: string, value: any) {
  try {
    await AsyncStorage.setItem(key, JSON.stringify(value));
  } catch (error) {
    console.error('Failed to save data:', error);
  }
}

// データ取得
export async function getData(key: string) {
  try {
    const value = await AsyncStorage.getItem(key);
    return value ? JSON.parse(value) : null;
  } catch (error) {
    console.error('Failed to get data:', error);
    return null;
  }
}

// データ削除
export async function removeData(key: string) {
  try {
    await AsyncStorage.removeItem(key);
  } catch (error) {
    console.error('Failed to remove data:', error);
  }
}
```

### Camera

```bash
npm install react-native-vision-camera
```

```typescript
import { Camera, useCameraDevices } from 'react-native-vision-camera';
import { useState } from 'react';

export function CameraScreen() {
  const devices = useCameraDevices();
  const device = devices.back;
  const [hasPermission, setHasPermission] = useState(false);

  useEffect(() => {
    (async () => {
      const status = await Camera.requestCameraPermission();
      setHasPermission(status === 'authorized');
    })();
  }, []);

  if (!device || !hasPermission) {
    return <Text>No camera access</Text>;
  }

  return (
    <Camera
      style={{ flex: 1 }}
      device={device}
      isActive={true}
    />
  );
}
```

### Geolocation

```bash
npm install @react-native-community/geolocation
```

```typescript
import Geolocation from '@react-native-community/geolocation';

export function useLocation() {
  const [location, setLocation] = useState<{
    latitude: number;
    longitude: number;
  } | null>(null);

  useEffect(() => {
    Geolocation.getCurrentPosition(
      (position) => {
        setLocation({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
        });
      },
      (error) => {
        console.error('Location error:', error);
      },
      { enableHighAccuracy: true, timeout: 20000, maximumAge: 1000 }
    );
  }, []);

  return location;
}
```

---

## パフォーマンス最適化

### React.memo

```typescript
import React from 'react';

const ExpensiveComponent = React.memo(({ data }: { data: any }) => {
  console.log('Rendering ExpensiveComponent');

  return (
    <View>
      <Text>{data.title}</Text>
    </View>
  );
});
```

### useCallback / useMemo

```typescript
import { useCallback, useMemo } from 'react';

export function OptimizedList({ items }: { items: Item[] }) {
  // コールバックをメモ化
  const handlePress = useCallback((id: string) => {
    console.log('Pressed:', id);
  }, []);

  // 計算結果をメモ化
  const sortedItems = useMemo(() => {
    return items.sort((a, b) => a.title.localeCompare(b.title));
  }, [items]);

  return (
    <FlatList
      data={sortedItems}
      renderItem={({ item }) => (
        <TouchableOpacity onPress={() => handlePress(item.id)}>
          <Text>{item.title}</Text>
        </TouchableOpacity>
      )}
    />
  );
}
```

### Hermes

```javascript
// android/app/build.gradle
project.ext.react = [
    enableHermes: true, // Hermesを有効化
]
```

---

## ベストプラクティス

### 1. TypeScript活用

```typescript
interface User {
  id: string;
  name: string;
  email: string;
}

interface UserCardProps {
  user: User;
  onPress: (userId: string) => void;
}

export function UserCard({ user, onPress }: UserCardProps) {
  return (
    <TouchableOpacity onPress={() => onPress(user.id)}>
      <Text>{user.name}</Text>
      <Text>{user.email}</Text>
    </TouchableOpacity>
  );
}
```

### 2. エラーバウンダリ

```typescript
import React from 'react';

interface State {
  hasError: boolean;
}

export class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  State
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <View>
          <Text>エラーが発生しました</Text>
        </View>
      );
    }

    return this.props.children;
  }
}
```

### 3. テスト

```bash
npm install --save-dev @testing-library/react-native
```

```typescript
import { render, fireEvent } from '@testing-library/react-native';
import { CustomButton } from './CustomButton';

describe('CustomButton', () => {
  it('should call onPress when pressed', () => {
    const onPress = jest.fn();
    const { getByText } = render(
      <CustomButton title="Test" onPress={onPress} />
    );

    fireEvent.press(getByText('Test'));
    expect(onPress).toHaveBeenCalledTimes(1);
  });
});
```

### 4. 環境変数

```bash
npm install react-native-config
```

```bash
# .env
API_URL=https://api.example.com
API_KEY=your-api-key
```

```typescript
import Config from 'react-native-config';

const API_URL = Config.API_URL;
const API_KEY = Config.API_KEY;
```

### 5. デバッグ

```typescript
// Reactotron
import Reactotron from 'reactotron-react-native';

Reactotron.configure()
  .useReactNative()
  .connect();

console.tron = Reactotron;

// 使用例
console.tron.log('Debug message');
```

---

## 参考リンク

- [React Native Documentation](https://reactnative.dev/)
- [React Navigation](https://reactnavigation.org/)
- [Awesome React Native](https://github.com/jondot/awesome-react-native)
