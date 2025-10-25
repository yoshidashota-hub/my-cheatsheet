# AWS Cognito 完全ガイド

## 目次
1. [AWS Cognitoとは](#aws-cognitoとは)
2. [基本概念](#基本概念)
3. [ユーザープール](#ユーザープール)
4. [IDプール（Federated Identities）](#idプールfederated-identities)
5. [認証フロー](#認証フロー)
6. [セットアップ](#セットアップ)
7. [実装例](#実装例)
8. [ベストプラクティス](#ベストプラクティス)
9. [トラブルシューティング](#トラブルシューティング)

---

## AWS Cognitoとは

AWS Cognitoは、ウェブアプリケーションやモバイルアプリケーションのユーザー認証・認可・ユーザー管理を提供するマネージドサービスです。

### 主な機能

- **ユーザー登録・サインイン**: メールアドレス、電話番号、ユーザー名による認証
- **多要素認証（MFA）**: SMS、TOTP（Time-based One-Time Password）
- **ソーシャルログイン**: Google、Facebook、Amazon、Appleなど
- **SAML/OIDC対応**: 企業のIDプロバイダーと統合
- **アクセストークン発行**: JWT形式のトークン
- **一時的なAWS認証情報**: S3、DynamoDBなどへの直接アクセス

---

## 基本概念

### ユーザープール vs IDプール

```
┌─────────────────────────────────────────────────┐
│              AWS Cognito                        │
├─────────────────────┬───────────────────────────┤
│   User Pools        │    Identity Pools         │
│  (認証)              │   (認可)                   │
│                     │                           │
│  - ユーザー登録      │  - AWS リソースへの       │
│  - サインイン        │    アクセス権限           │
│  - トークン発行      │  - 一時的な認証情報       │
│  - MFA              │  - ゲストアクセス         │
└─────────────────────┴───────────────────────────┘
```

### ユーザープールの構成要素

- **ユーザー**: アプリケーションのエンドユーザー
- **グループ**: ユーザーをまとめて管理
- **アプリクライアント**: アプリケーションとの接続設定
- **トリガー**: Lambda関数による処理の拡張

---

## ユーザープール

### ユーザープールの作成

#### AWS CLIでの作成

```bash
# ユーザープールの作成
aws cognito-idp create-user-pool \
  --pool-name my-user-pool \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": true
    }
  }' \
  --auto-verified-attributes email \
  --mfa-configuration OPTIONAL \
  --email-configuration '{
    "EmailSendingAccount": "COGNITO_DEFAULT"
  }' \
  --schema '[
    {
      "Name": "email",
      "AttributeDataType": "String",
      "Required": true,
      "Mutable": false
    },
    {
      "Name": "name",
      "AttributeDataType": "String",
      "Required": true,
      "Mutable": true
    }
  ]'

# アプリクライアントの作成
aws cognito-idp create-user-pool-client \
  --user-pool-id us-east-1_XXXXXXXXX \
  --client-name my-app-client \
  --generate-secret \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --read-attributes email name \
  --write-attributes name
```

#### AWS CDKでの作成

```typescript
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as cdk from 'aws-cdk-lib';

export class CognitoStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ユーザープールの作成
    const userPool = new cognito.UserPool(this, 'MyUserPool', {
      userPoolName: 'my-user-pool',
      selfSignUpEnabled: true,
      signInAliases: {
        email: true,
        username: true,
      },
      autoVerify: {
        email: true,
      },
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: true,
      },
      mfa: cognito.Mfa.OPTIONAL,
      mfaSecondFactor: {
        sms: true,
        otp: true,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      standardAttributes: {
        email: {
          required: true,
          mutable: false,
        },
        fullname: {
          required: true,
          mutable: true,
        },
      },
      customAttributes: {
        'tenant_id': new cognito.StringAttribute({ mutable: true }),
        'role': new cognito.StringAttribute({ mutable: true }),
      },
    });

    // アプリクライアントの作成
    const userPoolClient = userPool.addClient('AppClient', {
      userPoolClientName: 'my-app-client',
      authFlows: {
        userPassword: true,
        userSrp: true,
        custom: true,
      },
      oAuth: {
        flows: {
          authorizationCodeGrant: true,
        },
        scopes: [
          cognito.OAuthScope.EMAIL,
          cognito.OAuthScope.OPENID,
          cognito.OAuthScope.PROFILE,
        ],
        callbackUrls: [
          'http://localhost:3000/callback',
          'https://example.com/callback',
        ],
        logoutUrls: [
          'http://localhost:3000',
          'https://example.com',
        ],
      },
    });

    // ユーザーグループの作成
    new cognito.CfnUserPoolGroup(this, 'AdminGroup', {
      userPoolId: userPool.userPoolId,
      groupName: 'admin',
      description: 'Administrator group',
      precedence: 1,
    });

    new cognito.CfnUserPoolGroup(this, 'UserGroup', {
      userPoolId: userPool.userPoolId,
      groupName: 'user',
      description: 'Standard user group',
      precedence: 10,
    });

    // 出力
    new cdk.CfnOutput(this, 'UserPoolId', {
      value: userPool.userPoolId,
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: userPoolClient.userPoolClientId,
    });
  }
}
```

### カスタム属性

```typescript
// CDKでのカスタム属性定義
const userPool = new cognito.UserPool(this, 'MyUserPool', {
  customAttributes: {
    'company': new cognito.StringAttribute({
      minLen: 1,
      maxLen: 256,
      mutable: true
    }),
    'employee_id': new cognito.StringAttribute({
      mutable: false
    }),
    'age': new cognito.NumberAttribute({
      min: 18,
      max: 120,
      mutable: true
    }),
    'is_premium': new cognito.BooleanAttribute({
      mutable: true
    }),
    'member_since': new cognito.DateTimeAttribute({
      mutable: false
    }),
  },
});
```

---

## IDプール（Federated Identities）

### IDプールの作成

```typescript
import * as cognito_identity from 'aws-cdk-lib/aws-cognito-identitypool';
import * as iam from 'aws-cdk-lib/aws-iam';

// IDプールの作成
const identityPool = new cognito_identity.IdentityPool(this, 'MyIdentityPool', {
  identityPoolName: 'my-identity-pool',
  allowUnauthenticatedIdentities: true,
  authenticationProviders: {
    userPools: [
      new cognito_identity.UserPoolAuthenticationProvider({
        userPool: userPool,
        userPoolClient: userPoolClient,
      }),
    ],
  },
});

// 認証済みユーザー用のロール
const authenticatedRole = new iam.Role(this, 'AuthenticatedRole', {
  assumedBy: new iam.FederatedPrincipal(
    'cognito-identity.amazonaws.com',
    {
      StringEquals: {
        'cognito-identity.amazonaws.com:aud': identityPool.identityPoolId,
      },
      'ForAnyValue:StringLike': {
        'cognito-identity.amazonaws.com:amr': 'authenticated',
      },
    },
    'sts:AssumeRoleWithWebIdentity'
  ),
});

// S3アクセス権限の付与
authenticatedRole.addToPolicy(new iam.PolicyStatement({
  effect: iam.Effect.ALLOW,
  actions: [
    's3:GetObject',
    's3:PutObject',
  ],
  resources: [
    `arn:aws:s3:::my-bucket/users/\${cognito-identity.amazonaws.com:sub}/*`,
  ],
}));

// 未認証ユーザー用のロール
const unauthenticatedRole = new iam.Role(this, 'UnauthenticatedRole', {
  assumedBy: new iam.FederatedPrincipal(
    'cognito-identity.amazonaws.com',
    {
      StringEquals: {
        'cognito-identity.amazonaws.com:aud': identityPool.identityPoolId,
      },
      'ForAnyValue:StringLike': {
        'cognito-identity.amazonaws.com:amr': 'unauthenticated',
      },
    },
    'sts:AssumeRoleWithWebIdentity'
  ),
});
```

---

## 認証フロー

### SRP（Secure Remote Password）認証フロー

```
┌──────────┐                 ┌──────────────┐
│  Client  │                 │   Cognito    │
└────┬─────┘                 └──────┬───────┘
     │                              │
     │  1. InitiateAuth (SRP_A)     │
     │─────────────────────────────>│
     │                              │
     │  2. Challenge (SRP_B, SALT)  │
     │<─────────────────────────────│
     │                              │
     │  3. RespondToAuthChallenge   │
     │     (PASSWORD_CLAIM)         │
     │─────────────────────────────>│
     │                              │
     │  4. Tokens                   │
     │<─────────────────────────────│
     │                              │
```

### カスタム認証フロー

```typescript
// Lambda トリガー設定
const defineAuthChallenge = new lambda.Function(this, 'DefineAuthChallenge', {
  runtime: lambda.Runtime.NODEJS_18_X,
  handler: 'index.handler',
  code: lambda.Code.fromAsset('lambda/define-auth-challenge'),
});

const createAuthChallenge = new lambda.Function(this, 'CreateAuthChallenge', {
  runtime: lambda.Runtime.NODEJS_18_X,
  handler: 'index.handler',
  code: lambda.Code.fromAsset('lambda/create-auth-challenge'),
});

const verifyAuthChallenge = new lambda.Function(this, 'VerifyAuthChallenge', {
  runtime: lambda.Runtime.NODEJS_18_X,
  handler: 'index.handler',
  code: lambda.Code.fromAsset('lambda/verify-auth-challenge'),
});

userPool.addTrigger(
  cognito.UserPoolOperation.DEFINE_AUTH_CHALLENGE,
  defineAuthChallenge
);

userPool.addTrigger(
  cognito.UserPoolOperation.CREATE_AUTH_CHALLENGE,
  createAuthChallenge
);

userPool.addTrigger(
  cognito.UserPoolOperation.VERIFY_AUTH_CHALLENGE_RESPONSE,
  verifyAuthChallenge
);
```

#### Define Auth Challenge Lambda

```javascript
// lambda/define-auth-challenge/index.js
export const handler = async (event) => {
  if (event.request.session.length === 0) {
    // 最初のチャレンジ
    event.response.challengeName = 'CUSTOM_CHALLENGE';
    event.response.issueTokens = false;
    event.response.failAuthentication = false;
  } else if (
    event.request.session.length === 1 &&
    event.request.session[0].challengeName === 'CUSTOM_CHALLENGE' &&
    event.request.session[0].challengeResult === true
  ) {
    // チャレンジ成功
    event.response.issueTokens = true;
    event.response.failAuthentication = false;
  } else {
    // チャレンジ失敗
    event.response.issueTokens = false;
    event.response.failAuthentication = true;
  }

  return event;
};
```

#### Create Auth Challenge Lambda

```javascript
// lambda/create-auth-challenge/index.js
import crypto from 'crypto';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';

const ses = new SESClient({ region: 'us-east-1' });

export const handler = async (event) => {
  // ワンタイムコードの生成
  const code = crypto.randomInt(100000, 999999).toString();

  // コードをメール送信
  await ses.send(new SendEmailCommand({
    Source: 'noreply@example.com',
    Destination: {
      ToAddresses: [event.request.userAttributes.email],
    },
    Message: {
      Subject: {
        Data: 'Your verification code',
      },
      Body: {
        Text: {
          Data: `Your verification code is: ${code}`,
        },
      },
    },
  }));

  // チャレンジメタデータに正解を保存
  event.response.publicChallengeParameters = {
    email: event.request.userAttributes.email,
  };

  event.response.privateChallengeParameters = {
    answer: code,
  };

  event.response.challengeMetadata = 'CODE_VERIFICATION';

  return event;
};
```

#### Verify Auth Challenge Lambda

```javascript
// lambda/verify-auth-challenge/index.js
export const handler = async (event) => {
  const expectedAnswer = event.request.privateChallengeParameters.answer;
  const userAnswer = event.request.challengeAnswer;

  event.response.answerCorrect = expectedAnswer === userAnswer;

  return event;
};
```

---

## セットアップ

### 環境変数設定

```bash
# .env
COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
COGNITO_CLIENT_ID=xxxxxxxxxxxxxxxxxxxx
COGNITO_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
COGNITO_REGION=us-east-1
COGNITO_IDENTITY_POOL_ID=us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## 実装例

### 1. ユーザー登録（Sign Up）

#### TypeScript + AWS SDK v3

```typescript
import {
  CognitoIdentityProviderClient,
  SignUpCommand,
  ConfirmSignUpCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import crypto from 'crypto';

const client = new CognitoIdentityProviderClient({
  region: process.env.COGNITO_REGION
});

// シークレットハッシュの生成
function generateSecretHash(username: string): string {
  return crypto
    .createHmac('SHA256', process.env.COGNITO_CLIENT_SECRET!)
    .update(username + process.env.COGNITO_CLIENT_ID!)
    .digest('base64');
}

// ユーザー登録
async function signUp(
  username: string,
  password: string,
  email: string,
  name: string
) {
  try {
    const command = new SignUpCommand({
      ClientId: process.env.COGNITO_CLIENT_ID,
      SecretHash: generateSecretHash(username),
      Username: username,
      Password: password,
      UserAttributes: [
        {
          Name: 'email',
          Value: email,
        },
        {
          Name: 'name',
          Value: name,
        },
      ],
    });

    const response = await client.send(command);
    console.log('User registered:', response);

    return {
      userSub: response.UserSub,
      userConfirmed: response.UserConfirmed,
    };
  } catch (error) {
    console.error('Sign up error:', error);
    throw error;
  }
}

// 確認コードで登録確認
async function confirmSignUp(username: string, code: string) {
  try {
    const command = new ConfirmSignUpCommand({
      ClientId: process.env.COGNITO_CLIENT_ID,
      SecretHash: generateSecretHash(username),
      Username: username,
      ConfirmationCode: code,
    });

    await client.send(command);
    console.log('User confirmed successfully');
  } catch (error) {
    console.error('Confirm sign up error:', error);
    throw error;
  }
}
```

### 2. サインイン（Sign In）

```typescript
import {
  InitiateAuthCommand,
  RespondToAuthChallengeCommand,
  AuthFlowType,
} from '@aws-sdk/client-cognito-identity-provider';

// ユーザー名・パスワード認証
async function signIn(username: string, password: string) {
  try {
    const command = new InitiateAuthCommand({
      AuthFlow: AuthFlowType.USER_PASSWORD_AUTH,
      ClientId: process.env.COGNITO_CLIENT_ID,
      AuthParameters: {
        USERNAME: username,
        PASSWORD: password,
        SECRET_HASH: generateSecretHash(username),
      },
    });

    const response = await client.send(command);

    if (response.ChallengeName) {
      console.log('Challenge required:', response.ChallengeName);
      // MFAなどのチャレンジ処理
      return {
        challengeName: response.ChallengeName,
        session: response.Session,
      };
    }

    return {
      accessToken: response.AuthenticationResult?.AccessToken,
      idToken: response.AuthenticationResult?.IdToken,
      refreshToken: response.AuthenticationResult?.RefreshToken,
      expiresIn: response.AuthenticationResult?.ExpiresIn,
    };
  } catch (error) {
    console.error('Sign in error:', error);
    throw error;
  }
}

// MFAチャレンジへの応答
async function respondToMfaChallenge(
  username: string,
  session: string,
  mfaCode: string
) {
  try {
    const command = new RespondToAuthChallengeCommand({
      ClientId: process.env.COGNITO_CLIENT_ID,
      ChallengeName: 'SMS_MFA',
      Session: session,
      ChallengeResponses: {
        USERNAME: username,
        SMS_MFA_CODE: mfaCode,
        SECRET_HASH: generateSecretHash(username),
      },
    });

    const response = await client.send(command);

    return {
      accessToken: response.AuthenticationResult?.AccessToken,
      idToken: response.AuthenticationResult?.IdToken,
      refreshToken: response.AuthenticationResult?.RefreshToken,
    };
  } catch (error) {
    console.error('MFA challenge error:', error);
    throw error;
  }
}
```

### 3. トークンのリフレッシュ

```typescript
async function refreshTokens(username: string, refreshToken: string) {
  try {
    const command = new InitiateAuthCommand({
      AuthFlow: AuthFlowType.REFRESH_TOKEN_AUTH,
      ClientId: process.env.COGNITO_CLIENT_ID,
      AuthParameters: {
        REFRESH_TOKEN: refreshToken,
        SECRET_HASH: generateSecretHash(username),
      },
    });

    const response = await client.send(command);

    return {
      accessToken: response.AuthenticationResult?.AccessToken,
      idToken: response.AuthenticationResult?.IdToken,
      expiresIn: response.AuthenticationResult?.ExpiresIn,
    };
  } catch (error) {
    console.error('Refresh token error:', error);
    throw error;
  }
}
```

### 4. ユーザー情報の取得

```typescript
import { GetUserCommand } from '@aws-sdk/client-cognito-identity-provider';

async function getUserInfo(accessToken: string) {
  try {
    const command = new GetUserCommand({
      AccessToken: accessToken,
    });

    const response = await client.send(command);

    const attributes: Record<string, string> = {};
    response.UserAttributes?.forEach((attr) => {
      attributes[attr.Name] = attr.Value || '';
    });

    return {
      username: response.Username,
      attributes,
      mfaOptions: response.MFAOptions,
    };
  } catch (error) {
    console.error('Get user info error:', error);
    throw error;
  }
}
```

### 5. パスワードリセット

```typescript
import {
  ForgotPasswordCommand,
  ConfirmForgotPasswordCommand,
} from '@aws-sdk/client-cognito-identity-provider';

// パスワードリセット要求
async function forgotPassword(username: string) {
  try {
    const command = new ForgotPasswordCommand({
      ClientId: process.env.COGNITO_CLIENT_ID,
      SecretHash: generateSecretHash(username),
      Username: username,
    });

    const response = await client.send(command);
    console.log('Password reset code sent:', response.CodeDeliveryDetails);
  } catch (error) {
    console.error('Forgot password error:', error);
    throw error;
  }
}

// パスワードリセット確認
async function confirmForgotPassword(
  username: string,
  code: string,
  newPassword: string
) {
  try {
    const command = new ConfirmForgotPasswordCommand({
      ClientId: process.env.COGNITO_CLIENT_ID,
      SecretHash: generateSecretHash(username),
      Username: username,
      ConfirmationCode: code,
      Password: newPassword,
    });

    await client.send(command);
    console.log('Password reset successfully');
  } catch (error) {
    console.error('Confirm forgot password error:', error);
    throw error;
  }
}
```

### 6. React統合（amazon-cognito-identity-js）

```typescript
// hooks/useCognito.ts
import { useState } from 'react';
import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
  CognitoUserAttribute,
} from 'amazon-cognito-identity-js';

const userPool = new CognitoUserPool({
  UserPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID!,
  ClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID!,
});

export function useCognito() {
  const [user, setUser] = useState<CognitoUser | null>(null);
  const [loading, setLoading] = useState(false);

  const signUp = async (
    username: string,
    password: string,
    email: string,
    name: string
  ) => {
    setLoading(true);

    const attributes = [
      new CognitoUserAttribute({ Name: 'email', Value: email }),
      new CognitoUserAttribute({ Name: 'name', Value: name }),
    ];

    return new Promise((resolve, reject) => {
      userPool.signUp(username, password, attributes, [], (err, result) => {
        setLoading(false);
        if (err) {
          reject(err);
          return;
        }
        resolve(result);
      });
    });
  };

  const confirmSignUp = async (username: string, code: string) => {
    const cognitoUser = new CognitoUser({
      Username: username,
      Pool: userPool,
    });

    return new Promise((resolve, reject) => {
      cognitoUser.confirmRegistration(code, true, (err, result) => {
        if (err) {
          reject(err);
          return;
        }
        resolve(result);
      });
    });
  };

  const signIn = async (username: string, password: string) => {
    setLoading(true);

    const cognitoUser = new CognitoUser({
      Username: username,
      Pool: userPool,
    });

    const authDetails = new AuthenticationDetails({
      Username: username,
      Password: password,
    });

    return new Promise((resolve, reject) => {
      cognitoUser.authenticateUser(authDetails, {
        onSuccess: (result) => {
          setLoading(false);
          setUser(cognitoUser);
          resolve({
            accessToken: result.getAccessToken().getJwtToken(),
            idToken: result.getIdToken().getJwtToken(),
            refreshToken: result.getRefreshToken().getToken(),
          });
        },
        onFailure: (err) => {
          setLoading(false);
          reject(err);
        },
        mfaRequired: (codeDeliveryDetails) => {
          setLoading(false);
          resolve({ mfaRequired: true, codeDeliveryDetails });
        },
      });
    });
  };

  const signOut = () => {
    const cognitoUser = userPool.getCurrentUser();
    if (cognitoUser) {
      cognitoUser.signOut();
      setUser(null);
    }
  };

  const getCurrentUser = async () => {
    const cognitoUser = userPool.getCurrentUser();

    if (!cognitoUser) {
      return null;
    }

    return new Promise((resolve, reject) => {
      cognitoUser.getSession((err: any, session: any) => {
        if (err) {
          reject(err);
          return;
        }

        cognitoUser.getUserAttributes((err, attributes) => {
          if (err) {
            reject(err);
            return;
          }

          const userAttributes: Record<string, string> = {};
          attributes?.forEach((attr) => {
            userAttributes[attr.Name] = attr.Value;
          });

          resolve({
            username: cognitoUser.getUsername(),
            attributes: userAttributes,
            session,
          });
        });
      });
    });
  };

  return {
    user,
    loading,
    signUp,
    confirmSignUp,
    signIn,
    signOut,
    getCurrentUser,
  };
}
```

### 7. トークン検証（バックエンド）

```typescript
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

const client = jwksClient({
  jwksUri: `https://cognito-idp.${process.env.COGNITO_REGION}.amazonaws.com/${process.env.COGNITO_USER_POOL_ID}/.well-known/jwks.json`,
});

function getKey(header: any, callback: any) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    const signingKey = key?.getPublicKey();
    callback(null, signingKey);
  });
}

export async function verifyToken(token: string): Promise<any> {
  return new Promise((resolve, reject) => {
    jwt.verify(
      token,
      getKey,
      {
        issuer: `https://cognito-idp.${process.env.COGNITO_REGION}.amazonaws.com/${process.env.COGNITO_USER_POOL_ID}`,
        audience: process.env.COGNITO_CLIENT_ID,
      },
      (err, decoded) => {
        if (err) {
          reject(err);
          return;
        }
        resolve(decoded);
      }
    );
  });
}

// Express middleware
export const authenticateToken = async (req: any, res: any, next: any) => {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const decoded = await verifyToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid token' });
  }
};
```

### 8. AWS Amplifyとの統合

```typescript
// amplify/auth/resource.ts
import { defineAuth } from '@aws-amplify/backend';

export const auth = defineAuth({
  loginWith: {
    email: true,
  },
  userAttributes: {
    email: {
      required: true,
      mutable: false,
    },
    name: {
      required: true,
      mutable: true,
    },
  },
  multifactor: {
    mode: 'OPTIONAL',
    sms: true,
    totp: true,
  },
});

// フロントエンド
import { Amplify } from 'aws-amplify';
import { signUp, signIn, signOut, getCurrentUser } from 'aws-amplify/auth';
import outputs from '../amplify_outputs.json';

Amplify.configure(outputs);

// サインアップ
async function handleSignUp(username: string, password: string, email: string) {
  try {
    const { isSignUpComplete, userId, nextStep } = await signUp({
      username,
      password,
      options: {
        userAttributes: {
          email,
        },
      },
    });

    console.log('Sign up result:', { isSignUpComplete, userId, nextStep });
  } catch (error) {
    console.error('Sign up error:', error);
  }
}

// サインイン
async function handleSignIn(username: string, password: string) {
  try {
    const { isSignedIn, nextStep } = await signIn({ username, password });
    console.log('Sign in result:', { isSignedIn, nextStep });
  } catch (error) {
    console.error('Sign in error:', error);
  }
}

// 現在のユーザー取得
async function getCurrentAuthUser() {
  try {
    const user = await getCurrentUser();
    console.log('Current user:', user);
  } catch (error) {
    console.error('Get current user error:', error);
  }
}
```

---

## ベストプラクティス

### 1. セキュリティ

```typescript
// パスワードポリシーの設定
const userPool = new cognito.UserPool(this, 'UserPool', {
  passwordPolicy: {
    minLength: 12,
    requireLowercase: true,
    requireUppercase: true,
    requireDigits: true,
    requireSymbols: true,
    tempPasswordValidity: cdk.Duration.days(3),
  },
  mfa: cognito.Mfa.REQUIRED, // MFA必須
  mfaSecondFactor: {
    sms: false,
    otp: true, // TOTP推奨
  },
  accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
});
```

### 2. トークンの保存

```typescript
// セキュアなトークン保存（フロントエンド）
class SecureTokenStorage {
  private static readonly ACCESS_TOKEN_KEY = 'access_token';
  private static readonly REFRESH_TOKEN_KEY = 'refresh_token';
  private static readonly ID_TOKEN_KEY = 'id_token';

  // HttpOnly Cookieに保存（推奨）
  static setTokens(accessToken: string, refreshToken: string, idToken: string) {
    // バックエンドAPIを経由してHttpOnly Cookieに設定
    fetch('/api/auth/set-tokens', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ accessToken, refreshToken, idToken }),
      credentials: 'include',
    });
  }

  // メモリ内保存（代替案）
  private static tokens: Map<string, string> = new Map();

  static setTokenInMemory(key: string, value: string) {
    this.tokens.set(key, value);
  }

  static getTokenFromMemory(key: string): string | undefined {
    return this.tokens.get(key);
  }

  static clearTokens() {
    this.tokens.clear();
  }
}
```

### 3. エラーハンドリング

```typescript
async function handleCognitoError(error: any) {
  switch (error.name) {
    case 'UserNotConfirmedException':
      // ユーザー未確認
      console.error('User not confirmed. Please verify your email.');
      break;
    case 'NotAuthorizedException':
      // 認証失敗
      console.error('Invalid username or password.');
      break;
    case 'UserNotFoundException':
      // ユーザー不存在
      console.error('User does not exist.');
      break;
    case 'InvalidParameterException':
      // 無効なパラメータ
      console.error('Invalid parameters:', error.message);
      break;
    case 'TooManyRequestsException':
      // リクエスト過多
      console.error('Too many requests. Please try again later.');
      break;
    case 'LimitExceededException':
      // 制限超過
      console.error('Limit exceeded. Please try again later.');
      break;
    default:
      console.error('Unknown error:', error);
  }
}
```

### 4. Lambda トリガーの活用

```typescript
// Pre Sign-up トリガー
export const handler = async (event: any) => {
  // 自動確認（管理者が承認した場合のみ）
  if (event.request.userAttributes.email.endsWith('@example.com')) {
    event.response.autoConfirmUser = true;
    event.response.autoVerifyEmail = true;
  }

  return event;
};

// Post Confirmation トリガー
export const handler = async (event: any) => {
  // ユーザー登録後の処理（データベースへの保存など）
  const { sub, email, name } = event.request.userAttributes;

  // DynamoDBにユーザー情報を保存
  await dynamoDB.put({
    TableName: 'Users',
    Item: {
      userId: sub,
      email,
      name,
      createdAt: new Date().toISOString(),
    },
  });

  return event;
};

// Pre Token Generation トリガー
export const handler = async (event: any) => {
  // カスタムクレームの追加
  event.response = {
    claimsOverrideDetails: {
      claimsToAddOrOverride: {
        'custom:tenant_id': 'tenant-123',
        'custom:role': 'admin',
      },
    },
  };

  return event;
};
```

---

## トラブルシューティング

### よくあるエラーと解決方法

#### 1. "Unable to verify secret hash for client"

```typescript
// 原因: シークレットハッシュの計算ミス
// 解決: 正しいシークレットハッシュ生成関数を使用

function generateSecretHash(username: string): string {
  return crypto
    .createHmac('SHA256', process.env.COGNITO_CLIENT_SECRET!)
    .update(username + process.env.COGNITO_CLIENT_ID!) // 順序が重要
    .digest('base64');
}
```

#### 2. "Invalid session for the user"

```bash
# 原因: セッションの有効期限切れ
# 解決: リフレッシュトークンを使用して新しいトークンを取得

aws cognito-idp initiate-auth \
  --auth-flow REFRESH_TOKEN_AUTH \
  --client-id YOUR_CLIENT_ID \
  --auth-parameters REFRESH_TOKEN=YOUR_REFRESH_TOKEN
```

#### 3. CORS エラー

```typescript
// API Gatewayでのレスポンスヘッダー設定
const api = new apigateway.RestApi(this, 'Api', {
  defaultCorsPreflightOptions: {
    allowOrigins: apigateway.Cors.ALL_ORIGINS,
    allowMethods: apigateway.Cors.ALL_METHODS,
    allowHeaders: [
      'Content-Type',
      'X-Amz-Date',
      'Authorization',
      'X-Api-Key',
      'X-Amz-Security-Token',
    ],
  },
});
```

### デバッグ方法

```typescript
// CloudWatch Logsでのデバッグ
const userPool = new cognito.UserPool(this, 'UserPool', {
  // 詳細ログを有効化
  advancedSecurityMode: cognito.AdvancedSecurityMode.ENFORCED,
});

// AWS SDK のデバッグログ有効化
import { CognitoIdentityProviderClient } from '@aws-sdk/client-cognito-identity-provider';

const client = new CognitoIdentityProviderClient({
  region: 'us-east-1',
  logger: console, // ログ出力
});
```

---

## 参考リンク

- [AWS Cognito 公式ドキュメント](https://docs.aws.amazon.com/cognito/)
- [AWS SDK for JavaScript v3](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-cognito-identity-provider/)
- [Amazon Cognito Identity SDK for JavaScript](https://github.com/aws-amplify/amplify-js/tree/main/packages/amazon-cognito-identity-js)
- [AWS Amplify Auth](https://docs.amplify.aws/lib/auth/getting-started/)
