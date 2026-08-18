/**
 * JSPEAK 콘텐츠 JSON API (Apps Script)
 *
 * 기존 HTML 웹앱을 대체하는 "API 전용" 스크립트.
 * 스프레드시트는 회사 Workspace 비공개 공유 상태 그대로 두면 된다 (전체공개 불필요).
 *
 * 배포 방법:
 *  1. 스프레드시트 > 확장 프로그램 > Apps Script 에 이 코드를 붙여넣기
 *  2. 배포 > 새 배포 > 유형: 웹 앱
 *     - 실행 계정: "나" (시트 소유자 권한으로 실행됨)
 *     - 액세스 권한: "링크가 있는 모든 사용자" (URL을 아는 앱만 호출)
 *  3. 생성된 URL(https://script.google.com/macros/s/XXXX/exec)을
 *     Flutter 빌드 시 --dart-define=CONTENT_URL=... 로 전달
 *
 * 시트 컬럼 (Sentences 시트, 1행은 헤더):
 *  A: language | B: chapter_no | C: category | D: chapter_image
 *  E: sentence | F: pronunciation | G: korean | H: audio (Google Drive 파일 ID)
 *  I: popular | J: important (Yes/No) | L: chapter_hook (챕터당 첫 행 1셀만)
 *
 * Words 시트 (1행은 헤더):
 *  A: language | B: chapter_no | C: category | D: chapter_image
 *  E: word | F: pronunciation (IPA) | G: meaning | H: description
 *  I: popular | J: important (Yes/No)
 *
 * 시나리오 시트 (scenarios_en / scenarios_jp / scenarios_cn, 1행은 헤더):
 *  A: scenario_id | B: chapter_no | C: chapter_name | D: chapter_image
 *  E: title | F: order | G: speaker | H: text_ko | I: text_target
 *  J: pronunciation | K: blank_frame | L: flight_stage | M: level | N: new
 *  chapter_image: `ch_boarding.png` 또는 `assets/images/ch_boarding.png`
 *
 * audio 열: Google Drive **파일 ID** 또는 **공유 링크(URL)** 둘 다 가능.
 * "링크 복사"로 받은 주소를 그대로 붙여넣으면 Apps Script가 ID를 추출한다.
 * Apps Script가 자체 프록시 URL(?audio=파일ID)로 변환해 JSON에 내려준다.
 * 배포 확인: CONTENT_URL?jspeak_ping=1 → {"version":2,"audioProxy":true}
 *
 * [중요] UrlFetchApp 권한 (최초 1회):
 *  Apps Script 편집기에서 authorizeOnce 함수를 선택 후 ▶ 실행 → 권한 허용.
 *  (외부 URL 요청: script.external_request)
 *  권한 허용 후 웹앱을 "새 버전"으로 다시 배포한다.
 */

function doGet(e) {
  if (e && e.parameter && e.parameter.audio) {
    return serveDriveAudio(e.parameter.audio);
  }
  const pathAudioId = parseAudioPathInfo(e);
  if (pathAudioId) {
    return serveDriveAudio(pathAudioId);
  }
  if (e && e.parameter && e.parameter.jspeak_ping === '1') {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetNames = ss.getSheets().map(function (s) { return s.getName(); });
    return ContentService.createTextOutput(JSON.stringify({
      version: 3,
      audioProxy: true,
      sheets: sheetNames,
      scenariosEnCount: getScenarios('scenarios_en').length,
    }))
      .setMimeType(ContentService.MimeType.JSON);
  }
  return ContentService
    .createTextOutput(JSON.stringify(getData()))
    .setMimeType(ContentService.MimeType.JSON);
}

