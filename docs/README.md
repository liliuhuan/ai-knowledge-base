# Growth 流程图与时序图

## 1. Growth 整体架构图

```mermaid
graph TD
    subgraph "用户兴趣引导"
        IS[InterestSelectionFragment] --- ISV[InterestSelectionViewModel]
        IS --- IA[InterestAdapter]
        US[UserSelectionFragment] --- IUA[InterestUserAdapter]
        US --- USV[UserSelectionViewModel]
        GV[GuideVideoFragment] --- CP[ClosePlugin]
    end
    
    subgraph "新用户启动流程"
        GAL[GrowthAppLaunchManager] --> PDL[PrivacyDialogLauncher]
        GAL --> LDL[LoginDialogLauncher]
        GAL --> NUG[NewUserGuideLauncher]
        GAL --> SR[SceneRestoreLauncher]
        GAL --> ICL[InfoCollectionLauncher]
    end
    
    subgraph "设置页-评价功能"
        GMCD[GuideMarketCommentDialog] --- GMCI[GuideMarketCommentImpl]
        GMCI --- GMCIF[GuideMarketCommentInterface]
    end
    
    subgraph "引导用户打开推送开关"
        GPD[GuidePushDialog] --- GPL[GuidePushLifecycle]
        OPGD[OpenPushGuideDialog] --- PDI[PushDialogImpl]
        PDI --- PGDI[PushGuideDialogInterface]
    end
    
    subgraph "新注册用户领取权益"
        FBD[FourEBooksDialog] --- NREDI[NewRegisterEquityDialogImpl]
        NREDI --- NREDIF[NewRegisterEquityDialogInterface]
    end
    
    GAL --> GV
    GAL --> IS
```

## 2. Growth 新用户启动流程图

```mermaid
graph TD
    A[应用启动] --> B{判断是否需要增长引导}
    B -->|是| C[开始执行新用户启动流程]
    B -->|否| D[结束增长流程]
    
    C --> E[隐私弹框流程]
    E --> F{用户选择}
    F -->|同意| G[下一步]
    F -->|不同意| H[显示挽留弹框]
    H -->|同意| G
    H -->|不同意| I[解释说明页面]
    I -->|进入仅浏览模式| J[标记仅浏览模式]
    J --> ZZ[结束]
    
    G --> K{是否实验组-信息收集}
    K -->|是| L1[兴趣标签请求]
    K -->|否| L2[场景还原Pre]
    
    L1 --> M1[场景还原Pre]
    M1 --> N[信息收集]
    N --> O1[场景还原End]
    O1 --> ZZ
    
    L2 --> P[登陆弹框]
    P --> Q[新用户引导]
    Q --> R[场景还原End]
    R --> ZZ
```

## 3. Growth 新用户启动时序图

```mermaid
sequenceDiagram
    participant App as 应用
    participant GM as GrowthAppLaunchManager
    participant PD as PrivacyDialogLauncher
    participant SR as SceneRestoreLauncher
    participant IC as InfoCollectionLauncher
    participant LD as LoginDialogLauncher
    participant NUG as NewUserGuideLauncher

    App->>GM: 启动应用
    GM->>GM: isNeedGrowthGuide()
    alt 需要增长引导
        GM->>PD: launchPrivacyDialog()
        PD->>PD: 显示隐私弹框
        
        alt 用户同意隐私协议
            PD-->>GM: 隐私弹框流程结束(success)
            GM->>GM: afterPrivacyDialog()
            
            alt 仅浏览模式
                GM->>GM: 设置仅浏览模式标记
                GM->>GM: 结束流程
            else 正常模式
                alt 实验组-信息收集
                    GM->>SR: launchPreScene() - 场景还原Pre
                    SR-->>GM: 场景还原Pre完成
                    GM->>IC: launchInfoCollection()
                    IC-->>GM: 信息收集完成
                    GM->>SR: launchEndSceneAfterInfoCollection() - 场景还原End
                    SR-->>GM: 场景还原End完成
                else 对照组-标准流程
                    GM->>SR: launchPreScene() - 场景还原Pre
                    SR-->>GM: 场景还原Pre完成
                    GM->>LD: launchLoginDialog()
                    LD-->>GM: 登陆弹框流程结束
                    GM->>NUG: launchNewUserGuide()
                    NUG-->>GM: 新用户引导完成
                    GM->>SR: launchEndScene() - 场景还原End
                    SR-->>GM: 场景还原End完成
                end
                GM->>GM: afterPrivacyDialogEnd()
                GM->>GM: 申请通知权限
            end
        else 用户不同意隐私协议
            PD->>PD: 显示挽留弹框
            alt 用户选择同意
                PD-->>GM: 隐私弹框流程结束(success)
                note over GM: 继续正常流程
            else 用户选择仅浏览
                PD->>PD: 显示解释说明页面
                PD-->>GM: 隐私弹框流程结束(browse)
                GM->>GM: 设置仅浏览模式标记
                GM->>GM: 结束流程
            end
        end
    else 不需要增长引导
        GM->>GM: 结束流程
    end
```

## 4. Growth 场景还原流程图

