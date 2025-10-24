# ドメイン駆動設計（DDD）完全ガイド

## 目次
- [DDDとは](#dddとは)
- [戦略的設計](#戦略的設計)
- [戦術的設計](#戦術的設計)
- [実装パターン](#実装パターン)
- [実装例](#実装例)

---

## DDDとは

Domain-Driven Design（ドメイン駆動設計）。Eric Evansが提唱したソフトウェア設計手法。

### 核心原則

```
1. ドメインモデル中心
   ビジネスロジックをドメインモデルで表現

2. ユビキタス言語
   開発者とドメインエキスパートが共通の言語を使用

3. 境界づけられたコンテキスト
   モデルの適用範囲を明確に定義
```

### メリット

```
✓ ビジネスロジックの明確化
✓ ドメインエキスパートとの協業
✓ 保守性・拡張性の向上
✓ 複雑なドメインの整理
```

---

## 戦略的設計

システム全体の設計。

### 境界づけられたコンテキスト

```
ドメインを独立した境界で分割

ECサイト例:
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Sales Context  │  │ Inventory       │  │ Shipping        │
│                 │  │ Context         │  │ Context         │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ - Order         │  │ - Product       │  │ - Shipment      │
│ - Customer      │  │ - Stock         │  │ - Delivery      │
│ - Cart          │  │ - Warehouse     │  │ - Address       │
└─────────────────┘  └─────────────────┘  └─────────────────┘

各コンテキスト内で独自のモデル
```

### ユビキタス言語

```
開発者とドメインエキスパートが共有する用語

悪い例:
- data、info、manager → 技術用語
- obj、entity1 → 意味不明

良い例:
- 注文 (Order)
- 顧客 (Customer)
- 在庫 (Inventory)
- 配送 (Shipment)
```

### コンテキストマップ

```
コンテキスト間の関係を定義

┌─────────────┐         ┌─────────────┐
│   Sales     │────────▶│  Inventory  │
│  (上流)      │  ACL    │  (下流)      │
└─────────────┘         └─────────────┘

ACL: Anti-Corruption Layer（腐敗防止層）
上流の変更から下流を保護
```

---

## 戦術的設計

コード レベルの設計パターン。

### エンティティ（Entity）

同一性を持つオブジェクト。IDで識別。

```typescript
// domain/entities/User.ts
export class User {
  constructor(
    private readonly id: UserId,  // 識別子
    private email: Email,
    private name: UserName,
    private createdAt: Date
  ) {}

  // ID による同一性
  equals(other: User): boolean {
    return this.id.equals(other.id)
  }

  // ビジネスロジック
  changeEmail(newEmail: Email): void {
    if (!newEmail.isValid()) {
      throw new Error('Invalid email')
    }
    this.email = newEmail
  }

  getId(): UserId {
    return this.id
  }

  getEmail(): Email {
    return this.email
  }
}

// ライフサイクル全体で同一性を保つ
const user1 = new User(userId, email, name, date)
const user2 = new User(userId, email2, name2, date)

user1.equals(user2) // true (同じID)
```

### 値オブジェクト（Value Object）

同一性を持たず、属性で識別。不変。

```typescript
// domain/values/Email.ts
export class Email {
  private readonly value: string

  constructor(value: string) {
    if (!this.isValid(value)) {
      throw new Error(`Invalid email: ${value}`)
    }
    this.value = value
  }

  // 属性による同一性
  equals(other: Email): boolean {
    return this.value === other.value
  }

  toString(): string {
    return this.value
  }

  private isValid(value: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)
  }
}

// domain/values/Money.ts
export class Money {
  constructor(
    private readonly amount: number,
    private readonly currency: string
  ) {
    if (amount < 0) {
      throw new Error('Amount cannot be negative')
    }
  }

  add(other: Money): Money {
    if (this.currency !== other.currency) {
      throw new Error('Currency mismatch')
    }
    return new Money(this.amount + other.amount, this.currency)
  }

  multiply(multiplier: number): Money {
    return new Money(this.amount * multiplier, this.currency)
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency
  }
}

// 使用例
const price = new Money(1000, 'JPY')
const total = price.multiply(3) // 3000 JPY

// 不変性
const originalPrice = new Money(1000, 'JPY')
const newPrice = originalPrice.add(new Money(500, 'JPY'))
// originalPrice は変更されない
```

### 集約（Aggregate）

関連するエンティティ・値オブジェクトをまとめた単位。

```typescript
// domain/aggregates/Order.ts
export class Order {
  private readonly id: OrderId
  private customerId: CustomerId
  private items: OrderItem[] = []
  private status: OrderStatus
  private total: Money

  constructor(orderId: OrderId, customerId: CustomerId) {
    this.id = orderId
    this.customerId = customerId
    this.status = OrderStatus.Pending
    this.total = new Money(0, 'JPY')
  }

  // 集約ルート：外部から集約へのアクセスポイント
  addItem(productId: ProductId, quantity: number, price: Money): void {
    // ビジネスルール
    if (this.status !== OrderStatus.Pending) {
      throw new Error('Cannot add items to non-pending order')
    }

    if (quantity <= 0) {
      throw new Error('Quantity must be positive')
    }

    // OrderItem は集約内部のエンティティ
    const item = new OrderItem(generateId(), productId, quantity, price)
    this.items.push(item)

    // 集約の整合性を保つ
    this.recalculateTotal()
  }

  removeItem(itemId: OrderItemId): void {
    this.items = this.items.filter(item => !item.getId().equals(itemId))
    this.recalculateTotal()
  }

  confirm(): void {
    if (this.items.length === 0) {
      throw new Error('Cannot confirm empty order')
    }
    this.status = OrderStatus.Confirmed
  }

  private recalculateTotal(): void {
    this.total = this.items.reduce(
      (sum, item) => sum.add(item.getSubtotal()),
      new Money(0, 'JPY')
    )
  }

  // 集約内部のエンティティへの直接アクセスを許可しない
  getItems(): readonly OrderItem[] {
    return [...this.items] // コピーを返す
  }

  getTotal(): Money {
    return this.total
  }
}

// domain/entities/OrderItem.ts
export class OrderItem {
  constructor(
    private readonly id: OrderItemId,
    private readonly productId: ProductId,
    private readonly quantity: number,
    private readonly price: Money
  ) {}

  getSubtotal(): Money {
    return this.price.multiply(this.quantity)
  }

  getId(): OrderItemId {
    return this.id
  }
}
```

### リポジトリ（Repository）

集約の永続化を抽象化。

```typescript
// domain/repositories/OrderRepository.ts
export interface OrderRepository {
  save(order: Order): Promise<Order>
  findById(id: OrderId): Promise<Order | null>
  findByCustomerId(customerId: CustomerId): Promise<Order[]>
  delete(id: OrderId): Promise<void>
}

// infrastructure/repositories/OrderRepositoryImpl.ts
export class OrderRepositoryImpl implements OrderRepository {
  constructor(private prisma: PrismaClient) {}

  async save(order: Order): Promise<Order> {
    // 集約全体を保存（トランザクション）
    await this.prisma.$transaction(async (tx) => {
      // Order を保存
      await tx.order.upsert({
        where: { id: order.getId().toString() },
        create: {
          id: order.getId().toString(),
          customerId: order.getCustomerId().toString(),
          status: order.getStatus(),
          total: order.getTotal().getAmount()
        },
        update: {
          status: order.getStatus(),
          total: order.getTotal().getAmount()
        }
      })

      // OrderItems を保存
      await tx.orderItem.deleteMany({
        where: { orderId: order.getId().toString() }
      })

      for (const item of order.getItems()) {
        await tx.orderItem.create({
          data: {
            id: item.getId().toString(),
            orderId: order.getId().toString(),
            productId: item.getProductId().toString(),
            quantity: item.getQuantity(),
            price: item.getPrice().getAmount()
          }
        })
      }
    })

    return order
  }

  async findById(id: OrderId): Promise<Order | null> {
    const data = await this.prisma.order.findUnique({
      where: { id: id.toString() },
      include: { items: true }
    })

    if (!data) return null

    // ドメインオブジェクトに復元
    const order = new Order(
      new OrderId(data.id),
      new CustomerId(data.customerId)
    )

    for (const itemData of data.items) {
      order.addItem(
        new ProductId(itemData.productId),
        itemData.quantity,
        new Money(itemData.price, 'JPY')
      )
    }

    return order
  }
}
```

### ドメインサービス

複数の集約にまたがるロジック。

```typescript
// domain/services/OrderService.ts
export class OrderService {
  constructor(
    private orderRepository: OrderRepository,
    private inventoryService: InventoryService
  ) {}

  async placeOrder(order: Order): Promise<void> {
    // 在庫確認（別の集約）
    for (const item of order.getItems()) {
      const available = await this.inventoryService.checkAvailability(
        item.getProductId(),
        item.getQuantity()
      )

      if (!available) {
        throw new Error(`Product ${item.getProductId()} is out of stock`)
      }
    }

    // 在庫確保
    for (const item of order.getItems()) {
      await this.inventoryService.reserve(
        item.getProductId(),
        item.getQuantity()
      )
    }

    // 注文確定
    order.confirm()
    await this.orderRepository.save(order)
  }
}
```

### ドメインイベント

集約内で発生した出来事を表現。

```typescript
// domain/events/OrderEvents.ts
export interface DomainEvent {
  occurredAt: Date
}

export class OrderPlacedEvent implements DomainEvent {
  constructor(
    public readonly orderId: OrderId,
    public readonly customerId: CustomerId,
    public readonly total: Money,
    public readonly occurredAt: Date = new Date()
  ) {}
}

// domain/aggregates/Order.ts
export class Order {
  private domainEvents: DomainEvent[] = []

  confirm(): void {
    if (this.items.length === 0) {
      throw new Error('Cannot confirm empty order')
    }

    this.status = OrderStatus.Confirmed

    // イベント記録
    this.addDomainEvent(
      new OrderPlacedEvent(this.id, this.customerId, this.total)
    )
  }

  private addDomainEvent(event: DomainEvent): void {
    this.domainEvents.push(event)
  }

  getDomainEvents(): DomainEvent[] {
    return [...this.domainEvents]
  }

  clearDomainEvents(): void {
    this.domainEvents = []
  }
}

// application/usecases/PlaceOrderUseCase.ts
export class PlaceOrderUseCase {
  async execute(order: Order): Promise<void> {
    await this.orderRepository.save(order)

    // イベント発行
    const events = order.getDomainEvents()
    for (const event of events) {
      await this.eventBus.publish(event)
    }

    order.clearDomainEvents()
  }
}
```

---

## 実装パターン

### ファクトリー

複雑な集約の生成。

```typescript
// domain/factories/OrderFactory.ts
export class OrderFactory {
  static createFromCart(
    cart: Cart,
    customerId: CustomerId
  ): Order {
    const order = new Order(new OrderId(generateId()), customerId)

    for (const cartItem of cart.getItems()) {
      order.addItem(
        cartItem.getProductId(),
        cartItem.getQuantity(),
        cartItem.getPrice()
      )
    }

    return order
  }

  static reconstituteFromDatabase(data: OrderData): Order {
    // データベースから復元
    const order = new Order(
      new OrderId(data.id),
      new CustomerId(data.customerId)
    )

    // 状態復元
    // ...

    return order
  }
}
```

### 仕様パターン

ビジネスルールのカプセル化。

```typescript
// domain/specifications/OrderSpecification.ts
export interface Specification<T> {
  isSatisfiedBy(target: T): boolean
}

export class MinimumOrderAmountSpecification implements Specification<Order> {
  constructor(private minimumAmount: Money) {}

  isSatisfiedBy(order: Order): boolean {
    return order.getTotal().getAmount() >= this.minimumAmount.getAmount()
  }
}

// 使用例
const spec = new MinimumOrderAmountSpecification(new Money(1000, 'JPY'))

if (!spec.isSatisfiedBy(order)) {
  throw new Error('Order amount is below minimum')
}
```

---

## 実装例

### ディレクトリ構造

```
src/
├── domain/
│   ├── aggregates/
│   │   ├── Order.ts
│   │   └── User.ts
│   ├── entities/
│   │   └── OrderItem.ts
│   ├── values/
│   │   ├── Email.ts
│   │   ├── Money.ts
│   │   └── OrderId.ts
│   ├── services/
│   │   └── OrderService.ts
│   ├── repositories/
│   │   └── OrderRepository.ts (interface)
│   ├── events/
│   │   └── OrderEvents.ts
│   └── factories/
│       └── OrderFactory.ts
│
├── application/
│   └── usecases/
│       ├── PlaceOrderUseCase.ts
│       └── CancelOrderUseCase.ts
│
└── infrastructure/
    └── repositories/
        └── OrderRepositoryImpl.ts
```

---

## ベストプラクティス

### 1. ユビキタス言語を徹底

```typescript
// ✗ 技術用語
class DataManager {
  processInfo(obj: any) { /* ... */ }
}

// ○ ドメイン用語
class OrderService {
  placeOrder(order: Order) { /* ... */ }
}
```

### 2. 不変性を保つ

```typescript
// 値オブジェクトは常に不変
export class Money {
  add(other: Money): Money {
    return new Money(this.amount + other.amount, this.currency)
    // this.amount を直接変更しない
  }
}
```

### 3. 集約の境界を適切に

```typescript
// ✗ 大きすぎる集約
class Order {
  user: User // ✗ 別の集約
  product: Product // ✗ 別の集約
}

// ○ IDで参照
class Order {
  customerId: CustomerId // ○ IDのみ
  items: OrderItem[] // ○ 集約内のエンティティ
}
```

---

## 参考リンク

- [Domain-Driven Design - Eric Evans](https://www.domainlanguage.com/ddd/)
- [Implementing Domain-Driven Design - Vaughn Vernon](https://vaughnvernon.com/)