function normalizeChapterImage(raw) {
  const text = String(raw || '').trim();
  if (!text) return '';
  let path = text.replace(/\\/g, '/');
  while (path.indexOf('assets/assets/') === 0) {
    path = path.substring('assets/'.length);
  }
  path = path.replace(/learninghub\s+icons\//gi, '');
  path = path.replace(/^assets\/images\//i, '');
  path = path.replace(/^images\//i, '');
  if (/\.(png|jpe?g|webp|gif)$/i.test(path)) {
    return path.replace(/^\/+/, '');
  }
  return '';
}

function getData() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('Sentences');
  const data = sheet.getDataRange().getValues();

  const allSentences = [];

  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const language = row[0];
    const category = row[2];
    if (!language || !category) continue;

    allSentences.push({
      language: language,
      chapter_no: parseInt(row[1]) || 1,
      category: category,
      chapter_image: normalizeChapterImage(row[3]),
      sentence: row[4],
      pronunciation: row[5],
      korean: row[6],
      audio: resolveAudioUrl(row[7]),
      popular: parseInt(row[8]) || 0,
      important: normalizeImportant(row[9]),
      chapter_hook: String(row[11] || '').trim(),
    });
  }

  const allWords = getWords();

  return {
    allSentences: allSentences,
    categoryOrder: buildCategoryOrder(allSentences, allWords),
    allWords: allWords,
    scenariosEn: getScenarios('scenarios_en'),
    scenariosJp: getScenarios('scenarios_jp'),
    scenariosCn: getScenarios('scenarios_cn'),
  };
}

function buildCategoryOrder(allSentences, allWords) {
  const chapterByCategory = {};

  function noteCategory(category, chapterNo) {
    if (!category) return;
    const no = parseInt(chapterNo) || 1;
    if (
      chapterByCategory[category] === undefined ||
      no < chapterByCategory[category]
    ) {
      chapterByCategory[category] = no;
    }
  }

  for (let i = 0; i < allSentences.length; i++) {
    const s = allSentences[i];
    noteCategory(s.category, s.chapter_no);
  }
  for (let j = 0; j < allWords.length; j++) {
    const w = allWords[j];
    noteCategory(w.category, w.chapter_no);
  }

  return Object.keys(chapterByCategory).sort(function (a, b) {
    const cmp = chapterByCategory[a] - chapterByCategory[b];
    if (cmp !== 0) return cmp;
    return String(a).localeCompare(String(b), 'ko');
  });
}

/**
 * 시나리오 시트 파싱 (scenarios_en / scenarios_jp / scenarios_cn).
 * 1행 헤더명으로 컬럼을 찾고, 실패 시 고정 열 인덱스로 폴백한다.
 */
function getScenarios(sheetName) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = getSheetByNameInsensitive(ss, sheetName);
  if (!sheet) return [];

  const data = sheet.getDataRange().getValues();
  if (data.length < 2) return [];

  const headerRow = data[0].map(normalizeScenarioHeader);
  const col = buildScenarioColumnMap(headerRow);

  // 실제 시트 레이아웃 (A~N)
  const FALLBACK = {
    scenario_id: 0,
    chapter_no: 1,
    chapter_name: 2,
    chapter_image: 3,
    title: 4,
    order: 5,
    speaker: 6,
    text_ko: 7,
    text_target: 8,
    pronunciation: 9,
    blank_frame: 10,
    flight_stage: 11,
    level: 12,
    new: 13,
  };

  const HEADER_ALIASES = {
    scenario_id: ['scenario_id', 'scenarioid', 'id'],
    title: ['title', 'scenario_title', 'name'],
    order: ['order', 'seq', 'sequence', 'turn'],
    speaker: ['speaker', 'role'],
    text_ko: ['text_ko', 'textko', 'korean', 'ko'],
    text_target: ['text_target', 'texttarget', 'target', 'sentence'],
    pronunciation: ['pronunciation', 'pron'],
    blank_frame: ['blank_frame', 'blankframe', 'blank'],
    flight_stage: ['flight_stage', 'flightstage', 'topic', 'stage', 'category'],
    level: ['level', 'difficulty'],
    chapter_no: ['chapter_no', 'chapterno', 'chapter', 'chapter_number'],
    chapter_name: ['chapter_name', 'chaptername', 'chapter_title'],
    chapter_image: ['chapter_image', 'chapterimage', 'chapter_thumb', 'chapter_thumbnail'],
    new: ['new', 'is_new', 'isnew', 'new_content'],
  };

  function colIndex(key) {
    const aliases = HEADER_ALIASES[key] || [key];
    for (let i = 0; i < aliases.length; i++) {
      if (col[aliases[i]] !== undefined) return col[aliases[i]];
    }
    return FALLBACK[key];
  }

  function readCell(row, key) {
    const idx = colIndex(key);
    if (idx === undefined || idx < 0 || idx >= row.length) return '';
    const v = row[idx];
    return v === undefined || v === null ? '' : v;
  }

  function parseBoolCell(v) {
    if (v === true || v === 1) return true;
    const s = String(v).trim().toLowerCase();
    return s === 'true' || s === '1' || s === 'yes' || s === 'y';
  }

  function parseRows(useHeader) {
    const rows = [];
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      const scenarioId = useHeader
        ? readCell(row, 'scenario_id')
        : row[FALLBACK.scenario_id];
      if (!scenarioId) continue;

      const idText = String(scenarioId).trim();
      if (!idText || idText.toLowerCase() === 'scenario_id') continue;

      const chapterNoRaw = useHeader ? readCell(row, 'chapter_no') : row[FALLBACK.chapter_no];
      const chapterNo = parseInt(chapterNoRaw) || 1;

      rows.push({
        scenario_id: idText,
        title: String(useHeader ? readCell(row, 'title') : row[FALLBACK.title]).trim(),
        order: parseInt(useHeader ? readCell(row, 'order') : row[FALLBACK.order]) || 0,
        speaker: useHeader ? readCell(row, 'speaker') : row[FALLBACK.speaker],
        text_ko: useHeader ? readCell(row, 'text_ko') : row[FALLBACK.text_ko],
        text_target: useHeader ? readCell(row, 'text_target') : row[FALLBACK.text_target],
        pronunciation: useHeader ? readCell(row, 'pronunciation') : row[FALLBACK.pronunciation],
        blank_frame: useHeader ? readCell(row, 'blank_frame') : row[FALLBACK.blank_frame],
        flight_stage: useHeader ? readCell(row, 'flight_stage') : row[FALLBACK.flight_stage],
        level: useHeader ? readCell(row, 'level') : row[FALLBACK.level],
        chapter_no: chapterNo,
        chapter_name: String(useHeader ? readCell(row, 'chapter_name') : row[FALLBACK.chapter_name]).trim(),
        chapter_image: normalizeChapterImage(
          useHeader ? readCell(row, 'chapter_image') : row[FALLBACK.chapter_image]
        ),
        new: parseBoolCell(useHeader ? readCell(row, 'new') : row[FALLBACK.new]),
      });
    }
    return rows;
  }

  const hasScenarioHeader = col['scenario_id'] !== undefined;
  let rows = hasScenarioHeader ? parseRows(true) : [];
  if (rows.length === 0) {
    rows = parseRows(false);
  }
  return rows;
}

