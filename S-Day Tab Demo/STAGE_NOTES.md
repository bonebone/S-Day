# S-Day Tab Demo

`DemoContentView.swift` 顶部的 `currentStage` 用来选择当前实验阶段。

阶段顺序：

1. `basicTabViewOnly`
2. `navigationStacks`
3. `simpleLists`
4. `listWithoutSection`
5. `listWithoutNavigationStack`
6. `scrollViewLazyVStack`
7. `staticLongVStack`
8. `staticLongVStackNoNavTitle`
9. `fullHeightBlocks`
10. `singleFullScreenBlock`
11. `listGroupedStyle`
12. `customHeader`
13. `customSearchBar`
14. `bottomInsetBar`
15. `appLikeLayout`
16. `appLikeLayoutWithAnimation`

建议记录格式：

- 设备 / 系统：
- 阶段：
- 是否抖动：
- 备注：

当前记录：

- 设备 / 系统：iOS 26
- 阶段：basicTabViewOnly
- 是否抖动：否
- 备注：纯系统 TabView + 4 个 Text 页面，不抖

- 设备 / 系统：iOS 26
- 阶段：navigationStacks
- 是否抖动：否
- 备注：每个 tab 外层增加 NavigationStack，仍然不抖

- 设备 / 系统：iOS 26
- 阶段：simpleLists
- 是否抖动：是
- 备注：切 tab 时像向中心轻微缩小，上半部分向下、下半部分向上；不是单纯整体下沉

- 设备 / 系统：iOS 26
- 阶段：listWithoutSection
- 是否抖动：是
- 备注：去掉 Section 后仍然抖，说明问题更像和 List 本体有关

- 设备 / 系统：iOS 26
- 阶段：listWithoutNavigationStack
- 是否抖动：是
- 备注：去掉 NavigationStack 后仍然抖，说明不是 NavigationStack 与 List 的组合问题

- 设备 / 系统：iOS 26
- 阶段：scrollViewLazyVStack
- 是否抖动：是
- 备注：ScrollView + LazyVStack 仍然抖，问题范围扩大到可滚动容器，而不只是 List

- 设备 / 系统：iOS 26
- 阶段：staticLongVStack
- 是否抖动：是
- 备注：很多静态行内容仍然抖，说明不一定需要滚动容器，复杂布局本身就可能触发

- 设备 / 系统：iOS 26
- 阶段：staticLongVStackNoNavTitle
- 是否抖动：是
- 备注：隐藏 navigationTitle 后仍然抖，说明导航标题本身不是关键触发点

- 设备 / 系统：iOS 26
- 阶段：fullHeightBlocks
- 是否抖动：是
- 备注：少量块状布局但铺满整屏高度时仍然抖，说明问题更像整页容器过渡，而不依赖具体控件种类

- 设备 / 系统：iOS 26
- 阶段：singleFullScreenBlock
- 是否抖动：是
- 备注：即使只剩一个全屏内容块也会抖，说明问题已经非常接近系统 TabView 对完整页面内容的切换行为

- 设备 / 系统：iOS 17
- 阶段：singleFullScreenBlock
- 是否抖动：否
- 备注：与 iOS 26 对照后，问题可稳定归因到 iOS 26 的系统层行为差异

## 当前结论

- `iOS 17` 下，同样的最小 demo 不抖。
- `iOS 26` 下，只要 tab 内容从“极简 Text 页面”进入“完整页面内容”形态，就会出现切换时轻微向中心缩小的抖动。
- 这个现象不依赖以下单个因素：
  - `List`
  - `Section`
  - `NavigationStack`
  - `navigationTitle`
  - `ScrollView + LazyVStack`
  - 复杂业务动画
- 目前最合理的判断是：`iOS 26` 的系统 `TabView` / tab bar 宿主在切换完整页面内容时存在系统层过渡或布局重算行为，主工程里的抖动只是这个系统现象的放大版。

## 实践建议

- 如果优先保留系统 tab bar 外观：接受 `iOS 26` 上这类轻微抖动。
- 如果优先完全消除抖动：使用自定义 tab 容器 / 自定义底部栏，绕开系统 `TabView` 宿主。
- 后续若继续实验，优先测试：
  - `listGroupedStyle`
  - `customHeader`
  - `customSearchBar`
  - `bottomInsetBar`
  这些更适合用于判断“哪些结构会放大系统抖动感”，而不是再判断“问题是不是来自业务代码”。
