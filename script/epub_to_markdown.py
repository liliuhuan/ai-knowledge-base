#!/usr/bin/env python3
"""
EPUB to Markdown Converter
将 EPUB 电子书转换为 Markdown 格式文件

功能特点:
- 解析 EPUB 文件结构
- 提取文本内容并转换为 Markdown 格式
- 保留章节结构和基本格式
- 支持图片提取和链接转换
"""

import os
import sys
import re
import zipfile
import argparse
from pathlib import Path
from typing import List, Tuple, Optional
import xml.etree.ElementTree as ET
import html
import logging

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class EPUBConverter:
    def __init__(self, epub_path: str, output_dir: str = None):
        """
        初始化 EPUB 转换器
        
        Args:
            epub_path: EPUB 文件路径
            output_dir: 输出目录，如果为 None 则使用 EPUB 文件所在目录
        """
        self.epub_path = Path(epub_path)
        self.output_dir = Path(output_dir) if output_dir else self.epub_path.parent
        self.temp_dir = self.output_dir / f"{self.epub_path.stem}_temp"
        
        # 创建输出目录
        self.output_dir.mkdir(exist_ok=True)
        self.temp_dir.mkdir(exist_ok=True)
        
        # 解析结果
        self.content_files = []
        self.toc = []
        self.metadata = {}
        self.opf_dir = None  # OPF 文件所在目录
        
    def extract_epub(self) -> bool:
        """
        解压 EPUB 文件
        
        Returns:
            bool: 解压是否成功
        """
        try:
            logger.info(f"正在解压 EPUB 文件: {self.epub_path}")
            
            with zipfile.ZipFile(self.epub_path, 'r') as zip_ref:
                zip_ref.extractall(self.temp_dir)
                
            logger.info(f"EPUB 文件已解压到: {self.temp_dir}")
            return True
            
        except Exception as e:
            logger.error(f"解压 EPUB 文件失败: {e}")
            return False
    
    def parse_container(self) -> Optional[str]:
        """
        解析 container.xml 文件，找到 OPF 文件路径
        
        Returns:
            str: OPF 文件路径，如果找不到返回 None
        """
        container_path = self.temp_dir / "META-INF" / "container.xml"
        
        if not container_path.exists():
            logger.error("找不到 container.xml 文件")
            return None
            
        try:
            tree = ET.parse(container_path)
            root = tree.getroot()
            
            # 查找 rootfile
            namespace = {'container': 'urn:oasis:names:tc:opendocument:xmlns:container'}
            rootfile = root.find('.//container:rootfile', namespace)
            
            if rootfile is not None:
                opf_path = rootfile.get('full-path')
                logger.info(f"找到 OPF 文件: {opf_path}")
                return opf_path
            else:
                logger.error("在 container.xml 中找不到 rootfile")
                return None
                
        except Exception as e:
            logger.error(f"解析 container.xml 失败: {e}")
            return None
    
    def parse_opf(self, opf_path: str) -> bool:
        """
        解析 OPF 文件，提取元数据和内容文件列表
        
        Args:
            opf_path: OPF 文件路径
            
        Returns:
            bool: 解析是否成功
        """
        opf_file = self.temp_dir / opf_path
        
        if not opf_file.exists():
            logger.error(f"OPF 文件不存在: {opf_file}")
            return False
        
        # 保存 OPF 文件所在目录，用于解析相对路径
        self.opf_dir = opf_file.parent
            
        try:
            tree = ET.parse(opf_file)
            root = tree.getroot()
            
            # 提取命名空间
            namespaces = {
                'opf': 'http://www.idpf.org/2007/opf',
                'dc': 'http://purl.org/dc/elements/1.1/'
            }
            
            # 提取元数据
            metadata = root.find('opf:metadata', namespaces)
            if metadata is not None:
                self.extract_metadata(metadata, namespaces)
            
            # 提取内容文件
            manifest = root.find('opf:manifest', namespaces)
            if manifest is not None:
                self.extract_manifest(manifest, namespaces, opf_path)
            
            # 提取目录
            spine = root.find('opf:spine', namespaces)
            if spine is not None:
                self.extract_spine(spine, namespaces)
            
            logger.info("OPF 文件解析完成")
            return True
            
        except Exception as e:
            logger.error(f"解析 OPF 文件失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False
    
    def extract_metadata(self, metadata, namespaces: dict):
        """提取元数据"""
        self.metadata = {}
        
        # 提取标题（可能有多个，取第一个）
        title = metadata.find('dc:title', namespaces)
        if title is not None and title.text:
            self.metadata['title'] = title.text.strip()
        else:
            # 尝试查找所有标题
            titles = metadata.findall('dc:title', namespaces)
            if titles:
                self.metadata['title'] = titles[0].text.strip() if titles[0].text else ""
            
        # 提取作者（可能有多个）
        authors = metadata.findall('dc:creator', namespaces)
        if authors:
            author_list = [a.text.strip() for a in authors if a.text]
            if author_list:
                self.metadata['author'] = ', '.join(author_list)
            
        # 提取描述
        description = metadata.find('dc:description', namespaces)
        if description is not None and description.text:
            self.metadata['description'] = description.text.strip()
            
        # 提取日期
        date = metadata.find('dc:date', namespaces)
        if date is not None and date.text:
            self.metadata['date'] = date.text.strip()
            
        # 提取语言
        language = metadata.find('dc:language', namespaces)
        if language is not None and language.text:
            self.metadata['language'] = language.text.strip()
            
        # 提取出版商
        publisher = metadata.find('dc:publisher', namespaces)
        if publisher is not None and publisher.text:
            self.metadata['publisher'] = publisher.text.strip()
            
        logger.info(f"提取元数据: {self.metadata}")
    
    def extract_manifest(self, manifest, namespaces: dict, opf_path: str):
        """提取内容文件列表"""
        self.content_files = []
        
        # OPF 文件所在目录
        opf_dir = (self.temp_dir / opf_path).parent
        
        for item in manifest.findall('opf:item', namespaces):
            href = item.get('href')
            media_type = item.get('media-type')
            item_id = item.get('id')
            
            if not href or not item_id:
                continue
            
            # href 是相对于 OPF 文件所在目录的相对路径
            # 需要先解析相对路径，然后转换为绝对路径
            if href.startswith('/'):
                # 绝对路径（从 EPUB 根目录开始）
                file_path = self.temp_dir / href.lstrip('/')
            else:
                # 相对路径（相对于 OPF 文件所在目录）
                file_path = (opf_dir / href).resolve()
            
            # 检查是否是 HTML/XHTML 内容文件
            is_html = (
                href.endswith(('.html', '.xhtml', '.htm')) or
                media_type in ('application/xhtml+xml', 'text/html', 'application/html+xml')
            )
            
            if is_html:
                # 尝试不同的路径解析方式
                if not file_path.exists():
                    # 尝试直接从 temp_dir 解析
                    file_path = self.temp_dir / href.lstrip('/')
                
                if file_path.exists() and file_path.is_file():
                    self.content_files.append({
                        'id': item_id,
                        'href': href,
                        'path': file_path,
                        'media_type': media_type
                    })
                    logger.debug(f"找到内容文件: {item_id} -> {file_path}")
        
        logger.info(f"找到 {len(self.content_files)} 个内容文件")
        
        # 调试信息
        if not self.content_files:
            logger.warning("未找到任何内容文件，显示调试信息:")
            for item in manifest.findall('opf:item', namespaces):
                href = item.get('href')
                media_type = item.get('media-type')
                item_id = item.get('id')
                if href:
                    # 尝试多种路径解析方式
                    paths_to_try = [
                        (opf_dir / href).resolve(),
                        self.temp_dir / href.lstrip('/'),
                        self.temp_dir / href
                    ]
                    for path in paths_to_try:
                        if path.exists():
                            logger.info(f"  找到文件: {href} -> {path} (类型: {media_type}, ID: {item_id})")
                            break
                    else:
                        logger.info(f"  未找到: {href} (类型: {media_type}, ID: {item_id})")
    
    def extract_spine(self, spine, namespaces: dict):
        """提取目录结构"""
        self.toc = []
        
        for itemref in spine.findall('opf:itemref', namespaces):
            idref = itemref.get('idref')
            if idref:
                # 查找对应的 manifest 项
                for item in self.content_files:
                    if item['id'] == idref:
                        self.toc.append(item)
                        break
        
        logger.info(f"提取到 {len(self.toc)} 个章节")
    
    def convert_to_markdown(self) -> bool:
        """
        将内容转换为 Markdown
        
        Returns:
            bool: 转换是否成功
        """
        if not self.toc:
            logger.error("没有找到章节内容")
            return False
        
        try:
            # 创建主 Markdown 文件
            output_file = self.output_dir / f"{self.epub_path.stem}.md"
            
            with open(output_file, 'w', encoding='utf-8') as md_file:
                # 写入元数据
                self.write_metadata(md_file)
                
                # 转换每个章节
                for i, chapter in enumerate(self.toc, 1):
                    logger.info(f"正在转换第 {i}/{len(self.toc)} 章: {chapter['href']}")
                    self.convert_chapter(chapter, md_file, i)
            
            logger.info(f"Markdown 文件已保存: {output_file}")
            return True
            
        except Exception as e:
            logger.error(f"转换为 Markdown 失败: {e}")
            return False
    
    def write_metadata(self, md_file):
        """写入元数据到 Markdown 文件"""
        if self.metadata:
            md_file.write("# 元数据\n\n")
            
            for key, value in self.metadata.items():
                if value:
                    md_file.write(f"**{key}:** {value}\n\n")
            
            md_file.write("---\n\n")
    
    def convert_chapter(self, chapter: dict, md_file, chapter_num: int):
        """转换单个章节"""
        try:
            # 尝试多种编码方式读取文件
            content = None
            encodings = ['utf-8', 'gbk', 'gb2312', 'latin-1', 'cp1252']
            
            for encoding in encodings:
                try:
                    with open(chapter['path'], 'r', encoding=encoding) as html_file:
                        content = html_file.read()
                    logger.debug(f"成功使用 {encoding} 编码读取文件: {chapter['href']}")
                    break
                except UnicodeDecodeError:
                    continue
            
            if content is None:
                # 如果所有编码都失败，尝试使用错误处理
                with open(chapter['path'], 'r', encoding='utf-8', errors='ignore') as html_file:
                    content = html_file.read()
                logger.warning(f"使用 UTF-8 编码（忽略错误）读取文件: {chapter['href']}")
                
            # 提取标题
            title = self.extract_title_from_html(content, chapter['href'])
            md_file.write(f"# {chapter_num}. {title}\n\n")
            
            # 转换内容
            content_md = self.html_to_markdown_simple(content, chapter['path'])
            md_file.write(content_md)
            
            md_file.write("\n\n---\n\n")
            
        except Exception as e:
            logger.error(f"转换章节失败 {chapter['href']}: {e}")
            import traceback
            logger.error(traceback.format_exc())
    
    def extract_title_from_html(self, html_content: str, default_title: str) -> str:
        """从 HTML 内容中提取标题"""
        # 优先查找 h1 标签
        h1_match = re.search(r'<h1[^>]*>(.*?)</h1>', html_content, re.IGNORECASE | re.DOTALL)
        if h1_match:
            title = h1_match.group(1).strip()
            title = re.sub(r'<[^>]+>', '', title)
            title = html.unescape(title)
            if title:
                return title
        
        # 查找其他标题标签（按优先级）
        for level in range(2, 7):
            pattern = f'<h{level}[^>]*>(.*?)</h{level}>'
            match = re.search(pattern, html_content, re.IGNORECASE | re.DOTALL)
            if match:
                title = match.group(1).strip()
                title = re.sub(r'<[^>]+>', '', title)
                title = html.unescape(title)
                if title:
                    return title
        
        # 查找 title 标签
        title_match = re.search(r'<title[^>]*>(.*?)</title>', html_content, re.IGNORECASE | re.DOTALL)
        if title_match:
            title = title_match.group(1).strip()
            title = re.sub(r'<[^>]+>', '', title)
            title = html.unescape(title)
            if title:
                return title
        
        # 使用文件名作为默认标题
        return Path(default_title).stem
    
    def html_to_markdown_simple(self, html_content: str, html_file_path: Path) -> str:
        """将 HTML 转换为 Markdown"""
        # 移除 head 和 script 部分
        content = re.sub(r'<head[^>]*>.*?</head>', '', html_content, flags=re.DOTALL | re.IGNORECASE)
        content = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.DOTALL | re.IGNORECASE)
        content = re.sub(r'<style[^>]*>.*?</style>', '', content, flags=re.DOTALL | re.IGNORECASE)
        
        # 提取 body 内容
        body_match = re.search(r'<body[^>]*>(.*?)</body>', content, re.DOTALL | re.IGNORECASE)
        if body_match:
            content = body_match.group(1)
        
        # 处理预格式化文本（代码块）
        code_blocks = []
        def replace_code_block(match):
            code_content = match.group(1)
            code_blocks.append(code_content)
            return f"__CODE_BLOCK_{len(code_blocks)-1}__"
        
        content = re.sub(r'<pre[^>]*>(.*?)</pre>', replace_code_block, content, flags=re.DOTALL | re.IGNORECASE)
        
        # 处理代码标签（行内代码）
        def replace_inline_code(match):
            code_text = match.group(1)
            # 移除内部 HTML 标签
            code_text = re.sub(r'<[^>]+>', '', code_text)
            code_text = html.unescape(code_text)
            return f"`{code_text}`"
        
        content = re.sub(r'<code[^>]*>(.*?)</code>', replace_inline_code, content, flags=re.DOTALL | re.IGNORECASE)
        
        # 转换列表（有序和无序）
        # 先标记有序和无序列表，然后处理列表项
        list_items = []
        list_item_counter = 0
        
        # 标记有序列表中的列表项
        def mark_ordered_list(match):
            nonlocal list_item_counter
            ol_content = match.group(1)
            # 查找所有 li 标签并标记为有序
            def mark_li(m):
                nonlocal list_item_counter
                item_content = m.group(1)
                list_items.append((item_content, True, list_item_counter))
                idx = list_item_counter
                list_item_counter += 1
                return f"__LIST_ITEM_{idx}__"
            return re.sub(r'<li[^>]*>(.*?)</li>', mark_li, ol_content, flags=re.DOTALL | re.IGNORECASE)
        
        # 标记无序列表中的列表项
        def mark_unordered_list(match):
            nonlocal list_item_counter
            ul_content = match.group(1)
            # 查找所有 li 标签并标记为无序
            def mark_li(m):
                nonlocal list_item_counter
                item_content = m.group(1)
                list_items.append((item_content, False, list_item_counter))
                idx = list_item_counter
                list_item_counter += 1
                return f"__LIST_ITEM_{idx}__"
            return re.sub(r'<li[^>]*>(.*?)</li>', mark_li, ul_content, flags=re.DOTALL | re.IGNORECASE)
        
        # 先处理有序列表
        content = re.sub(r'<ol[^>]*>(.*?)</ol>', mark_ordered_list, content, flags=re.DOTALL | re.IGNORECASE)
        # 再处理无序列表
        content = re.sub(r'<ul[^>]*>(.*?)</ul>', mark_unordered_list, content, flags=re.DOTALL | re.IGNORECASE)
        
        # 转换标题（从 h1 到 h6，增加一级，因为章节标题已经是 h1）
        for i in range(1, 7):
            def replace_heading(match, level=i):
                heading_text = match.group(1)
                # 移除内部 HTML 标签
                heading_text = re.sub(r'<[^>]+>', '', heading_text)
                heading_text = html.unescape(heading_text).strip()
                # 增加一级标题级别
                new_level = min(level + 1, 6)
                return f"\n{'#' * new_level} {heading_text}\n"
            
            pattern = f'<h{i}[^>]*>(.*?)</h{i}>'
            content = re.sub(pattern, replace_heading, content, flags=re.IGNORECASE | re.DOTALL)
        
        # 转换粗体和强调
        content = re.sub(r'<strong[^>]*>(.*?)</strong>', r'**\1**', content, flags=re.IGNORECASE | re.DOTALL)
        content = re.sub(r'<b[^>]*>(.*?)</b>', r'**\1**', content, flags=re.IGNORECASE | re.DOTALL)
        content = re.sub(r'<em[^>]*>(.*?)</em>', r'*\1*', content, flags=re.IGNORECASE | re.DOTALL)
        content = re.sub(r'<i[^>]*>(.*?)</i>', r'*\1*', content, flags=re.IGNORECASE | re.DOTALL)
        
        # 转换链接
        def replace_link(match):
            url = match.group(1)
            link_text = match.group(2)
            # 处理相对路径
            if url.startswith('#'):
                # 内部锚点链接
                return link_text
            # 移除链接文本中的 HTML 标签
            link_text = re.sub(r'<[^>]+>', '', link_text)
            link_text = html.unescape(link_text)
            return f"[{link_text}]({url})"
        
        content = re.sub(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>', replace_link, content, flags=re.IGNORECASE | re.DOTALL)
        
        # 转换图片
        html_file_dir = Path(html_file_path).parent
        def replace_image(match):
            src = match.group(1)
            alt = match.group(2) if match.group(2) else ""
            # 处理相对路径
            if not src.startswith(('http://', 'https://', '/')):
                # 相对路径，相对于当前 HTML 文件
                img_path = (html_file_dir / src).resolve()
                # 如果图片在 temp_dir 内，使用相对路径
                try:
                    src = str(img_path.relative_to(self.temp_dir))
                except ValueError:
                    src = str(img_path)
            return f"![{alt}]({src})"
        
        content = re.sub(r'<img[^>]+src=["\']([^"\']+)["\'][^>]*(?:alt=["\']([^"\']*)["\'])?[^>]*>', replace_image, content, flags=re.IGNORECASE)
        
        # 转换换行和段落
        content = re.sub(r'<br[^>]*/?>', '  \n', content, flags=re.IGNORECASE)
        content = re.sub(r'</p[^>]*>', '\n\n', content, flags=re.IGNORECASE)
        content = re.sub(r'<p[^>]*>', '\n', content, flags=re.IGNORECASE)
        
        # 转换 div
        content = re.sub(r'</div[^>]*>', '\n', content, flags=re.IGNORECASE)
        content = re.sub(r'<div[^>]*>', '\n', content, flags=re.IGNORECASE)
        
        # 转换其他块级元素
        block_elements = ['section', 'article', 'header', 'footer', 'nav', 'aside']
        for elem in block_elements:
            content = re.sub(f'</{elem}[^>]*>', '\n\n', content, flags=re.IGNORECASE)
            content = re.sub(f'<{elem}[^>]*>', '\n', content, flags=re.IGNORECASE)
        
        # 恢复代码块
        for idx, code_block in enumerate(code_blocks):
            code_text = re.sub(r'<[^>]+>', '', code_block)
            code_text = html.unescape(code_text)
            content = content.replace(f"__CODE_BLOCK_{idx}__", f"\n```\n{code_text}\n```\n")
        
        # 恢复列表项
        # 需要按顺序处理，因为有序列表需要正确的序号
        ordered_counters = {}  # 跟踪每个有序列表的计数器
        
        for item_content, is_ordered, idx in list_items:
            item_text = re.sub(r'<[^>]+>', '', item_content)
            item_text = html.unescape(item_text).strip()
            
            if is_ordered:
                # 有序列表：使用序号
                # 简单处理：使用索引+1作为序号（实际应该按列表分组）
                prefix = f"{idx+1}. "
            else:
                # 无序列表：使用 - 或 *
                prefix = "- "
            
            content = content.replace(f"__LIST_ITEM_{idx}__", f"{prefix}{item_text}\n")
        
        # 移除剩余的 HTML 标签
        content = re.sub(r'<[^>]+>', '', content)
        
        # HTML 实体解码
        content = html.unescape(content)
        
        # 清理多余的空白行（保留最多两个连续换行）
        content = re.sub(r'\n{3,}', '\n\n', content)
        
        # 清理行首行尾空白
        lines = [line.rstrip() for line in content.split('\n')]
        content = '\n'.join(lines)
        
        return content.strip()
    
    def cleanup(self, force=False):
        """清理临时文件"""
        import shutil
        if self.temp_dir.exists() and force:
            try:
                shutil.rmtree(self.temp_dir)
                logger.info(f"已清理临时文件: {self.temp_dir}")
            except Exception as e:
                logger.warning(f"清理临时文件失败: {e}")
    
    def convert(self) -> bool:
        """
        执行完整的转换流程
        
        Returns:
            bool: 转换是否成功
        """
        try:
            # 1. 解压 EPUB 文件
            if not self.extract_epub():
                return False
            
            # 2. 解析 container.xml
            opf_path = self.parse_container()
            if not opf_path:
                return False
            
            # 3. 解析 OPF 文件
            if not self.parse_opf(opf_path):
                return False
            
            # 4. 转换为 Markdown
            success = self.convert_to_markdown()
            
            # 5. 清理临时文件（仅在成功时清理）
            if success:
                self.cleanup(force=True)
            
            return success
            
        except Exception as e:
            logger.error(f"转换过程中发生错误: {e}")
            # 出错时保留临时文件用于调试
            return False

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='EPUB to Markdown Converter')
    parser.add_argument('epub_file', help='输入的 EPUB 文件路径')
    parser.add_argument('-o', '--output', help='输出目录（可选）')
    
    args = parser.parse_args()
    
    # 检查输入文件
    epub_path = Path(args.epub_file)
    if not epub_path.exists():
        print(f"错误: 文件不存在: {epub_path}")
        sys.exit(1)
    
    if not epub_path.suffix.lower() == '.epub':
        print(f"错误: 不是 EPUB 文件: {epub_path}")
        sys.exit(1)
    
    # 执行转换
    converter = EPUBConverter(str(epub_path), args.output)
    success = converter.convert()
    
    if success:
        print("✅ 转换成功！")
        sys.exit(0)
    else:
        print("❌ 转换失败！")
        sys.exit(1)

if __name__ == '__main__':
    main()