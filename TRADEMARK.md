# Trademark

The source code is MIT. That covers the code, not the identity.

**Not covered by the MIT license:**

- The name **Blink**
- The eye glyph used in the menu bar (`Sources/Blink/EyeIcon.swift`)
- The app icon (`Resources/AppIcon.icns`)

If you fork this and distribute a build, give it a different name and a different icon. That's the whole ask — you can ship it, sell it, change it, strip it for parts. Just don't ship it *as Blink*, because then people can't tell your build from mine, and I can't stand behind a build I didn't make.

A fork that keeps the name but changes the code is the one case that actually causes trouble: someone reports a bug, I look at it, and it isn't in my code.

## Why this and not a stricter license

Because the useful thing here isn't the code. It's four `StageSpec` arrays, a timer, and a panel layout — anyone who writes Swift could rebuild it in a weekend. What's worth protecting is that people can trust the label: if it says Blink, it behaves like Blink, and it doesn't phone home.

A non-commercial license would buy me a slightly smaller chance of being copied, at the cost of GitHub no longer calling the repo open source and every reader having to squint at the fine print. Not worth it.

---

# 商标

代码是 MIT 的。MIT 覆盖代码，不覆盖身份。

**不在 MIT 授权范围内：**

- **Blink** 这个名字
- 菜单栏那只眼睛的图形（`Sources/Blink/EyeIcon.swift`）
- 应用图标（`Resources/AppIcon.icns`）

如果你想 fork 之后分发一个构建，换个名字、换个图标就行。就这一个要求——你可以发布、出售、修改、拆开用。只是别把它当成 Blink 发出去，否则用户分不清哪个是你的、哪个是我的，而我没法为一个不是我做的构建背书。

唯一真会带来麻烦的情况是：留着名字、改了代码。有人来报 bug，我去看，发现根本不在我的代码里。

## 为什么是这个尺度，而不是更严的许可

因为这里值钱的东西不是代码。四个 `StageSpec` 数组、一个计时器、一个面板布局——任何会写 Swift 的人一个周末就能重做一遍。值得保护的是「看到这个名字就能放心」这件事：叫 Blink 的东西，行为就是 Blink，而且不会偷偷联网。

换成非商业许可，能换来被抄的概率稍微低一点，代价是 GitHub 不再把这个仓库标为开源，而且每个读者都得眯着眼看免责条款。不值。
