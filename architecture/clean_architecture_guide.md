# クリーンアーキテクチャ完全ガイド

## 目次
- [クリーンアーキテクチャとは](#クリーンアーキテクチャとは)
- [レイヤー構成](#レイヤー構成)
- [依存性逆転の原則](#依存性逆転の原則)
- [実装例](#実装例)
- [ヘキサゴナルアーキテクチャ](#ヘキサゴナルアーキテクチャ)
- [メリット・デメリット](#メリットデメリット)

---

## クリーンアーキテクチャとは

Robert C. Martin (Uncle Bob) が提唱したソフトウェアアーキテクチャパターン。

### 核心原則

```
1. 独立性
   - フレームワーク非依存
   - UI非依存
   - データベース非依存
   - 外部エージェント非依存

2. テスト可能性
   - ビジネスロジックを単独でテスト可能

3. 依存性ルール
   - 依存の方向は常に内側（抽象）へ
   - 内側のレイヤーは外側を知らない
```

### 同心円モデル

```
┌─────────────────────────────────────┐
│  Frameworks & Drivers (最外層)      │  ← Web, DB, UI
├─────────────────────────────────────┤
│  Interface Adapters (アダプター層)   │  ← Controllers, Presenters
├─────────────────────────────────────┤
│  Application Business Rules (UC層)   │  ← Use Cases
├─────────────────────────────────────┤
│  Enterprise Business Rules (中心)    │  ← Entities
└─────────────────────────────────────┘

依存の方向: 外 → 内（内側は外側を知らない）
```

---

## レイヤー構成

### 1. Entities（エンティティ層）

ビジネスルールをカプセル化。最も安定したレイヤー。

```typescript
// entities/User.ts
export class User {
  constructor(
    public readonly id: string,
    public readonly email: string,
    public readonly name: string,
    private passwordHash: string
  ) {}

  // ビジネスルール
  isValidEmail(): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(this.email)
  }

  verifyPassword(password: string, hasher: PasswordHasher): boolean {
    return hasher.verify(password, this.passwordHash)
  }

  updateName(newName: string): User {
    if (!newName || newName.length < 2) {
      throw new Error('Invalid name')
    }
    return new User(this.id, this.email, newName, this.passwordHash)
  }
}
```

### 2. Use Cases（ユースケース層）

アプリケーション固有のビジネスルール。

```typescript
// usecases/CreateUser.ts
export interface CreateUserInput {
  email: string
  name: string
  password: string
}

export interface CreateUserOutput {
  id: string
  email: string
  name: string
}

export interface UserRepository {
  save(user: User): Promise<User>
  findByEmail(email: string): Promise<User | null>
}

export interface PasswordHasher {
  hash(password: string): Promise<string>
}

export class CreateUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private passwordHasher: PasswordHasher
  ) {}

  async execute(input: CreateUserInput): Promise<CreateUserOutput> {
    // バリデーション
    if (!input.email || !input.name || !input.password) {
      throw new Error('Missing required fields')
    }

    // 重複チェック
    const existing = await this.userRepository.findByEmail(input.email)
    if (existing) {
      throw new Error('User already exists')
    }

    // パスワードハッシュ化
    const passwordHash = await this.passwordHasher.hash(input.password)

    // エンティティ作成
    const user = new User(
      generateId(),
      input.email,
      input.name,
      passwordHash
    )

    // 保存
    const saved = await this.userRepository.save(user)

    return {
      id: saved.id,
      email: saved.email,
      name: saved.name
    }
  }
}
```

### 3. Interface Adapters（アダプター層）

外部とビジネスロジックの変換。

```typescript
// adapters/controllers/UserController.ts
import { Request, Response } from 'express'

export class UserController {
  constructor(private createUserUseCase: CreateUserUseCase) {}

  async createUser(req: Request, res: Response) {
    try {
      const { email, name, password } = req.body

      const result = await this.createUserUseCase.execute({
        email,
        name,
        password
      })

      res.status(201).json(result)
    } catch (error) {
      if (error.message === 'User already exists') {
        res.status(409).json({ error: error.message })
      } else {
        res.status(400).json({ error: error.message })
      }
    }
  }
}
```

```typescript
// adapters/presenters/UserPresenter.ts
export class UserPresenter {
  present(user: User) {
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      createdAt: user.createdAt.toISOString()
    }
  }

  presentList(users: User[]) {
    return users.map(user => this.present(user))
  }
}
```

### 4. Frameworks & Drivers（最外層）

フレームワーク、ツール、DB等の実装。

```typescript
// infrastructure/database/UserRepositoryImpl.ts
import { PrismaClient } from '@prisma/client'

export class UserRepositoryImpl implements UserRepository {
  constructor(private prisma: PrismaClient) {}

  async save(user: User): Promise<User> {
    const data = await this.prisma.user.create({
      data: {
        id: user.id,
        email: user.email,
        name: user.name,
        passwordHash: user.passwordHash
      }
    })

    return new User(data.id, data.email, data.name, data.passwordHash)
  }

  async findByEmail(email: string): Promise<User | null> {
    const data = await this.prisma.user.findUnique({ where: { email } })

    if (!data) return null

    return new User(data.id, data.email, data.name, data.passwordHash)
  }
}
```

```typescript
// infrastructure/security/BcryptPasswordHasher.ts
import bcrypt from 'bcrypt'

export class BcryptPasswordHasher implements PasswordHasher {
  async hash(password: string): Promise<string> {
    return bcrypt.hash(password, 10)
  }

  async verify(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash)
  }
}
```

---

## 依存性逆転の原則

### 悪い例（依存が外側を向く）

```typescript
// ✗ UseCase が具体的な実装に依存
class CreateUserUseCase {
  private repository = new PrismaUserRepository() // 具体クラスに依存

  async execute(input: any) {
    // ...
    await this.repository.save(user)
  }
}
```

### 良い例（依存が内側を向く）

```typescript
// ○ UseCase がインターフェースに依存
interface UserRepository {
  save(user: User): Promise<User>
}

class CreateUserUseCase {
  constructor(private repository: UserRepository) {} // 抽象に依存

  async execute(input: any) {
    // ...
    await this.repository.save(user)
  }
}

// 外側で具体実装を注入（Dependency Injection）
const prismaClient = new PrismaClient()
const repository = new PrismaUserRepository(prismaClient)
const useCase = new CreateUserUseCase(repository)
```

---

## 実装例

### ディレクトリ構造

```
src/
├── domain/
│   ├── entities/
│   │   ├── User.ts
│   │   └── Order.ts
│   └── repositories/
│       ├── UserRepository.ts (interface)
│       └── OrderRepository.ts (interface)
│
├── application/
│   ├── usecases/
│   │   ├── CreateUser.ts
│   │   ├── GetUser.ts
│   │   └── UpdateUser.ts
│   └── services/
│       └── PasswordHasher.ts (interface)
│
├── adapters/
│   ├── controllers/
│   │   └── UserController.ts
│   ├── presenters/
│   │   └── UserPresenter.ts
│   └── gateways/
│       └── EmailGateway.ts
│
├── infrastructure/
│   ├── database/
│   │   ├── prisma/
│   │   └── repositories/
│   │       └── PrismaUserRepository.ts
│   ├── security/
│   │   └── BcryptPasswordHasher.ts
│   └── web/
│       ├── express/
│       └── routes.ts
│
└── main.ts (DI Container, App起動)
```

### Dependency Injection

```typescript
// main.ts
import { PrismaClient } from '@prisma/client'
import express from 'express'

// Infrastructure
const prisma = new PrismaClient()
const userRepository = new PrismaUserRepository(prisma)
const passwordHasher = new BcryptPasswordHasher()

// Use Cases
const createUserUseCase = new CreateUserUseCase(
  userRepository,
  passwordHasher
)
const getUserUseCase = new GetUserUseCase(userRepository)

// Controllers
const userController = new UserController(
  createUserUseCase,
  getUserUseCase
)

// Routes
const app = express()

app.post('/users', (req, res) => userController.createUser(req, res))
app.get('/users/:id', (req, res) => userController.getUser(req, res))

app.listen(3000)
```

### DI Container（TypeScript）

```typescript
// di/container.ts
import { Container } from 'inversify'

const container = new Container()

// Infrastructure
container.bind<PrismaClient>('PrismaClient').toConstantValue(new PrismaClient())
container.bind<UserRepository>('UserRepository').to(PrismaUserRepository)
container.bind<PasswordHasher>('PasswordHasher').to(BcryptPasswordHasher)

// Use Cases
container.bind<CreateUserUseCase>('CreateUserUseCase').to(CreateUserUseCase)

// Controllers
container.bind<UserController>('UserController').to(UserController)

export { container }
```

---

## ヘキサゴナルアーキテクチャ

クリーンアーキテクチャと似た概念。Ports & Adapters とも呼ばれる。

### 構造

```
          ┌─────────────────────────┐
          │     Application Core    │
          │  (Domain + Use Cases)   │
          └─────────────────────────┘
                 ▲         ▲
                 │         │
         Port    │         │    Port
                 │         │
          ┌──────┴─┐   ┌──┴───────┐
          │Adapter │   │ Adapter  │
          │  HTTP  │   │   DB     │
          └────────┘   └──────────┘
```

### Port（インターフェース）

```typescript
// ports/UserPort.ts (入力ポート)
export interface CreateUserPort {
  execute(input: CreateUserInput): Promise<CreateUserOutput>
}

// ports/UserRepository.ts (出力ポート)
export interface UserRepository {
  save(user: User): Promise<User>
  findById(id: string): Promise<User | null>
}
```

### Adapter（実装）

```typescript
// adapters/input/HttpUserAdapter.ts
export class HttpUserAdapter {
  constructor(private createUserPort: CreateUserPort) {}

  async handleRequest(req: Request, res: Response) {
    const result = await this.createUserPort.execute(req.body)
    res.json(result)
  }
}

// adapters/output/PostgresUserAdapter.ts
export class PostgresUserAdapter implements UserRepository {
  async save(user: User): Promise<User> {
    // Postgres実装
  }
}
```

---

## メリット・デメリット

### メリット

```
✓ テスト容易性
  - ビジネスロジックを独立してテスト可能
  - モックやスタブの作成が簡単

✓ 保守性
  - 責務が明確に分離
  - 変更の影響範囲が限定的

✓ 技術スタック変更の容易さ
  - フレームワークやDBの変更が容易
  - 外側のレイヤーのみ変更

✓ ビジネスロジックの再利用
  - 複数のUIで同じロジックを使用可能
```

### デメリット

```
✗ 学習コスト
  - 概念の理解に時間がかかる
  - チーム全体での理解が必要

✗ 初期実装コスト
  - 多数のファイル・インターフェース
  - 小規模プロジェクトではオーバーエンジニアリング

✗ 定型コード増加
  - DTO、Mapper等の変換コード
  - レイヤー間の橋渡しコード
```

### 使用すべき場合

```
○ 長期間メンテナンスするシステム
○ ビジネスロジックが複雑
○ 技術スタックの変更可能性
○ 高いテストカバレッジが必要
```

### 避けるべき場合

```
✗ 単純なCRUD アプリケーション
✗ プロトタイプ・PoC
✗ 短期間のプロジェクト
✗ 小規模チーム・個人開発
```

---

## ベストプラクティス

### 1. インターフェース分離

```typescript
// ✗ 大きすぎるインターフェース
interface UserRepository {
  save(user: User): Promise<User>
  findById(id: string): Promise<User | null>
  findAll(): Promise<User[]>
  delete(id: string): Promise<void>
  update(user: User): Promise<User>
  findByEmail(email: string): Promise<User | null>
}

// ○ 必要なメソッドのみ定義
interface SaveUser {
  save(user: User): Promise<User>
}

interface FindUser {
  findById(id: string): Promise<User | null>
}
```

### 2. DTOを使用

```typescript
// レイヤー間でエンティティを直接渡さない
export interface CreateUserDTO {
  email: string
  name: string
  password: string
}

// エンティティは内部のみで使用
class User {
  // ...
}
```

### 3. 単一責任を保つ

```typescript
// ✗ UseCaseに複数の責務
class UserUseCase {
  createUser() { /* ... */ }
  updateUser() { /* ... */ }
  deleteUser() { /* ... */ }
}

// ○ UseCaseごとに1つの責務
class CreateUserUseCase {
  execute() { /* ... */ }
}

class UpdateUserUseCase {
  execute() { /* ... */ }
}
```

---

## 参考リンク

- [The Clean Architecture - Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Hexagonal Architecture - Alistair Cockburn](https://alistair.cockburn.us/hexagonal-architecture/)
