import '../data/reading_settings_controller.dart';
import '../models/reading_settings.dart';

/// Minimal hand-rolled i18n: every UI string keyed once, translated to
/// Korean/English/Japanese/Chinese in that fixed order (matching
/// [AppLocale]'s declaration order, so `AppLocale.index` indexes straight
/// into it). `{name}`-style placeholders are substituted from [params].
String tr(String key, [Map<String, String>? params]) {
  final entry = _dict[key];
  var text = entry == null
      ? key
      : entry[ReadingSettingsController.instance.value.locale.index];
  if (params != null) {
    for (final e in params.entries) {
      text = text.replaceAll('{${e.key}}', e.value);
    }
  }
  return text;
}

const _dict = <String, List<String>>{
  // Common
  'cancel': ['취소', 'Cancel', 'キャンセル', '取消'],
  'delete': ['삭제', 'Delete', '削除', '删除'],
  'create': ['생성', 'Create', '作成', '创建'],
  'apply': ['적용', 'Apply', '適用', '应用'],
  'close': ['닫기', 'Close', '閉じる', '关闭'],
  'back': ['뒤로', 'Back', '戻る', '返回'],
  'home': ['홈으로', 'Home', 'ホームへ', '主页'],
  'search': ['검색', 'Search', '検索', '搜索'],
  'sort': ['정렬', 'Sort', '並び替え', '排序'],

  // Library screen
  'library_title': ['내 서재', 'My Library', 'マイライブラリ', '我的书房'],
  'add': ['추가', 'Add', '追加', '添加'],
  'file_register': ['파일 등록', 'Add File', 'ファイル登録', '添加文件'],
  'folder_create': ['폴더 생성', 'New Folder', 'フォルダ作成', '新建文件夹'],
  'new_folder_title': ['새 폴더', 'New Folder', '新しいフォルダ', '新建文件夹'],
  'folder_name_hint': ['폴더 이름', 'Folder name', 'フォルダ名', '文件夹名称'],
  'delete_folder_confirm_title': [
    '폴더를 삭제하시겠습니까?',
    'Delete this folder?',
    'このフォルダを削除しますか?',
    '要删除此文件夹吗?',
  ],
  'delete_folder_confirm_body': [
    '"{name}" 폴더를 삭제합니다. 안의 파일은 서재 루트로 이동합니다.',
    'This deletes the folder "{name}". Files inside will move to the library root.',
    '「{name}」フォルダを削除します。中のファイルはライブラリのルートに移動します。',
    '将删除文件夹"{name}"。其中的文件将移动到书房根目录。',
  ],
  'move_to_folder': ['폴더로 이동', 'Move to folder', 'フォルダへ移動', '移动到文件夹'],
  'no_folder_root': [
    '폴더 없음 (루트)',
    'No folder (root)',
    'フォルダなし(ルート)',
    '无文件夹(根目录)',
  ],
  'unsupported_format': [
    '지원하지 않는 파일 형식입니다.',
    'Unsupported file format.',
    'サポートされていないファイル形式です。',
    '不支持的文件格式。',
  ],
  'save_failed': [
    '저장 중 오류가 발생했습니다: {error}\n다시 시도하거나 새로고침 후 시도해 주세요.',
    'An error occurred while saving: {error}\nPlease try again, or refresh the page and retry.',
    '保存中にエラーが発生しました: {error}\nもう一度お試しいただくか、ページを更新してから再試行してください。',
    '保存时发生错误: {error}\n请重试,或刷新页面后再试。',
  ],
  'pick_timeout': [
    '파일 선택창이 응답하지 않았어요. 다시 시도해 주세요.',
    "The file picker didn't respond in time. Please try again.",
    'ファイル選択ウィンドウが応答しませんでした。もう一度お試しください。',
    '文件选择窗口无响应,请重试。',
  ],
  'clipboard_empty': [
    '클립보드에 텍스트가 없습니다.',
    'Clipboard has no text.',
    'クリップボードにテキストがありません。',
    '剪贴板中没有文本。',
  ],
  'clipboard_text_name': [
    '클립보드 텍스트 {ts}.txt',
    'Clipboard text {ts}.txt',
    'クリップボードテキスト {ts}.txt',
    '剪贴板文本 {ts}.txt',
  ],
  'import_not_ready': [
    '아직 지원하지 않는 가져오기 방식입니다. 준비 중이에요.',
    "This import method isn't available yet. Coming soon.",
    'この取り込み方法はまだ利用できません。準備中です。',
    '此导入方式暂不支持,敬请期待。',
  ],
  'delete_book_confirm_title': [
    '삭제하시겠습니까?',
    'Delete this?',
    '削除しますか?',
    '要删除吗?',
  ],
  'delete_book_confirm_body': [
    '"{name}"을(를) 서재에서 삭제합니다.',
    'This removes "{name}" from your library.',
    '「{name}」をライブラリから削除します。',
    '将从书房中删除"{name}"。',
  ],
  'delete_selected_confirm_title': [
    '선택 항목을 삭제하시겠습니까?',
    'Delete the selected items?',
    '選択した項目を削除しますか?',
    '要删除所选项目吗?',
  ],
  'delete_selected_folders_part': [
    '폴더 {n}개(안의 파일은 루트로 이동)',
    '{n} folder(s) (files inside move to root)',
    'フォルダ{n}個(中のファイルはルートへ移動)',
    '{n}个文件夹(内部文件将移至根目录)',
  ],
  'delete_selected_books_part': [
    '파일 {n}개',
    '{n} file(s)',
    'ファイル{n}個',
    '{n}个文件',
  ],
  'delete_selected_suffix': [
    '를 삭제합니다.',
    ' will be deleted.',
    'を削除します。',
    '将被删除。',
  ],
  'open_error': [
    '{format}를 여는 중 오류가 발생했습니다: {error}',
    'An error occurred opening the {format}: {error}',
    '{format}を開く際にエラーが発生しました: {error}',
    '打开{format}时发生错误: {error}',
  ],
  'select_delete': ['선택 삭제', 'Select & Delete', '選択削除', '选择删除'],
  'close_search': ['검색 닫기', 'Close search', '検索を閉じる', '关闭搜索'],
  'search_hint': ['이름으로 검색', 'Search by name', '名前で検索', '按名称搜索'],
  'search_prev': ['이전 결과', 'Previous match', '前の結果', '上一个匹配'],
  'search_next': ['다음 결과', 'Next match', '次の結果', '下一个匹配'],
  'content_search_hint': [
    '글 내용에서 검색',
    'Search within this text',
    '本文内を検索',
    '在正文中搜索',
  ],
  'reading_settings': ['읽기 설정', 'Reading Settings', '読書設定', '阅读设置'],
  'tts_start': ['음성으로 듣기', 'Read aloud', '音声で聞く', '朗读'],
  'tts_stop': ['듣기 중지', 'Stop reading', '再生を停止', '停止朗读'],
  'tts_settings': ['음성 설정', 'Voice settings', '音声設定', '朗读设置'],
  'tts_voice': ['목소리', 'Voice', '音声', '声音'],
  'tts_voice_system_default': ['시스템 기본', 'System default', 'システム標準', '系统默认'],
  'tts_speed': ['읽기 속도', 'Reading speed', '読み上げ速度', '朗读速度'],
  'tts_no_voices': [
    '이 브라우저에서 사용 가능한 목소리를 찾을 수 없습니다.',
    'No voices available in this browser.',
    'このブラウザで利用可能な音声が見つかりません。',
    '此浏览器中没有可用的声音。',
  ],
  'cancel_selection': ['선택 취소', 'Cancel selection', '選択解除', '取消选择'],
  'select_all': ['전체 선택', 'Select all', 'すべて選択', '全选'],
  'deselect_all': ['전체 선택 해제', 'Deselect all', 'すべて解除', '取消全选'],
  'selected_count': ['{n}개 선택됨', '{n} selected', '{n}件選択中', '已选择{n}项'],
  'no_search_results': [
    '검색 결과가 없습니다.',
    'No results found.',
    '検索結果がありません。',
    '未找到搜索结果。',
  ],
  'no_files_yet': [
    '아직 추가된 파일이 없습니다.',
    'No files added yet.',
    'まだファイルが追加されていません。',
    '尚未添加任何文件。',
  ],
  'folder_empty': [
    '이 폴더에 파일이 없습니다.',
    'This folder is empty.',
    'このフォルダにファイルがありません。',
    '此文件夹为空。',
  ],
  'supported_formats_hint': [
    'EPUB, PDF, TXT, DOCX, RTF, MusicXML 파일을 열 수 있어요.\nZIP 압축파일 안에 있어도 자동으로 찾아서 열어드려요.',
    'You can open EPUB, PDF, TXT, DOCX, RTF, and MusicXML files.\nEven zipped inside a .zip, we\'ll find and open it automatically.',
    'EPUB、PDF、TXT、DOCX、RTF、MusicXMLファイルを開けます。\nZIPファイルの中にあっても自動的に見つけて開きます。',
    '可以打开EPUB、PDF、TXT、DOCX、RTF、MusicXML文件。\n即使压缩在ZIP文件中,也会自动找到并打开。',
  ],
  'file_count': ['{n}개 파일', '{n} files', '{n}個のファイル', '{n}个文件'],
  'delete_folder': ['폴더 삭제', 'Delete folder', 'フォルダ削除', '删除文件夹'],
  'large_file_delay_hint': [
    '글자수가 많은 텍스트파일은 첫 실행 시 지연시간이 생길 수 있습니다.',
    'Very large text files may take a moment to load the first time.',
    '文字数の多いテキストファイルは初回読み込みに時間がかかることがあります。',
    '字数较多的文本文件首次打开时可能需要一些加载时间。',
  ],
  'rename': ['이름 바꾸기', 'Rename', '名前を変更', '重命名'],
  'file_name_hint': ['파일 이름', 'File name', 'ファイル名', '文件名'],
  'show_format_icon_title': [
    '형식 아이콘 표시',
    'Show Format Icon',
    'ファイル形式アイコンを表示',
    '显示格式图标',
  ],
  'show_format_icon_desc': [
    '목록에서 제목 앞에 TXT·EPUB 등 형식 아이콘을 표시합니다',
    'Shows a TXT/EPUB/etc. icon before each title in the list',
    'リストのタイトルの前にTXT・EPUBなどの形式アイコンを表示します',
    '在列表标题前显示TXT·EPUB等格式图标',
  ],
  'coffee_title': [
    '커피 한 잔 어떠세요? ☕',
    'Buy me a coffee? ☕',
    'コーヒーを一杯いかがですか? ☕',
    '请开发者喝杯咖啡? ☕',
  ],
  'coffee_body': [
    '이 앱을 즐겁게 쓰고 계신다면, 개발자에게 커피 한 잔 값의 응원을 보내보는 건 어때요?\n큰 힘이 됩니다 :)',
    "If you're enjoying this app, consider treating the developer to a coffee.\nIt means a lot :)",
    'このアプリを楽しく使っていただけているなら、開発者にコーヒー一杯分の応援を送ってみませんか?\nとても励みになります :)',
    '如果您喜欢这个应用,不妨请开发者喝杯咖啡表示支持吧。\n这对我意义重大 :)',
  ],
  'coffee_buy': ['커피 사주기', 'Buy a coffee', 'コーヒーを贈る', '请喝咖啡'],
  'coffee_thanks': [
    '따뜻한 마음 감사합니다!',
    'Thanks for the kind thought either way!',
    'お気持ちだけでも嬉しいです!',
    '心意已经让我很感激了!',
  ],
  'char_progress': [
    '{current} / {total}자 · {percent}%',
    '{current} / {total} chars · {percent}%',
    '{current} / {total}文字 · {percent}%',
    '{current} / {total}字 · {percent}%',
  ],

  // Readers (text/epub/pdf)
  'bookmark_added': [
    '북마크에 추가했습니다.',
    'Added to bookmarks.',
    'ブックマークに追加しました。',
    '已添加到书签。',
  ],
  'toc': ['목차', 'Contents', '目次', '目录'],
  'bookmark_add': ['북마크 추가', 'Add Bookmark', 'ブックマーク追加', '添加书签'],
  'bookmark_list': ['북마크 목록', 'Bookmarks', 'ブックマーク一覧', '书签列表'],
  'bookmark_saved_list': [
    '북마크 · 저장한 글귀',
    'Bookmarks & Quotes',
    'ブックマーク・保存した引用',
    '书签 · 收藏的语句',
  ],
  'epub_open_error': [
    'EPUB을 여는 중 오류가 발생했습니다: {error}',
    'An error occurred opening the EPUB: {error}',
    'EPUBを開く際にエラーが発生しました: {error}',
    '打开EPUB时发生错误: {error}',
  ],
  'load_timeout': [
    '불러오는 데 너무 오래 걸리고 있어요.\n네트워크 상태를 확인하고 다시 시도해 주세요.',
    "This is taking too long to load.\nPlease check your connection and try again.",
    '読み込みに時間がかかりすぎています。\nネットワーク状態を確認して再度お試しください。',
    '加载时间过长。\n请检查网络状态后重试。',
  ],
  'load_timeout_back': ['서재로 돌아가기', 'Back to library', 'ライブラリへ戻る', '返回书房'],
  'pdf_open_error': [
    'PDF를 여는 중 오류가 발생했습니다: {error}',
    'An error occurred opening the PDF: {error}',
    'PDFを開く際にエラーが発生しました: {error}',
    '打开PDF时发生错误: {error}',
  ],
  'musicxml_open_error': [
    '악보를 여는 중 오류가 발생했습니다: {error}',
    'An error occurred opening the score: {error}',
    '楽譜を開く際にエラーが発生しました: {error}',
    '打开乐谱时发生错误: {error}',
  ],
  'page_n': ['{n}페이지', 'Page {n}', '{n}ページ', '第{n}页'],
  'jump_first': ['처음으로', 'First page', '最初のページ', '首页'],
  'jump_back10': ['10페이지 뒤로', 'Back 10 pages', '10ページ戻る', '后退10页'],
  'jump_forward10': ['10페이지 앞으로', 'Forward 10 pages', '10ページ進む', '前进10页'],
  'jump_last': ['끝으로', 'Last page', '最後のページ', '末页'],
  'empty_document': ['(빈 문서)', '(empty document)', '(空の文書)', '(空文档)'],
  'empty_paragraph': ['(빈 문단)', '(empty paragraph)', '(空の段落)', '(空段落)'],
  'content_not_found': [
    '내용을 찾을 수 없습니다.',
    'No content found.',
    'コンテンツが見つかりません。',
    '未找到内容。',
  ],
  'save_selection_prompt': [
    '선택한 문장을 저장할까요?',
    'Save the selected text?',
    '選択したテキストを保存しますか?',
    '要保存所选文本吗?',
  ],
  'save_as_highlight': ['형광펜으로 저장', 'Save as Highlight', 'ハイライトとして保存', '保存为高亮'],

  // Saved items screen
  'no_bookmarks': [
    '저장된 북마크가 없습니다.',
    'No bookmarks saved yet.',
    '保存されたブックマークがありません。',
    '尚未保存任何书签。',
  ],
  'bookmarks_count': [
    '북마크 ({n})',
    'Bookmarks ({n})',
    'ブックマーク ({n})',
    '书签 ({n})',
  ],
  'quotes_count': [
    '저장한 글귀 ({n})',
    'Saved Quotes ({n})',
    '保存した引用 ({n})',
    '收藏的语句 ({n})',
  ],
  'no_quotes': [
    '저장된 글귀가 없습니다.\n글을 읽다가 문장을 드래그해 보세요.',
    'No saved quotes yet.\nTry dragging to select text while reading.',
    '保存した引用がありません。\n読書中にテキストをドラッグして選択してみてください。',
    '尚未收藏任何语句。\n阅读时试着拖动选中文本吧。',
  ],

  // docx extractor
  'docx_missing_document_xml': [
    'word/document.xml를 찾을 수 없습니다. 올바른 .docx 파일인지 확인해 주세요.',
    'Could not find word/document.xml. Please check that this is a valid .docx file.',
    'word/document.xmlが見つかりません。正しい.docxファイルか確認してください。',
    '未找到word/document.xml。请确认这是有效的.docx文件。',
  ],

  // File source dialog
  'import_title': ['파일 가져오기', 'Import File', 'ファイルを取り込む', '导入文件'],
  'source_local': [
    '내 컴퓨터 or 모바일에서 가져오기',
    'Import from this computer or phone',
    'このパソコンまたはスマホから取り込む',
    '从这台电脑或手机导入',
  ],
  'source_clipboard': [
    '클립보드에서 붙여넣기',
    'Paste from clipboard',
    'クリップボードから貼り付け',
    '从剪贴板粘贴',
  ],
  'source_onedrive': ['원드라이브', 'OneDrive', 'OneDrive', 'OneDrive'],
  'source_dropbox': ['Dropbox', 'Dropbox', 'Dropbox', 'Dropbox'],
  'dropbox_not_configured': [
    'Dropbox 연동이 아직 설정되지 않았습니다.',
    'Dropbox integration is not configured yet.',
    'Dropbox連携がまだ設定されていません。',
    'Dropbox 集成尚未配置。',
  ],
  'onedrive_not_configured': [
    'OneDrive 연동이 아직 설정되지 않았습니다.',
    'OneDrive integration is not configured yet.',
    'OneDrive連携がまだ設定されていません。',
    'OneDrive 集成尚未配置。',
  ],
  'source_wifi': ['와이파이 전송', 'Wi-Fi Transfer', 'Wi-Fi転送', 'Wi-Fi传输'],
  'source_ftp': ['FTP', 'FTP', 'FTP', 'FTP'],
  'coming_soon': ['준비 중', 'Coming soon', '準備中', '敬请期待'],

  // Onboarding
  'onb_next': ['다음', 'Next', '次へ', '下一步'],
  'onb_show_again': ['다음에 다시 보기', 'Show again next time', '次回また表示', '下次再显示'],
  'onb_never_show': ['다신 안 보기', "Don't show again", '二度と表示しない', '不再显示'],
  'onb_add_title': [
    '오른쪽 아래 + 버튼',
    'Bottom-right + button',
    '右下の + ボタン',
    '右下角的 + 按钮',
  ],
  'onb_add_desc': [
    '여기를 누르면 파일을 등록하거나 새 폴더를 만들 수 있어요.',
    'Tap here to add a file or create a new folder.',
    'ここをタップすると、ファイルを登録したり新しいフォルダを作成できます。',
    '点击这里可以添加文件或新建文件夹。',
  ],
  'onb_folder_title': ['폴더', 'Folders', 'フォルダ', '文件夹'],
  'onb_folder_desc': [
    '탭하면 폴더 안으로 들어가고, 각 파일의 ⋮ 메뉴에서 다른 폴더로 옮기거나 삭제할 수 있어요.',
    "Tap to open a folder, and use each file's ⋮ menu to move or delete it.",
    'タップするとフォルダの中に入れます。各ファイルの ⋮ メニューから移動や削除もできます。',
    '点击可以进入文件夹,通过每个文件的 ⋮ 菜单可以移动或删除文件。',
  ],
  'onb_search_title': ['검색 아이콘', 'Search icon', '検索アイコン', '搜索图标'],
  'onb_search_desc': [
    '이름으로 서재 안의 파일과 폴더를 빠르게 찾을 수 있어요.',
    'Quickly find files and folders in your library by name.',
    '名前でライブラリ内のファイルやフォルダをすばやく検索できます。',
    '可以按名称快速查找书房中的文件和文件夹。',
  ],
  'onb_sort_title': ['정렬 아이콘', 'Sort icon', '並び替えアイコン', '排序图标'],
  'onb_sort_desc': [
    '이름순, 등록순, 최근 읽은 순 등 원하는 방식으로 목록을 정렬할 수 있어요.',
    'Sort your list by name, date added, recently read, and more — whatever suits you.',
    '名前順・登録順・最近読んだ順など、お好みの方法で並び替えができます。',
    '可以按名称、添加日期、最近阅读等你喜欢的方式排序列表。',
  ],
  'onb_trash_title': ['휴지통 아이콘', 'Trash icon', 'ゴミ箱アイコン', '垃圾桶图标'],
  'onb_trash_desc': [
    '여러 파일을 한 번에 골라서 삭제할 수 있어요.',
    'Select several files at once and delete them together.',
    '複数のファイルをまとめて選んで削除できます。',
    '可以一次选择多个文件并删除。',
  ],
  'onb_settings_title': [
    '읽기 설정(톱니)',
    'Reading settings (gear)',
    '読書設定(歯車)',
    '阅读设置(齿轮)',
  ],
  'onb_settings_desc': [
    '글꼴, 크기, 배경, 다크모드 같은 읽기 환경을 취향대로 바꿀 수 있어요. 읽는 도중에도 언제든 다시 열어 바꿀 수 있답니다.',
    'Customize your reading experience — font, size, background, dark mode and more. You can open this and adjust it anytime, even mid-read.',
    'フォント・サイズ・背景・ダークモードなど、読書環境をお好みに合わせて変更できます。読書中でもいつでも開いて調整できますよ。',
    '可以按喜好调整字体、大小、背景、深色模式等阅读环境。阅读过程中随时都能打开调整。',
  ],
  'onb_highlight_title': [
    '읽는 중 문장 드래그',
    'Drag text while reading',
    '読書中にテキストをドラッグ',
    '阅读中拖动选择文本',
  ],
  'onb_highlight_desc': [
    '마음에 드는 문장을 드래그하면 형광펜 색을 골라 저장해둘 수 있어요. 나중에 다시 찾아보기 편해요.',
    "Drag over a sentence you like, pick a highlighter color, and save it — handy for finding it again later.",
    '気に入った文章をドラッグすると、マーカーの色を選んで保存できます。あとで見返すのに便利です。',
    '拖动喜欢的句子,选择一种荧光笔颜色保存下来,以后查找会更方便。',
  ],
  'onb_bookmark_title': ['북마크 추가', 'Add a bookmark', 'ブックマーク追加', '添加书签'],
  'onb_bookmark_desc': [
    '지금 읽던 위치를 북마크로 저장해두면, 나중에 목록에서 바로 그 자리로 돌아올 수 있어요.',
    "Save where you're reading now as a bookmark, and jump straight back to it from the list later.",
    '今読んでいる位置をブックマークとして保存しておくと、あとでリストからすぐそこに戻れます。',
    '把当前阅读的位置保存为书签,以后可以直接从列表跳回这里。',
  ],

  // Reading settings dialog
  'reading_settings_title': ['설정', 'Reading Settings', '読書設定', '阅读设置'],
  'reset_defaults': ['기본값으로', 'Reset to defaults', 'デフォルトに戻す', '恢复默认设置'],
  'display_mode': ['화면 모드', 'Display Mode', '表示モード', '显示模式'],
  'reading_progress_section': ['읽기 진행률', 'Reading Progress', '読書の進捗', '阅读进度'],
  'show_progress_title': ['진행 페이지 표시', 'Show progress', '進捗を表示', '显示进度'],
  'show_progress_desc': [
    '리더 화면 상단에 현재 위치 / 전체 분량을 표시합니다',
    'Shows current position / total length at the top of the reader',
    'リーダー画面の上部に現在位置 / 全体を表示します',
    '在阅读器顶部显示当前位置 / 总长度',
  ],
  'background_color': ['배경색', 'Background Color', '背景色', '背景色'],
  'font_section': ['글꼴', 'Font', 'フォント', '字体'],
  'font_delay_hint': [
    '글자수가 많은 텍스트파일에선 변경 속도가 5초 이상 소요될 수 있습니다.',
    'For very large text files, changing this can take 5+ seconds.',
    '文字数の多いテキストファイルでは、変更に5秒以上かかることがあります。',
    '对于字数较多的文本文件,更改可能需要5秒以上。',
  ],
  'weight_section': ['굵기', 'Weight', '太さ', '粗细'],
  'font_size': ['글자 크기', 'Font Size', '文字サイズ', '字体大小'],
  'letter_spacing': ['자간', 'Letter Spacing', '字間', '字间距'],
  'line_height': ['행간', 'Line Height', '行間', '行间距'],
  'page_margin': ['바깥 여백', 'Page Margin', '余白', '页边距'],
  'paragraph_indent': ['들여쓰기', 'Indent', 'インデント', '首行缩进'],
  'language_section': ['언어', 'Language', '言語', '语言'],
  'app_name_section': ['앱 이름', 'App Name', 'アプリ名', '应用名称'],
  'system_mode': ['시스템', 'System', 'システム', '系统'],
  'light_mode': ['라이트', 'Light', 'ライト', '浅色'],
  'dark_mode': ['다크', 'Dark', 'ダーク', '深色'],

  // Enum labels
  'font_system': ['시스템 기본', 'System Default', 'システムデフォルト', '系统默认'],
  'font_notoSansKr': ['노토 산스', 'Noto Sans', 'Noto Sans', 'Noto Sans'],
  'font_pretendard': ['프리텐다드', 'Pretendard', 'Pretendard', 'Pretendard'],
  'font_maruBuri': ['마루부리', 'Maru Buri', 'マルブリ', 'Maru Buri'],
  'font_notoSerifKr': ['노토 세리프', 'Noto Serif', 'Noto Serif', 'Noto Serif'],
  'font_nanumGothic': ['나눔고딕', 'Nanum Gothic', 'ナヌムゴシック', 'Nanum Gothic'],
  'font_nanumMyeongjo': ['나눔명조', 'Nanum Myeongjo', 'ナヌム明朝', 'Nanum Myeongjo'],
  'font_gowunBatang': ['고운바탕', 'Gowun Batang', 'コウンバタン', 'Gowun Batang'],
  'font_gowunDodum': ['고운돋움', 'Gowun Dodum', 'コウンドドゥム', 'Gowun Dodum'],
  'font_ibmPlexSansKr': [
    'IBM 플렉스 산스',
    'IBM Plex Sans',
    'IBM Plex Sans',
    'IBM Plex Sans',
  ],

  'weight_light': ['가늘게', 'Light', '細字', '细'],
  'weight_regular': ['보통', 'Regular', '標準', '常规'],
  'weight_medium': ['중간', 'Medium', '中太', '中等'],
  'weight_semiBold': ['약간 굵게', 'Semi Bold', 'やや太字', '半粗'],
  'weight_bold': ['굵게', 'Bold', '太字', '粗'],

  'bg_white': ['화이트', 'White', 'ホワイト', '白色'],
  'bg_sepia': ['세피아', 'Sepia', 'セピア', '棕褐色'],
  'bg_gray': ['그레이', 'Gray', 'グレー', '灰色'],
  'bg_dark': ['다크', 'Dark', 'ダーク', '深色'],
  'bg_black': ['블랙', 'Black', 'ブラック', '黑色'],

  'sort_defaultOrder': [
    '내 서재 (기본)',
    'My Library (Default)',
    'マイライブラリ(デフォルト)',
    '我的书房(默认)',
  ],
  'sort_recentlyRead': ['최근 읽은 순', 'Recently Read', '最近読んだ順', '最近阅读'],
  'sort_nameAsc': ['이름순 (가나다·ABC)', 'Name (A-Z)', '名前順(A-Z)', '名称(A-Z)'],
  'sort_nameDesc': ['이름순 (역순)', 'Name (Z-A)', '名前順(Z-A)', '名称(Z-A)'],
  'sort_addedNewest': ['최신 등록순', 'Newest Added', '追加日が新しい順', '最新添加'],
  'sort_addedOldest': ['오래된 순', 'Oldest Added', '追加日が古い順', '最早添加'],

  // Note editor
  'save': ['저장', 'Save', '保存', '保存'],
  'note_create': ['새 글 작성', 'Write New Note', '新規作成', '新建笔记'],
  'note_title_hint': ['제목 없음', 'Untitled', 'タイトルなし', '无标题'],
  'note_untitled': ['제목 없음', 'Untitled', 'タイトルなし', '无标题'],
  'note_body_hint': [
    '내용을 입력하세요 — # 제목, ## 부제목, * 목록, `코드` 처럼 마크다운 문법을 사용할 수 있어요.',
    'Start writing — you can use Markdown, like # heading, ## subheading, * list, `code`.',
    '入力してください — # 見出し、## 小見出し、* リスト、`コード` のようなMarkdown記法が使えます。',
    '开始输入 — 支持 Markdown 语法，如 # 标题、## 副标题、* 列表、`代码`。',
  ],
  'note_preview_empty': [
    '_미리보기할 내용이 없습니다._',
    '_Nothing to preview yet._',
    '_プレビューする内容がありません。_',
    '_没有可预览的内容。_',
  ],
  'note_edit': ['수정', 'Edit', '編集', '编辑'],

  // Markdown shortcuts cheatsheet (note editor)
  'md_help_title': [
    '글쓰기 서식 안내',
    'Formatting Cheatsheet',
    '書式ガイド',
    '格式速查',
  ],
  'md_help_intro': [
    '아래 기호를 넣으면 자동으로 서식이 적용돼요.',
    'Type these and they turn into formatting automatically.',
    '以下の記号を入力すると自動的に書式が適用されます。',
    '输入以下符号会自动应用相应格式。',
  ],
  'md_help_h1': ['제목', 'Heading', '見出し', '标题'],
  'md_help_h2': ['부제목', 'Subheading', '小見出し', '副标题'],
  'md_help_bold': ['굵게', 'Bold', '太字', '加粗'],
  'md_help_italic': ['기울임', 'Italic', '斜体', '斜体'],
  'md_help_list': ['목록', 'List', 'リスト', '列表'],
  'md_help_quote': ['인용', 'Quote', '引用', '引用'],
  'md_help_code': ['코드', 'Code', 'コード', '代码'],
  'md_help_link': ['링크', 'Link', 'リンク', '链接'],

  'note_discard_title': [
    '글 등록을 취소하시겠습니까?',
    'Discard this note?',
    'この投稿を破棄しますか?',
    '要放弃这篇笔记吗?',
  ],
  'note_discard_body': [
    '지금까지 쓴 내용이 저장되지 않습니다.',
    "What you've written won't be saved.",
    'これまで書いた内容は保存されません。',
    '目前写的内容不会被保存。',
  ],
  'note_keep_writing': ['계속 쓰기', 'Keep Writing', '書き続ける', '继续编辑'],
  'note_leave_without_saving': ['나가기', 'Leave', '破棄して戻る', '离开'],

  'backup_title': ['백업', 'Backup', 'バックアップ', '备份'],
  'backup_desc': [
    '내가 쓴 글, 등록한 파일, 북마크, 형광펜을 통째로 파일 하나로 내려받아요.',
    'Download everything -- your notes, imported files, bookmarks and highlights -- as one file.',
    '書いたメモ、登録したファイル、ブックマーク、ハイライトをまとめて1つのファイルでダウンロードします。',
    '将你写的笔记、导入的文件、书签和高亮一起下载为一个文件。',
  ],
  'backup_download': ['바로 다운받기', 'Download Now', '今すぐダウンロード', '立即下载'],
  'backup_share_email': ['메일로 보내기', 'Send by Email', 'メールで送る', '通过邮件发送'],
  'backup_done': ['백업 파일을 저장했어요.', 'Backup saved.', 'バックアップを保存しました。', '备份文件已保存。'],
  'backup_email_subject': [
    'Moon Atelier 백업',
    'Moon Atelier Backup',
    'Moon Atelier バックアップ',
    'Moon Atelier 备份',
  ],
  'backup_email_body': [
    '내 서재 백업 파일을 첨부했어요.',
    "I've attached my library backup file.",
    '書斎のバックアップファイルを添付しました。',
    '已附上我的书房备份文件。',
  ],
  'backup_failed': [
    '백업에 실패했습니다: {error}',
    'Backup failed: {error}',
    'バックアップに失敗しました: {error}',
    '备份失败: {error}',
  ],
};

String fontLabel(ReadingFont f) => tr('font_${f.name}');
String weightLabel(ReadingWeight w) => tr('weight_${w.name}');
String backgroundLabel(String key) => tr('bg_$key');