function normalizeScenarioHeader(h) {
  return String(h)
    .replace(/^\uFEFF/, '')
    .trim()
    .toLowerCase()
    .replace(/[\s\u00a0\u200b-]+/g, '_')
    .replace(/[^a-z0-9_]/g, '');
}

function buildScenarioColumnMap(headerRow) {
  const col = {};
  for (let c = 0; c < headerRow.length; c++) {
    if (headerRow[c]) col[headerRow[c]] = c;
  }
  return col;
}

function getSheetByNameInsensitive(ss, name) {
  const target = String(name).trim().toLowerCase();
  const sheets = ss.getSheets();
  for (let i = 0; i < sheets.length; i++) {
    if (sheets[i].getName().trim().toLowerCase() === target) {
      return sheets[i];
    }
  }
  return null;
}

function getWords() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('Words');
  if (!sheet) return [];

  const data = sheet.getDataRange().getValues();
  const allWords = [];

  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const language = row[0];
    const word = row[4];
    if (!language || !word) continue;

    allWords.push({
      language: language,
      chapter_no: parseInt(row[1]) || 1,
      category: row[2] || '',
      chapter_image: normalizeChapterImage(row[3]),
      word: word,
      pronunciation: row[5] || '',
      meaning: row[6] || '',
      description: row[7] || '',
      popular: parseInt(row[8]) || 0,
      important: normalizeImportant(row[9]),
    });
  }

  return allWords;
}

