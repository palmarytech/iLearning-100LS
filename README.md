# 听力练习助手 (ListeningPractice)

一款专为语言学习者设计的听力练习工具，帮助您通过精确控制音频片段的重复播放来提高听力理解能力。

![听力练习助手截图](/asset//screen.png)

## 功能简介

听力练习助手允许用户导入音频文件，精确选择需要练习的音频片段，并设置重复次数和播放速度，是语言学习和听力训练的理想工具。

## 详细描述

听力练习助手专为需要反复练习特定音频片段的用户设计，特别适合语言学习者、音乐学习者和需要进行听写训练的人群。通过该应用，您可以：

- **导入音频文件**：支持各种常见音频格式
- **精确控制播放区间**：可以设置精确的开始时间和结束时间
- **循环播放**：设置指定片段的重复次数
- **调整播放速度**：提供多种播放速度选项（1.0x、0.85x、0.75x、0.5x）
- **音量增强**：针对音量较小的音频提供音量增强功能
- **实时标记**：在播放过程中可以随时标记当前位置为开始或结束点
- **文本记录**：提供文本输入区域，方便记录音频内容或做笔记

应用界面简洁直观，提供了播放进度条和时间显示，让您能够直观地了解当前播放位置和总时长。

## 特点

- 🎯 **精确控制**：可精确到小数点后一位秒的时间控制
- 🔄 **灵活循环**：自定义循环次数，满足不同难度片段的练习需求
- ⏱️ **实时标记**：播放过程中可随时标记当前位置为开始点或结束点
- 🔊 **音量增强**：针对音量较小的音频提供音量增强功能
- 🐢 **变速播放**：四档播放速度选择，适应不同难度的听力材料
- 📝 **文本记录**：内置文本编辑区域，方便记录音频内容或做笔记
- 📊 **进度可视化**：直观的进度条和时间显示
- 🔍 **精确定位**：通过滑块可以精确定位到音频的任意位置

## 部署方法

### 开发环境配置

1. **系统要求**：
   - macOS 10.15 或更高版本
   - Xcode 12.0 或更高版本
   - iOS 13.0 SDK 或更高版本

2. **获取源代码**：
   ```bash
   git clone https://github.com/yourusername/ListeningPractice.git
   cd ListeningPractice
   ```

3. **打开项目**：
   ```bash
   open ListeningPractice.xcodeproj
   ```

### 构建与运行

1. **选择目标设备**：
   - 在 Xcode 顶部的设备选择器中选择您要运行的设备或模拟器

2. **构建应用**：
   - 按下 `Command + B` 构建应用
   - 或点击 Xcode 工具栏中的 "Build" 按钮

3. **运行应用**：
   - 按下 `Command + R` 运行应用
   - 或点击 Xcode 工具栏中的 "Run" 按钮

### 发布到 App Store

1. **准备应用**：
   - 更新应用版本号和构建号
   - 确保所有必要的应用图标和启动屏幕已添加
   - 完成 App Store 所需的隐私政策和描述

2. **创建归档**：
   - 在 Xcode 中选择 "Product" > "Archive"
   - 等待归档过程完成

3. **上传到 App Store Connect**：
   - 在归档窗口中，选择您的归档并点击 "Distribute App"
   - 选择 "App Store Connect" 并按照向导完成上传

4. **提交审核**：
   - 在 App Store Connect 中完成应用信息
   - 提交应用进行审核

### 直接安装（开发者模式）

1. **连接设备**：
   - 使用 USB 线将 iOS 设备连接到 Mac

2. **信任开发者**：
   - 在 iOS 设备上，前往 "设置" > "通用" > "设备管理"
   - 信任您的开发者证书

3. **安装应用**：
   - 在 Xcode 中选择您的设备作为目标
   - 点击 "Run" 按钮将应用安装到设备上

## 使用场景

- 语言学习者练习听力理解
- 音乐学习者反复练习特定乐段
- 学生进行听写训练
- 演讲者分析和学习演讲技巧
- 口译练习和训练

## 系统要求

- iOS 13.0 或更高版本
- 兼容 iPhone 和 iPad

## 隐私说明

听力练习助手仅在本地处理音频文件，不会上传或分享您的音频内容和练习数据。

## 开源许可

本项目基于 MIT license 许可进行开源。

```
MIT License

Copyright (c) 2023 [版权所有者]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

欢迎贡献代码、报告问题或提出改进建议！