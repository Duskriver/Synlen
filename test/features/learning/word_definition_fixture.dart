const wordSummaryRecord =
    '{"type":"summary","lemma":"sort","phonetic":"/ˈsɔːrtɪd/",'
    '"partOfSpeech":"verb","definitionEn":"put things into groups",'
    '"definitionZh":"分类"}\n';
const wordExplanationRecord =
    '{"type":"explanation","text":"这里 sorted 表示按类别分开。"}\n';
const wordSynonymsRecord =
    '{"type":"synonyms","items":[{"word":"classify","meaning":"分类",'
    '"distinction":"更强调按既定标准划分类别。"}]}\n';
const wordFormationRecord =
    '{"type":"formation","text":"sort 加 -ed 构成过去分词 sorted。"}\n';
const wordDefinitionRecords = [
  wordSummaryRecord,
  wordExplanationRecord,
  wordSynonymsRecord,
  wordFormationRecord,
];
const wordDefinitionContent =
    '$wordSummaryRecord$wordExplanationRecord$wordSynonymsRecord$wordFormationRecord';
