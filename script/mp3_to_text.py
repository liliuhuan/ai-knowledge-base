#!/usr/bin/env python3
"""
MP3 to Chinese Text Converter
将 MP3 音频文件转换为中文文本

功能特点:
- 支持多种音频格式（MP3、WAV、M4A、FLAC 等）
- 使用 Whisper 进行高精度中文语音识别
- 支持批量处理
- 可选的输出格式（纯文本、带时间戳、SRT 字幕）
- 自动检测语言或指定中文
"""

import os
import sys
import argparse
from pathlib import Path
import logging
import ssl
import urllib.request
import warnings
import re

# 过滤 Whisper 的 FP16 警告（CPU 不支持 FP16，这是正常的）
warnings.filterwarnings("ignore", message="FP16 is not supported on CPU; using FP32 instead")
warnings.filterwarnings("ignore", category=UserWarning, module="whisper")

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

try:
    import whisper
except ImportError:
    logger.error("未安装 whisper 库，请运行: pip install openai-whisper")
    sys.exit(1)

class MP3ToTextConverter:
    def __init__(self, model_size: str = "base", language: str = "zh", skip_ssl_verify: bool = False):
        """
        初始化 MP3 转文本转换器
        
        Args:
            model_size: Whisper 模型大小 (tiny, base, small, medium, large)
            language: 语言代码，默认为中文 (zh)
            skip_ssl_verify: 是否跳过 SSL 证书验证（用于解决证书验证失败问题）
        """
        self.model_size = model_size
        self.language = language
        self.model = None
        self.skip_ssl_verify = skip_ssl_verify
        
        # 如果需要跳过 SSL 验证，在初始化时就设置
        if self.skip_ssl_verify:
            self._setup_ssl_context()
        
    def _setup_ssl_context(self):
        """设置 SSL 上下文以跳过证书验证"""
        logger.warning("⚠️  已禁用 SSL 证书验证，可能存在安全风险")
        # 设置全局的默认 SSL 上下文
        ssl._create_default_https_context = ssl._create_unverified_context
        
        # 同时设置环境变量（某些库可能会检查）
        os.environ['PYTHONHTTPSVERIFY'] = '0'
        os.environ['CURL_CA_BUNDLE'] = ''
        os.environ['REQUESTS_CA_BUNDLE'] = ''
        
    def load_model(self):
        """加载 Whisper 模型"""
        try:
            logger.info(f"正在加载 Whisper 模型: {self.model_size}")
            
            # 如果跳过 SSL 验证，需要临时修改 urllib 的 urlopen 函数
            if self.skip_ssl_verify:
                original_urlopen = urllib.request.urlopen
                def urlopen_without_ssl(*args, **kwargs):
                    # 创建不验证证书的 opener
                    context = ssl.create_default_context()
                    context.check_hostname = False
                    context.verify_mode = ssl.CERT_NONE
                    https_handler = urllib.request.HTTPSHandler(context=context)
                    opener = urllib.request.build_opener(https_handler)
                    return opener.open(*args, **kwargs)
                
                # 临时替换 urlopen
                urllib.request.urlopen = urlopen_without_ssl
                try:
                    self.model = whisper.load_model(self.model_size)
                finally:
                    # 恢复原始的 urlopen
                    urllib.request.urlopen = original_urlopen
            else:
                self.model = whisper.load_model(self.model_size)
            
            logger.info("模型加载完成")
        except Exception as e:
            logger.error(f"加载模型失败: {e}")
            if "SSL" in str(e) or "certificate" in str(e).lower():
                logger.error("提示: 如果遇到 SSL 证书验证错误，可以使用 --skip-ssl 参数跳过验证")
                logger.error("例如: python mp3_to_text.py audio.mp3 --skip-ssl")
            raise
    
    def transcribe(self, audio_path: str, output_format: str = "txt") -> dict:
        """
        转录音频文件
        
        Args:
            audio_path: 音频文件路径
            output_format: 输出格式 (txt, srt, vtt, json)
            
        Returns:
            dict: 转录结果
        """
        if self.model is None:
            self.load_model()
        
        audio_file = Path(audio_path)
        if not audio_file.exists():
            raise FileNotFoundError(f"音频文件不存在: {audio_path}")
        
        logger.info(f"正在转录音频文件: {audio_path}")
        
        try:
            # 转录音频
            result = self.model.transcribe(
                str(audio_file),
                language=self.language,
                task="transcribe"
            )
            
            logger.info("转录完成")
            return result
            
        except Exception as e:
            logger.error(f"转录失败: {e}")
            raise
    
    def save_text(self, result: dict, output_path: str, format_type: str = "txt", format_text: bool = True):
        """
        保存转录结果到文件
        
        Args:
            result: Whisper 转录结果
            output_path: 输出文件路径
            format_type: 输出格式 (txt, srt, vtt, json)
            format_text: 是否格式化文本（添加标点、分段）
        """
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        if format_type == "txt":
            # 纯文本格式
            text = result['text']
            if format_text:
                text = self.format_text(text)
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(text)
            logger.info(f"文本已保存到: {output_file}")
            
        elif format_type == "txt_with_timestamps":
            # 带时间戳的文本格式
            with open(output_file, 'w', encoding='utf-8') as f:
                for segment in result['segments']:
                    start_time = self.format_timestamp(segment['start'])
                    end_time = self.format_timestamp(segment['end'])
                    text = segment['text'].strip()
                    if format_text:
                        text = self.format_text(text)
                    f.write(f"[{start_time} -> {end_time}] {text}\n\n")
            logger.info(f"带时间戳的文本已保存到: {output_file}")
            
        elif format_type == "srt":
            # SRT 字幕格式
            with open(output_file, 'w', encoding='utf-8') as f:
                for i, segment in enumerate(result['segments'], 1):
                    start_time = self.format_timestamp_srt(segment['start'])
                    end_time = self.format_timestamp_srt(segment['end'])
                    text = segment['text'].strip()
                    f.write(f"{i}\n")
                    f.write(f"{start_time} --> {end_time}\n")
                    f.write(f"{text}\n\n")
            logger.info(f"SRT 字幕已保存到: {output_file}")
            
        elif format_type == "vtt":
            # WebVTT 字幕格式
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write("WEBVTT\n\n")
                for segment in result['segments']:
                    start_time = self.format_timestamp_vtt(segment['start'])
                    end_time = self.format_timestamp_vtt(segment['end'])
                    text = segment['text'].strip()
                    f.write(f"{start_time} --> {end_time}\n")
                    f.write(f"{text}\n\n")
            logger.info(f"WebVTT 字幕已保存到: {output_file}")
            
        elif format_type == "json":
            # JSON 格式
            import json
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            logger.info(f"JSON 结果已保存到: {output_file}")
    
    @staticmethod
    def format_timestamp(seconds: float) -> str:
        """格式化时间戳为 HH:MM:SS.mmm"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int((seconds % 1) * 1000)
        return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"
    
    @staticmethod
    def format_timestamp_srt(seconds: float) -> str:
        """格式化时间戳为 SRT 格式 (HH:MM:SS,mmm)"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int((seconds % 1) * 1000)
        return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"
    
    @staticmethod
    def format_timestamp_vtt(seconds: float) -> str:
        """格式化时间戳为 WebVTT 格式 (HH:MM:SS.mmm)"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int((seconds % 1) * 1000)
        return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"
    
    @staticmethod
    def format_text(text: str) -> str:
        """
        格式化文本：添加标点、分段，提升可读性
        
        Args:
            text: 原始文本
            
        Returns:
            str: 格式化后的文本
        """
        if not text or not text.strip():
            return text
        
        # 移除多余的空白
        text = re.sub(r'\s+', ' ', text.strip())
        
        # 处理数字和百分比（保持在一起，不添加空格）
        # 先处理百分比
        text = re.sub(r'(\d+\.?\d*)\s*%', r'\1%', text)
        
        # 处理"点"（如"0.73点"）
        text = re.sub(r'(\d+\.?\d*)\s*点', r'\1点', text)
        
        # 在常见标点前确保没有多余空格
        text = re.sub(r'\s+([，。！？；：])', r'\1', text)
        
        # 在常见标点后添加空格（如果后面不是空格、换行或结束）
        text = re.sub(r'([，。！？；：])([^\s\n])', r'\1 \2', text)
        
        # 识别句子结束标记（句号、问号、感叹号）
        # 在句号、问号、感叹号后添加换行（如果后面不是引号或结束）
        text = re.sub(r'([。！？])([^"」\n])', r'\1\n\n\2', text)
        
        # 识别段落标记（常见的话题转换词）
        paragraph_markers = [
            r'另外就是', r'另外', r'那么', r'所以说', r'所以', 
            r'但是', r'不过', r'然而', r'而且', r'然后',
            r'首先', r'其次', r'最后', r'总之', r'总的来说',
            r'今天', r'昨天', r'明天', r'现在', r'未来',
            r'我觉得', r'我认为', r'我们', r'大家',
            r'问题\d+[：:]', r'第[一二三四五六七八九十\d]+[、.]',
        ]
        
        for marker in paragraph_markers:
            # 在段落标记前添加换行（如果不在行首）
            pattern = f'([^\n])({marker})'
            text = re.sub(pattern, r'\1\n\n\2', text)
        
        # 处理列表项（数字开头或特殊标记）
        # 在列表项前添加换行
        text = re.sub(r'([。！？\n])([一二三四五六七八九十\d]+[、.])', r'\1\n\2', text)
        text = re.sub(r'([。！？\n])([-•·])\s*', r'\1\n\2 ', text)
        
        # 处理引号内的内容（保持在一起）
        text = re.sub(r'"([^"]+)"', lambda m: f'"{m.group(1)}"', text)
        
        # 处理常见的口语化标记（"对吧"、"是吧"等）
        text = re.sub(r'([，。！？])\s*(对吧|是吧|对吧|是不是)', r'\1 \2', text)
        
        # 清理多余的换行（超过两个连续换行）
        text = re.sub(r'\n{3,}', '\n\n', text)
        
        # 清理行首行尾的空白
        lines = [line.strip() for line in text.split('\n')]
        text = '\n'.join(lines)
        
        # 移除空行之间的多余空行
        text = re.sub(r'\n\s*\n\s*\n', '\n\n', text)
        
        # 确保每段开头没有多余空格
        text = re.sub(r'\n\s+', '\n', text)
        
        # 处理数字和单位（如"2020年"、"11月"等）
        text = re.sub(r'(\d+)(年|月|日|号|点|分|秒|%|个百分点)', r'\1\2', text)
        
        # 处理常见的市场术语（保持在一起）
        market_terms = [
            r'上证指数', r'沪深300', r'创业板', r'科创50', r'中证\d+',
            r'恒生指数', r'恒生科技', r'标普', r'纳斯达克',
            r'人民币', r'美元', r'黄金', r'原油',
        ]
        
        # 确保这些术语不会被分开
        for term in market_terms:
            text = re.sub(f'({term})\s+', r'\1 ', text)
        
        # 修正常见的语音识别错误
        text = re.sub(r'长了\s*(\d+\.?\d*%)', r'涨了\1', text)  # 修正"长了"为"涨了"
        text = re.sub(r'长\s*(\d+\.?\d*%)', r'涨\1', text)  # 修正"长"为"涨"
        text = re.sub(r'温存300', '沪深300', text)  # 修正市场名称
        text = re.sub(r'恒胜', '恒生', text)  # 修正"恒胜"为"恒生"
        text = re.sub(r'习惯成会', '习惯成会', text)  # 保持原样（可能是特定术语）
        
        # 处理常见的口语化表达
        text = re.sub(r'(\w+)\s*对吧\s*', r'\1，对吧', text)
        text = re.sub(r'(\w+)\s*是吧\s*', r'\1，是吧', text)
        
        # 在长句子中适当添加逗号（基于常见模式）
        # 在"因为"、"所以"、"但是"等词前添加逗号（如果前面没有标点）
        conjunctions = ['因为', '所以', '但是', '不过', '然而', '而且', '另外', '同时']
        for conj in conjunctions:
            pattern = f'([^，。！？；：\n])({conj})'
            text = re.sub(pattern, r'\1，\2', text)
        
        # 处理日期格式
        text = re.sub(r'(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})[号日]', r'\1年\2月\3日', text)
        
        # 最终清理：移除行首行尾空白，但保留段落间的空行
        paragraphs = []
        for para in text.split('\n\n'):
            para = para.strip()
            if para:
                paragraphs.append(para)
        text = '\n\n'.join(paragraphs)
        
        return text.strip()
    
    def convert(self, audio_path: str, output_path: str = None, format_type: str = "txt", format_text: bool = True) -> bool:
        """
        执行完整的转换流程
        
        Args:
            audio_path: 音频文件路径
            output_path: 输出文件路径，如果为 None 则自动生成
            format_type: 输出格式 (txt, txt_with_timestamps, srt, vtt, json)
            format_text: 是否格式化文本（添加标点、分段）
            
        Returns:
            bool: 转换是否成功
        """
        try:
            audio_file = Path(audio_path)
            
            # 生成输出文件路径
            if output_path is None:
                if format_type == "txt":
                    output_path = audio_file.with_suffix('.txt')
                elif format_type == "txt_with_timestamps":
                    output_path = audio_file.with_suffix('.txt')
                elif format_type == "srt":
                    output_path = audio_file.with_suffix('.srt')
                elif format_type == "vtt":
                    output_path = audio_file.with_suffix('.vtt')
                elif format_type == "json":
                    output_path = audio_file.with_suffix('.json')
            
            # 转录音频
            result = self.transcribe(audio_path)
            
            # 保存结果（JSON 格式不格式化文本）
            should_format = format_text and format_type not in ['json', 'srt', 'vtt']
            self.save_text(result, output_path, format_type, format_text=should_format)
            
            # 显示统计信息
            duration = result.get('duration', 0)
            text_length = len(result['text'])
            logger.info(f"转录统计:")
            logger.info(f"  音频时长: {duration:.2f} 秒")
            logger.info(f"  文本长度: {text_length} 字符")
            logger.info(f"  输出文件: {output_path}")
            
            return True
            
        except Exception as e:
            logger.error(f"转换过程中发生错误: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='MP3 to Chinese Text Converter',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 基本用法：转换 MP3 为文本
  python mp3_to_text.py audio.mp3
  
  # 指定输出文件
  python mp3_to_text.py audio.mp3 -o output.txt
  
  # 生成带时间戳的文本
  python mp3_to_text.py audio.mp3 -f txt_with_timestamps
  
  # 生成 SRT 字幕文件
  python mp3_to_text.py audio.mp3 -f srt
  
  # 使用更大的模型（更准确但更慢）
  python mp3_to_text.py audio.mp3 -m medium
  
  # 批量处理目录下的所有音频文件
  python mp3_to_text.py /path/to/audio/directory -b
  
  # 跳过 SSL 证书验证（解决证书验证失败问题）
  python mp3_to_text.py audio.mp3 --skip-ssl
  
  # 不格式化文本（保留原始转录结果）
  python mp3_to_text.py audio.mp3 --no-format
        """
    )
    
    parser.add_argument('input', help='输入的音频文件路径或目录路径')
    parser.add_argument('-o', '--output', help='输出文件路径（可选）')
    parser.add_argument(
        '-f', '--format',
        choices=['txt', 'txt_with_timestamps', 'srt', 'vtt', 'json'],
        default='txt',
        help='输出格式 (默认: txt)'
    )
    parser.add_argument(
        '-m', '--model',
        choices=['tiny', 'base', 'small', 'medium', 'large'],
        default='base',
        help='Whisper 模型大小 (默认: base). 越大越准确但越慢'
    )
    parser.add_argument(
        '-l', '--language',
        default='zh',
        help='语言代码 (默认: zh 中文)'
    )
    parser.add_argument(
        '-b', '--batch',
        action='store_true',
        help='批量处理目录下的所有音频文件'
    )
    parser.add_argument(
        '--skip-ssl',
        action='store_true',
        help='跳过 SSL 证书验证（用于解决证书验证失败问题，仅在必要时使用）'
    )
    parser.add_argument(
        '--no-format',
        action='store_true',
        help='不格式化文本（默认会自动添加标点、分段以提升可读性）'
    )
    
    args = parser.parse_args()
    
    # 检查输入路径
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"错误: 路径不存在: {input_path}")
        sys.exit(1)
    
    # 创建转换器
    converter = MP3ToTextConverter(
        model_size=args.model,
        language=args.language,
        skip_ssl_verify=args.skip_ssl
    )
    
    # 支持的音频格式
    audio_extensions = {'.mp3', '.wav', '.m4a', '.flac', '.ogg', '.wma', '.aac', '.opus'}
    
    success_count = 0
    fail_count = 0
    
    if args.batch and input_path.is_dir():
        # 批量处理模式
        logger.info(f"批量处理模式: {input_path}")
        audio_files = [f for f in input_path.iterdir() 
                      if f.is_file() and f.suffix.lower() in audio_extensions]
        
        if not audio_files:
            print(f"错误: 目录中没有找到支持的音频文件")
            sys.exit(1)
        
        logger.info(f"找到 {len(audio_files)} 个音频文件")
        
        for audio_file in audio_files:
            logger.info(f"\n处理文件: {audio_file.name}")
            if converter.convert(str(audio_file), format_type=args.format, format_text=not args.no_format):
                success_count += 1
            else:
                fail_count += 1
        
        logger.info(f"\n批量处理完成: 成功 {success_count} 个, 失败 {fail_count} 个")
        
    elif input_path.is_file():
        # 单文件处理模式
        if input_path.suffix.lower() not in audio_extensions:
            print(f"错误: 不支持的音频格式: {input_path.suffix}")
            print(f"支持的格式: {', '.join(audio_extensions)}")
            sys.exit(1)
        
        success = converter.convert(
            str(input_path),
            args.output,
            format_type=args.format,
            format_text=not args.no_format
        )
        
        if success:
            print("✅ 转换成功！")
            sys.exit(0)
        else:
            print("❌ 转换失败！")
            sys.exit(1)
    else:
        print(f"错误: 输入路径既不是文件也不是目录: {input_path}")
        sys.exit(1)


if __name__ == '__main__':
    main()

