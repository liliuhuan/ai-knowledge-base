# 脚本工具集

这个目录包含多个实用的转换和处理工具。

## 📚 EPUB to Markdown 转换工具

这个工具可以将 EPUB 电子书转换为 Markdown 格式文件，保留章节结构和基本格式。

## 功能特点

- 📖 解析 EPUB 文件结构
- 📝 提取文本内容并转换为 Markdown 格式
- 🏗️ 保留章节结构和标题层次
- 🔗 转换链接和图片
- 📋 支持列表、代码块等格式
- 📊 提取书籍元数据（标题、作者等）

## 安装依赖

无需额外安装依赖，使用 Python 内置库即可运行。

## 使用方法

### 基本用法

```bash
python script/epub_to_markdown.py your_book.epub
```

### 指定输出目录

```bash
python script/epub_to_markdown.py your_book.epub -o /path/to/output
```

## 输出文件

转换完成后会生成以下文件：

1. **主 Markdown 文件**: `book_name.md` - 包含所有章节内容
2. **临时文件夹**: `book_name_temp/` - 解压的 EPUB 原始文件（自动清理）

## 支持的格式

### 输入格式

- `.epub` 文件

### 输出格式

- `.md` Markdown 文件

### 保留的格式

- 章节标题（H1-H6）
- 段落和换行
- 粗体和斜体
- 链接
- 图片
- 有序和无序列表
- 代码块

## 示例

```bash
# 转换当前目录下的电子书
python script/epub_to_markdown.py "我的第一本电子书.epub"

# 转换并指定输出目录
python script/epub_to_markdown.py "/path/to/book.epub" -o "/output/directory"
```

## 注意事项

1. **编码**: 默认使用 UTF-8 编码处理文件
2. **图片**: 图片链接会被保留，但图片文件不会被复制
3. **复杂格式**: 某些复杂的 HTML 格式可能无法完全转换
4. **大文件**: 对于大型 EPUB 文件，转换可能需要一些时间

## 错误处理

如果转换失败，工具会：

- 在控制台显示错误信息
- 保留临时文件以便调试
- 返回非零退出码

## 技术实现

- 使用 `zipfile` 解压 EPUB 文件
- 使用 `xml.etree.ElementTree` 解析 OPF 和 container.xml
- 使用正则表达式和内置 HTML 处理函数转换内容
- 生成标准 Markdown 格式

---

## 🎤 MP3 to Chinese Text 转换工具

这个工具可以将 MP3 等音频文件转换为中文文本，使用 OpenAI Whisper 进行高精度语音识别。

### 功能特点

- 🎵 支持多种音频格式（MP3、WAV、M4A、FLAC、OGG 等）
- 🇨🇳 高精度中文语音识别
- ⏱️ 支持生成带时间戳的文本
- 📝 支持生成字幕文件（SRT、WebVTT）
- 📦 支持批量处理多个音频文件
- 🎯 多种模型大小可选（速度与准确度平衡）

### 安装依赖

首先需要安装 Whisper 库：

```bash
pip install openai-whisper
```

**注意**: Whisper 需要安装 `ffmpeg` 来处理音频文件：

- **macOS**: `brew install ffmpeg`
- **Ubuntu/Debian**: `sudo apt update && sudo apt install ffmpeg`
- **Windows**: 从 [ffmpeg.org](https://ffmpeg.org/download.html) 下载并添加到 PATH

### 使用方法

#### 基本用法

```bash
python script/mp3_to_text.py audio.mp3 --skip-ssl
```

#### 指定输出文件

```bash
python script/mp3_to_text.py audio.mp3 -o output.txt
```

#### 生成带时间戳的文本

```bash
python script/mp3_to_text.py audio.mp3 -f txt_with_timestamps
```

#### 生成 SRT 字幕文件

```bash
python script/mp3_to_text.py audio.mp3 -f srt
```

#### 使用更大的模型（更准确但更慢）

```bash
python script/mp3_to_text.py audio.mp3 -m medium
```

#### 批量处理目录下的所有音频文件

```bash
python script/mp3_to_text.py /path/to/audio/directory -b
```

### 支持的格式

#### 输入格式

- `.mp3` - MP3 音频
- `.wav` - WAV 音频
- `.m4a` - M4A 音频
- `.flac` - FLAC 无损音频
- `.ogg` - OGG 音频
- `.wma` - WMA 音频
- `.aac` - AAC 音频
- `.opus` - Opus 音频

#### 输出格式

- `txt` - 纯文本（默认）
- `txt_with_timestamps` - 带时间戳的文本
- `srt` - SRT 字幕文件
- `vtt` - WebVTT 字幕文件
- `json` - JSON 格式（包含完整信息）

### 模型选择

Whisper 提供多种模型大小，在速度和准确度之间权衡：

| 模型       | 参数量 | 相对速度 | 相对准确度 | 推荐场景               |
| ---------- | ------ | -------- | ---------- | ---------------------- |
| `tiny`   | 39M    | 最快     | 较低       | 快速测试               |
| `base`   | 74M    | 快       | 中等       | **推荐日常使用** |
| `small`  | 244M   | 中等     | 较高       | 平衡选择               |
| `medium` | 769M   | 慢       | 高         | 高质量需求             |
| `large`  | 1550M  | 最慢     | 最高       | 专业用途               |

### 示例

```bash
# 转换单个 MP3 文件
python script/mp3_to_text.py "我的录音.mp3"

# 生成字幕文件
python script/mp3_to_text.py "会议录音.mp3" -f srt

# 批量转换目录下的所有音频
python script/mp3_to_text.py ./audio_files -b -f txt_with_timestamps

# 使用高质量模型
python script/mp3_to_text.py "重要录音.mp3" -m medium -f srt
```

### 注意事项

1. **首次使用**: 首次运行时会自动下载 Whisper 模型，需要网络连接
2. **处理时间**: 转换时间取决于音频长度和模型大小，通常为音频时长的 0.1-1 倍
3. **内存需求**: 较大的模型（medium、large）需要更多内存
4. **GPU 加速**: 如果有 NVIDIA GPU，Whisper 会自动使用 GPU 加速
5. **语言检测**: 默认使用中文（zh），可以通过 `-l` 参数指定其他语言

### 错误处理

如果转换失败，工具会：

- 在控制台显示详细的错误信息
- 显示堆栈跟踪以便调试
- 返回非零退出码

### 技术实现

- 使用 `openai-whisper` 进行语音识别
- 支持多种音频格式（通过 ffmpeg）
- 自动处理时间戳和分段
- 生成标准字幕格式

---

## 许可证

MIT License
