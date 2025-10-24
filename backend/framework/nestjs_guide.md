# NestJS 完全ガイド

## 目次
- [NestJSとは](#nestjsとは)
- [セットアップ](#セットアップ)
- [モジュール](#モジュール)
- [コントローラー](#コントローラー)
- [プロバイダー](#プロバイダー)
- [依存性注入](#依存性注入)
- [ミドルウェア・ガード・インターセプター](#ミドルウェアガードインターセプター)
- [データベース連携](#データベース連携)

---

## NestJSとは

TypeScriptで構築された、スケーラブルなサーバーサイドアプリケーションフレームワーク。

### 主な特徴
- 🏗️ Angularに触発されたアーキテクチャ
- 📦 モジュールベースの構造
- 💉 依存性注入（DI）
- 🔒 TypeScript完全サポート
- 🚀 高速で効率的

---

## セットアップ

### プロジェクト作成

```bash
# Nest CLI インストール
npm install -g @nestjs/cli

# 新規プロジェクト作成
nest new project-name

# パッケージマネージャー選択
# npm / yarn / pnpm
```

### プロジェクト構造

```
src/
├── app.controller.ts
├── app.controller.spec.ts
├── app.module.ts
├── app.service.ts
└── main.ts
```

### main.ts

```typescript
import { NestFactory } from '@nestjs/core'
import { AppModule } from './app.module'

async function bootstrap() {
  const app = await NestFactory.create(AppModule)
  await app.listen(3000)
}
bootstrap()
```

---

## モジュール

### 基本的なモジュール

```typescript
import { Module } from '@nestjs/common'
import { UsersController } from './users.controller'
import { UsersService } from './users.service'

@Module({
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService] // 他のモジュールから使用可能に
})
export class UsersModule {}
```

### グローバルモジュール

```typescript
import { Module, Global } from '@nestjs/common'

@Global()
@Module({
  providers: [ConfigService],
  exports: [ConfigService]
})
export class ConfigModule {}
```

---

## コントローラー

### 基本的なコントローラー

```typescript
import { Controller, Get, Post, Body, Param, Delete, Put } from '@nestjs/common'

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  findAll() {
    return this.usersService.findAll()
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(+id)
  }

  @Post()
  create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto)
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() updateUserDto: UpdateUserDto) {
    return this.usersService.update(+id, updateUserDto)
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.usersService.remove(+id)
  }
}
```

---

## プロバイダー

### サービス

```typescript
import { Injectable, NotFoundException } from '@nestjs/common'

@Injectable()
export class UsersService {
  private users = []

  findAll() {
    return this.users
  }

  findOne(id: number) {
    const user = this.users.find(u => u.id === id)
    if (!user) {
      throw new NotFoundException(`User #${id} not found`)
    }
    return user
  }

  create(createUserDto: CreateUserDto) {
    const user = { id: Date.now(), ...createUserDto }
    this.users.push(user)
    return user
  }

  update(id: number, updateUserDto: UpdateUserDto) {
    const user = this.findOne(id)
    Object.assign(user, updateUserDto)
    return user
  }

  remove(id: number) {
    const index = this.users.findIndex(u => u.id === id)
    if (index === -1) {
      throw new NotFoundException()
    }
    return this.users.splice(index, 1)
  }
}
```

---

## 依存性注入

### コンストラクター注入

```typescript
@Injectable()
export class UsersService {
  constructor(
    private readonly repository: UserRepository,
    private readonly config: ConfigService
  ) {}
}
```

### カスタムプロバイダー

```typescript
@Module({
  providers: [
    {
      provide: 'DATABASE_CONNECTION',
      useFactory: async () => {
        const connection = await createConnection()
        return connection
      }
    }
  ]
})
export class AppModule {}
```

---

## ミドルウェア・ガード・インターセプター

### ミドルウェア

```typescript
import { Injectable, NestMiddleware } from '@nestjs/common'

@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: Function) {
    console.log(`Request...`)
    next()
  }
}
```

### ガード

```typescript
import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common'

@Injectable()
export class AuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest()
    return validateRequest(request)
  }
}
```

---

## データベース連携

### TypeORM

```bash
npm install @nestjs/typeorm typeorm mysql2
```

```typescript
import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'mysql',
      host: 'localhost',
      port: 3306,
      username: 'root',
      password: 'root',
      database: 'test',
      entities: [User],
      synchronize: true
    }),
    TypeOrmModule.forFeature([User])
  ]
})
export class AppModule {}
```

---

## 参考リンク

- [NestJS 公式ドキュメント](https://docs.nestjs.com/)
