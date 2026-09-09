/// Max characters per rendered chunk. A single multi-megabyte string handed
/// to one Text/SelectableText/Markdown widget can overwhelm the web
/// text-layout engine on very large content (a 4MB+ novel crashes
/// CanvasKit), so long content is split into bounded chunks and rendered in
/// a virtualized, lazily-built list.
const maxChunkLength = 2000;

/// Splits [content] into line-based chunks (further split if a single line
/// exceeds [maxLength]), for virtualized rendering. Shared by every plain
/// and Markdown text viewer so their chunking -- and therefore bookmark/TTS
/// chunk-index math -- stays identical.
List<String> splitIntoChunks(String content, {int maxLength = maxChunkLength}) {
  if (content.isEmpty) return const [];
  final chunks = <String>[];
  for (final paragraph in content.split('\n')) {
    if (paragraph.length <= maxLength) {
      chunks.add(paragraph);
      continue;
    }
    for (var i = 0; i < paragraph.length; i += maxLength) {
      chunks.add(paragraph.substring(i, (i + maxLength).clamp(0, paragraph.length)));
    }
  }
  return chunks;
}