```mermaid
graph TD
    A[场景还原启动] --> B{是否需要执行场景还原}
    B -->|否| C[结束场景还原]
    B -->|是| D{是否Link调起或动态包}
    D -->|否| C
    D -->|是| E{是否有启动Link}
    
    E -->|是| F[使用Link打开页面]
    E -->|否| G[执行动态包场景还原]
    
    G --> H[发起网络请求]
    H --> I{请求是否成功}
    I -->|否| J[场景还原失败]
    I -->|是| K{场景还原开关}
    
    K -->|关闭| J
    K -->|打开| L{判断场景还原类型}
    
    L -->|V3全屏| M[打开场景还原V3全屏页面]
    L -->|V4半屏| N[打开场景还原V4半弹框]
    
    M --> O[场景还原成功]
    N --> O
    
    J --> C
    O --> C
```

## 4.1 Growth 场景还原时序图

```mermaid
sequenceDiagram
    participant GAL as GrowthAppLaunchManager
    participant SR as SceneRestoreLauncher
    participant Net as 网络服务
    participant ZR as ZRouter
    participant ZA as 埋点服务

    GAL->>SR: launchPreScene()/launchEndScene()
    SR->>SR: isNeedExecScene()
    
    alt 需要执行场景还原
        SR->>SR: isLinkLaunchOrTicket()
        
        alt 是Link调起
            SR->>SR: getLaunchOpenLink()
            SR->>ZA: 添加埋点染色标记
            SR->>ZA: 场景还原打开URL埋点
            SR->>ZR: ZRouter.with(link).open()
            SR->>ZA: 外链调起埋点
            SR-->>GAL: 场景还原成功完成
        else 是动态包
            SR->>SR: getDynamicAppTicket()
            SR->>SR: requestULinkParams()
            SR->>Net: 请求场景还原数据(/reduction_v4)
            
            alt 网络请求成功
                Net-->>SR: 返回场景还原数据
                SR->>SR: 处理场景还原数据
                SR->>ZA: 添加埋点染色标记
                SR->>ZA: sceneRestorationResponse() 场景还原响应埋点
                
                alt 场景还原开关打开
                    SR->>SR: toScenePageV3V4()
                    
                    alt V3全屏类型
                        SR->>ZA: sceneRestorationV3OpenUrl() 埋点
                        SR->>ZR: ZRouter.with(deepLink).open()
                        SR-->>GAL: 场景还原成功完成
                    else V4半屏类型
                        SR->>SR: isSceneV4OK()
                        SR->>SR: 创建并显示SceneRestoreV4AnswerArticleFragment/SceneRestoreV4QuestionFragment
                        SR-->>GAL: 场景还原成功完成
                    end
                else 场景还原开关关闭
                    SR-->>GAL: 场景还原失败完成
                end
            else 网络请求失败
                Net-->>SR: 返回错误
                SR->>ZA: 场景还原失败埋点
                SR-->>GAL: 场景还原失败完成
            end
        end
    else 不需要执行场景还原
        SR-->>GAL: 场景还原直接完成(已消费)
    end
```

## 5. Growth 隐私弹框流程图

```mermaid
graph TD
    A[隐私弹框启动] --> B{是否需要显示隐私弹框}
    B -->|否| C[结束隐私流程]
    B -->|是| D[显示隐私协议弹窗]
    
    D --> E{用户选择}
    E -->|同意| F[流程结束-同意]
    E -->|不同意| G[显示挽留弹框]
    
    G --> H{用户选择}
    H -->|同意| F
    H -->|仅浏览| I[显示解释说明页面]
    
    I --> J[用户点击进入仅浏览模式]
    J --> K[流程结束-仅浏览]
```

## 6. Growth 新用户引导流程图

```mermaid
graph TD
    A[新用户引导启动] --> B{是否需要显示新用户引导}
    B -->|否| C[结束新用户引导]
    B -->|是| D{是否是新注册用户}
    
    D -->|否| C
    D -->|是| E[打开新用户引导页面]
    
    E --> F[用户浏览/操作]
    F --> G[发送引导完成事件]
    G --> H[结束新用户引导]
```

## 7. Growth 登录流程图

```mermaid
graph TD
    A[登录弹框启动] --> B{是否已经消费过登录流程}
    B -->|是| C[结束登录流程]
    B -->|否| D[注册登录关闭事件]
    
    D --> E{支持一键登录?}
    E -->|是| F[打开一键登录]
    E -->|否| G[打开标准登录弹框]
    
    F --> H[用户操作登录]
    G --> H
    
    H --> I[设置已消费登录标记]
    I --> J[接收登录结束事件]
    J --> K[清理登录染色标记]
    K --> L[结束登录流程]
```

## 8. Growth 兴趣选择流程图

```mermaid
graph TD
    A[兴趣选择启动] --> B[InterestSelectionFragment显示]
    B --> C{用户操作}
    
    C -->|选择标签| D[InterestAdapter更新]
    C -->|完成| E[InterestSelectionViewModel处理数据]
    
    E --> F[UserSelectionFragment显示]
    F --> G[用户选择关注用户]
    G --> H[InterestUserAdapter更新]
    
    H --> I[GuideVideoFragment显示]
    I --> J[视频引导播放]
    J --> K[用户结束引导]
    
    K --> L[上报选择结果]
    L --> M[结束兴趣选择]
```