function normalizeImportant(value) {
  if (value === true) return 'Yes';
  if (value === false || value === null || value === undefined || value === '') {
    return 'No';
  }
  const normalized = String(value).trim().toLowerCase();
  if (
    normalized === 'yes' ||
    normalized === 'true' ||
    normalized === '1' ||
    normalized === 'y'
  ) {
    return 'Yes';
  }
  return 'No';
}

/**
 * 시트 audio 셀 값을 앱이 재생할 수 있는 URL로 변환한다.
 * - 빈 값 → ""
 * - Google Drive 파일 ID → 이 웹앱의 ?audio= 프록시 URL
 * - http(s) URL → Dropbox 등은 그대로, Drive 링크는 ID 추출 후 프록시
 */
function resolveAudioUrl(raw) {
  if (!raw) return '';
  const value = String(raw).trim();
  if (!value) return '';

  if (/^https?:\/\//i.test(value)) {
    const driveId = extractDriveFileId(value);
    if (driveId) return buildAudioProxyUrl(driveId);
    return value;
  }

  return buildAudioProxyUrl(value);
}

function buildAudioProxyUrl(fileId) {
  const base = ScriptApp.getService().getUrl();
  const sep = base.indexOf('?') >= 0 ? '&' : '?';
  return base + sep + 'audio=' + encodeURIComponent(fileId);
}

function parseAudioPathInfo(e) {
  if (!e || !e.pathInfo) return null;
  const path = String(e.pathInfo).trim();
  if (path.indexOf('audio/') !== 0) return null;
  const id = path.substring('audio/'.length);
  return id ? decodeURIComponent(id) : null;
}

function serveDriveAudio(fileId) {
  const id = String(fileId).trim();
  try {
    const blob = fetchDriveAudioBlob(id);
    // ContentService는 바이너리를 직접 반환할 수 없어 base64 JSON으로 내려준다.
    // Flutter 앱이 디코딩해 재생한다.
    const payload = {
      mime: blob.getContentType(),
      data: Utilities.base64Encode(blob.getBytes()),
    };
    return ContentService.createTextOutput(JSON.stringify(payload))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      error: 'Audio not found',
      fileId: id,
      detail: String(error),
    }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * DriveApp 권한이 없어도 "링크가 있는 사용자" 공유 파일은
 * 서버 측 UrlFetch로 받을 수 있다.
 */
function fetchDriveAudioBlob(fileId) {
  try {
    return DriveApp.getFileById(fileId).getBlob();
  } catch (driveAppError) {
    const url =
      'https://drive.usercontent.google.com/download?id=' +
      encodeURIComponent(fileId) +
      '&export=download';
    const response = UrlFetchApp.fetch(url, {
      followRedirects: true,
      muteHttpExceptions: true,
    });
    const code = response.getResponseCode();
    if (code < 200 || code >= 300) {
      throw new Error('Drive fetch HTTP ' + code);
    }
    return response.getBlob();
  }
}

function extractDriveFileId(url) {
  let match = url.match(/\/file\/d\/([a-zA-Z0-9_-]+)/);
  if (match) return match[1];
  match = url.match(/[?&]id=([a-zA-Z0-9_-]+)/);
  if (match) return match[1];
  return null;
}

/**
 * 편집기에서 1회 실행해 OAuth 권한을 부여한다.
 * 실행 후 배포 > 배포 관리 > 새 버전으로 웹앱을 다시 배포한다.
 */
function authorizeOnce() {
  UrlFetchApp.fetch('https://www.google.com', { muteHttpExceptions: true });
  const testId = '1TNZ_eWOxd8K1dSxQcgS0H1m1VzRJxMEG';
  const blob = fetchDriveAudioBlob(testId);
  Logger.log('OK bytes=' + blob.getBytes().length + ' type=' + blob.getContentType());
}
