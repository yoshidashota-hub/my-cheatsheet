# レイヤードアーキテクチャ完全ガイド

## 目次
- [レイヤードアーキテクチャとは](#レイヤードアーキテクチャとは)
- [3層アーキテクチャ](#3層アーキテクチャ)
- [MVCパターン](#mvcパターン)
- [4層アーキテクチャ](#4層アーキテクチャ)
- [実装例](#実装例)
- [メリット・デメリット](#メリットデメリット)

---

## レイヤードアーキテクチャとは

アプリケーションを階層（Layer）に分割する伝統的なアーキテクチャパターン。

### 基本原則

```
1. レイヤー分離
   各レイヤーは特定の責務を持つ

2. 依存方向
   上位レイヤーは下位レイヤーに依存
   下位レイヤーは上位を知らない

3. レイヤー間通信
   隣接するレイヤーのみ通信可能
```

### 一般的な構成

```
┌─────────────────────────┐
│  Presentation Layer     │  ← UI, Controllers
├─────────────────────────┤
│  Business Logic Layer   │  ← Services, Domain Logic
├─────────────────────────┤
│  Data Access Layer      │  ← Repositories, DAO
├─────────────────────────┤
│  Database              │  ← PostgreSQL, MongoDB
└─────────────────────────┘

依存の方向: 上 → 下
```

---

## 3層アーキテクチャ

最も基本的な階層化パターン。

### 構成

```
┌──────────────────────────────────┐
│  Presentation Layer (プレゼン層)  │
│  - UI                            │
│  - HTTP Handlers                 │
│  - View Templates                │
└──────────────────────────────────┘
              ↓
┌──────────────────────────────────┐
│  Business Logic Layer (ビジネス層) │
│  - Domain Models                 │
│  - Business Rules                │
│  - Services                      │
└──────────────────────────────────┘
              ↓
┌──────────────────────────────────┐
│  Data Access Layer (データアクセス層)│
│  - Repositories                  │
│  - DAO                           │
│  - ORM                           │
└──────────────────────────────────┘
              ↓
┌──────────────────────────────────┐
│  Database (データベース)           │
└──────────────────────────────────┘
```

### Presentation Layer

```typescript
// controllers/UserController.ts
import { Request, Response } from 'express'
import { UserService } from '../services/UserService'

export class UserController {
  constructor(private userService: UserService) {}

  async getUsers(req: Request, res: Response) {
    try {
      const users = await this.userService.getAllUsers()
      res.json(users)
    } catch (error) {
      res.status(500).json({ error: error.message })
    }
  }

  async createUser(req: Request, res: Response) {
    try {
      const { email, name } = req.body
      const user = await this.userService.createUser(email, name)
      res.status(201).json(user)
    } catch (error) {
      res.status(400).json({ error: error.message })
    }
  }
}
```

### Business Logic Layer

```typescript
// services/UserService.ts
import { UserRepository } from '../repositories/UserRepository'
import { User } from '../models/User'

export class UserService {
  constructor(private userRepository: UserRepository) {}

  async getAllUsers(): Promise<User[]> {
    return await this.userRepository.findAll()
  }

  async createUser(email: string, name: string): Promise<User> {
    // ビジネスルール
    if (!email || !name) {
      throw new Error('Email and name are required')
    }

    if (!this.isValidEmail(email)) {
      throw new Error('Invalid email format')
    }

    // 重複チェック
    const existing = await this.userRepository.findByEmail(email)
    if (existing) {
      throw new Error('User already exists')
    }

    // 作成
    const user = new User(generateId(), email, name)
    return await this.userRepository.save(user)
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }
}
```

### Data Access Layer

```typescript
// repositories/UserRepository.ts
import { PrismaClient } from '@prisma/client'
import { User } from '../models/User'

export class UserRepository {
  constructor(private prisma: PrismaClient) {}

  async findAll(): Promise<User[]> {
    const users = await this.prisma.user.findMany()
    return users.map(u => new User(u.id, u.email, u.name))
  }

  async findByEmail(email: string): Promise<User | null> {
    const user = await this.prisma.user.findUnique({ where: { email } })
    return user ? new User(user.id, user.email, user.name) : null
  }

  async save(user: User): Promise<User> {
    const saved = await this.prisma.user.create({
      data: {
        id: user.id,
        email: user.email,
        name: user.name
      }
    })
    return new User(saved.id, saved.email, saved.name)
  }
}
```

---

## MVCパターン

Model-View-Controller パターン。Webアプリケーションで最も一般的。

### 構成

```
        ┌──────────┐
        │  Client  │
        └─────┬────┘
              │
        ┌─────▼──────┐
        │ Controller │ ← リクエスト処理
        └─────┬──────┘
              │
      ┌───────┴────────┐
      │                │
┌─────▼────┐    ┌─────▼────┐
│  Model   │    │   View   │
│(Business)│    │   (UI)   │
└──────────┘    └──────────┘
```

### Model

```typescript
// models/User.ts
export class User {
  constructor(
    public id: string,
    public email: string,
    public name: string,
    public createdAt: Date = new Date()
  ) {}

  // ビジネスロジック
  isActive(): boolean {
    // ユーザーがアクティブかどうか
    return true
  }

  updateName(newName: string): void {
    if (!newName || newName.length < 2) {
      throw new Error('Invalid name')
    }
    this.name = newName
  }
}

// models/UserModel.ts (データアクセス含む)
export class UserModel {
  constructor(private db: Database) {}

  async findById(id: string): Promise<User | null> {
    const data = await this.db.query('SELECT * FROM users WHERE id = $1', [id])
    if (!data) return null
    return new User(data.id, data.email, data.name, data.created_at)
  }

  async save(user: User): Promise<User> {
    const result = await this.db.query(
      'INSERT INTO users (id, email, name) VALUES ($1, $2, $3) RETURNING *',
      [user.id, user.email, user.name]
    )
    return new User(result.id, result.email, result.name)
  }
}
```

### View

```typescript
// views/users.ejs
<!DOCTYPE html>
<html>
<head>
  <title>Users</title>
</head>
<body>
  <h1>Users</h1>
  <ul>
    <% users.forEach(user => { %>
      <li><%= user.name %> (<%= user.email %>)</li>
    <% }) %>
  </ul>
</body>
</html>
```

```typescript
// React View
export function UserList({ users }: { users: User[] }) {
  return (
    <div>
      <h1>Users</h1>
      <ul>
        {users.map(user => (
          <li key={user.id}>
            {user.name} ({user.email})
          </li>
        ))}
      </ul>
    </div>
  )
}
```

### Controller

```typescript
// controllers/UserController.ts
import { Request, Response } from 'express'
import { UserModel } from '../models/UserModel'

export class UserController {
  constructor(private userModel: UserModel) {}

  async index(req: Request, res: Response) {
    const users = await this.userModel.findAll()
    res.render('users/index', { users })
  }

  async show(req: Request, res: Response) {
    const user = await this.userModel.findById(req.params.id)
    if (!user) {
      return res.status(404).render('errors/404')
    }
    res.render('users/show', { user })
  }

  async create(req: Request, res: Response) {
    const { email, name } = req.body
    const user = new User(generateId(), email, name)
    await this.userModel.save(user)
    res.redirect('/users')
  }
}
```

### Rails MVC

```ruby
# models/user.rb
class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  def active?
    # ビジネスロジック
    true
  end
end

# views/users/index.html.erb
<h1>Users</h1>
<ul>
  <% @users.each do |user| %>
    <li><%= user.name %> (<%= user.email %>)</li>
  <% end %>
</ul>

# controllers/users_controller.rb
class UsersController < ApplicationController
  def index
    @users = User.all
  end

  def show
    @user = User.find(params[:id])
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to @user
    else
      render :new
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :name)
  end
end
```

---

## 4層アーキテクチャ

サービス層を追加した拡張版。

### 構成

```
┌─────────────────────────┐
│  Presentation Layer     │  ← Controllers, Views
├─────────────────────────┤
│  Service Layer          │  ← Business Logic
├─────────────────────────┤
│  Domain Layer           │  ← Entities, Models
├─────────────────────────┤
│  Data Access Layer      │  ← Repositories
└─────────────────────────┘
```

### Domain Layer

```typescript
// domain/entities/User.ts
export class User {
  constructor(
    public readonly id: string,
    public email: string,
    public name: string
  ) {}

  // ドメインロジック
  updateEmail(newEmail: string): void {
    if (!this.isValidEmail(newEmail)) {
      throw new Error('Invalid email')
    }
    this.email = newEmail
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }
}
```

### Service Layer

```typescript
// services/UserService.ts
export class UserService {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService
  ) {}

  async registerUser(email: string, name: string): Promise<User> {
    // バリデーション
    if (!email || !name) {
      throw new Error('Email and name are required')
    }

    // 重複チェック
    const existing = await this.userRepository.findByEmail(email)
    if (existing) {
      throw new Error('User already exists')
    }

    // ユーザー作成
    const user = new User(generateId(), email, name)
    await this.userRepository.save(user)

    // ウェルカムメール送信
    await this.emailService.sendWelcomeEmail(user)

    return user
  }
}
```

---

## 実装例

### Express + TypeScript

```typescript
// src/
// ├── controllers/
// │   └── UserController.ts
// ├── services/
// │   └── UserService.ts
// ├── repositories/
// │   └── UserRepository.ts
// ├── models/
// │   └── User.ts
// └── app.ts

// app.ts
import express from 'express'
import { PrismaClient } from '@prisma/client'
import { UserController } from './controllers/UserController'
import { UserService } from './services/UserService'
import { UserRepository } from './repositories/UserRepository'

const app = express()
const prisma = new PrismaClient()

// DI
const userRepository = new UserRepository(prisma)
const userService = new UserService(userRepository)
const userController = new UserController(userService)

// Routes
app.get('/users', (req, res) => userController.getUsers(req, res))
app.post('/users', (req, res) => userController.createUser(req, res))

app.listen(3000)
```

### NestJS

```typescript
// NestJS は標準でレイヤードアーキテクチャ

// entities/user.entity.ts
@Entity()
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string

  @Column({ unique: true })
  email: string

  @Column()
  name: string
}

// services/user.service.ts
@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>
  ) {}

  async findAll(): Promise<User[]> {
    return await this.userRepository.find()
  }

  async create(email: string, name: string): Promise<User> {
    const user = this.userRepository.create({ email, name })
    return await this.userRepository.save(user)
  }
}

// controllers/user.controller.ts
@Controller('users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get()
  async findAll() {
    return await this.userService.findAll()
  }

  @Post()
  async create(@Body() dto: CreateUserDto) {
    return await this.userService.create(dto.email, dto.name)
  }
}
```

---

## メリット・デメリット

### メリット

```
✓ シンプル
  - 理解しやすい
  - 学習コストが低い

✓ 責務の分離
  - 各レイヤーの役割が明確
  - チーム分担しやすい

✓ テスト容易性
  - レイヤーごとにテスト可能

✓ 拡張性
  - レイヤーの追加・変更が容易
```

### デメリット

```
✗ 依存の方向が固定
  - 上から下への依存のみ
  - ビジネスロジックがDBに依存しがち

✗ レイヤー間の結合
  - データがレイヤーを貫通
  - 変更の影響が広がりやすい

✗ ドメインロジックの散在
  - サービス層とモデル層に分散
  - どこに書くべきか迷う
```

### 適用シーン

```
○ 中小規模のWebアプリケーション
○ CRUDが中心のアプリ
○ シンプルなビジネスロジック
○ 短期〜中期のプロジェクト
```

---

## ベストプラクティス

### 1. レイヤーの責務を明確に

```typescript
// ✗ Controllerにビジネスロジック
class UserController {
  async createUser(req, res) {
    const { email } = req.body
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { // ✗
      return res.status(400).json({ error: 'Invalid email' })
    }
    // ...
  }
}

// ○ Serviceにビジネスロジック
class UserService {
  async createUser(email: string, name: string) {
    if (!this.isValidEmail(email)) { // ○
      throw new Error('Invalid email')
    }
    // ...
  }
}
```

### 2. DTOを使用

```typescript
// DTO (Data Transfer Object)
export interface CreateUserDto {
  email: string
  name: string
}

export interface UserResponseDto {
  id: string
  email: string
  name: string
}

// Controller
class UserController {
  async createUser(req: Request, res: Response) {
    const dto: CreateUserDto = req.body
    const user = await this.userService.createUser(dto)

    const response: UserResponseDto = {
      id: user.id,
      email: user.email,
      name: user.name
    }

    res.json(response)
  }
}
```

### 3. トランザクション管理

```typescript
// Service層でトランザクション管理
class OrderService {
  async createOrder(userId: string, items: CartItem[]) {
    return await this.db.transaction(async (tx) => {
      // 注文作成
      const order = await tx.orders.create({ userId })

      // 明細作成
      for (const item of items) {
        await tx.orderItems.create({
          orderId: order.id,
          productId: item.productId,
          quantity: item.quantity
        })
      }

      // 在庫更新
      for (const item of items) {
        await tx.products.update({
          where: { id: item.productId },
          data: { stock: { decrement: item.quantity } }
        })
      }

      return order
    })
  }
}
```

---

## 参考リンク

- [Patterns of Enterprise Application Architecture - Martin Fowler](https://martinfowler.com/eaaCatalog/)
- [MVC Pattern](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller)
