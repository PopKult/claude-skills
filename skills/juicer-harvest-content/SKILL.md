---
name: juicer-harvest-content
description: Turns a transcript into a complete PopKult Juicer content package - key phrases that together cover about 80% of the text's meaning, each lifted in a reusable form the learner can use in any situation, not only this transcript's, discussion questions with word-by-word translations, answering advice, and 3 translation-practice sentences per phrase (2 forward + 1 backward) with word-by-word glosses. Only a transcript plus its language pair is required - the skill translates the transcript itself if a translation isn't already supplied. The phrase list is reviewed and approved once, then every phrase's full package is built back-to-back and delivered as one final combined JSON object - no per-phrase pause. Use this whenever given a transcript (and its language pair) and asked to harvest content, extract phrases, build Juicer content, or run the content pipeline on it.
---

# Juicer content harvester

You are standing in for PopKult's "Juicer" content-authoring pipeline,
which normally runs as four gated AI stages (extract phrases, write
questions, translate them word-by-word, write answering advice) plus a
second pipeline that generates translation-practice sentences and
splits them into words. Here you do all of that yourself: the phrase
list gets one human review pass (§5), then every phrase's full package
is built back-to-back with no further pausing (§6), relying on the
self-check in §6.5 rather than a human catching problems phrase by
phrase.

**The person running this skill may not be a programmer.** Explain
things in plain language, don't assume they know what "JSON" is beyond
"the structured text block below" - but still produce exact, correctly
formatted JSON every time, because that output is meant to be usable by
an engineer or an importer script later.

## 1. Collect the input

Before starting, make sure you have:

- **Original text** - the transcript, in its original language.
- **Original language code** (e.g. `EN`).
- **Translation language code** (e.g. `RU`).

If the person hasn't given you all three, ask for whichever is missing.
Don't guess a language code from the text yourself if they haven't
stated it - confirm it with them.

**Translated text is optional.** If the person already has a full
translation of the transcript and gives it to you, use it as-is instead
of retranslating. If they don't, that's the normal case - Gate 1 (§5)
produces the translation itself, as its first step, before extracting
phrases from it.

## 2. Ground rule: the atomic word unit

Whenever anything below refers to "words" or "tokens" of a text, split
that text **only on whitespace**. Punctuation stays attached to
whichever word it's next to - `"Friday."` is one token, not two. Never
re-split on punctuation, never drop a token, never reorder tokens. This
is the atomic unit everything else below is built from - even when a
later step groups several of these tokens into one glossed "part", the
grouping never splits a token in half or reorders it.

## 3. How to gloss a text against its own full translation ("chunk-match")

This is the method used in two places below (question word-translation,
§6.1; translation-task word-splitting, §6.4). It exists to avoid two
failure modes seen in earlier attempts: translating single words in
isolation produces disconnected, sometimes-wrong glosses, and forcing a
1:1 word-for-word mapping leaves gaps (`""`) wherever a language doesn't
have a clean single-word counterpart (articles, particles, split verb
constructions, case markers, etc.).

Given a stretch of original-language text to gloss (a question, or a
translation-task's `before`/`after` text - **never** a `target` span;
the target phrase is always its own single unsplit entry, see §6.4
step 2) and the full sentence it's part of:

1. **Translate the whole sentence first**, naturally and fluently, into
   the other language. Keep this translation as grounding context - the
   later per-part glosses are pulled from it, never invented fresh in
   isolation.
2. **Group the stretch's word-tokens (§2) into an ordered sequence of
   "parts"**. Default to one token per part. Merge two or more adjacent
   tokens into a single part only when they don't have a sensible
   standalone counterpart on their own - a phrasal-verb particle, an
   article, a case-marking word, a fixed multi-word expression. Keep
   parts short - usually 1-3 words; go longer only when a single fixed
   expression genuinely can't be split without becoming nonsense. This
   grouping never applies to a `target` span - it stays whole no matter
   how many words it has.
3. **For each part, pull its corresponding span out of the full
   translation from step 1** and use that as the part's gloss - copied
   or lightly adapted from the real, whole-sentence translation, never
   translated as if the part were standing alone.
4. **No empty glosses, ever.** If a token genuinely has no standalone
   counterpart, that's a sign to merge it into a neighboring part (step
   2), not to give it `""`. Every part's translation must be a real,
   non-empty, sensible rendering. One narrow exception: a token made up
   only of punctuation (no letters at all) - which can only arise as a
   lone trailing character right after `target`, since merging it left
   would mean splitting `target` - isn't a word to translate. Keep it
   as its own entry with the punctuation itself as the "translation"
   (e.g. `"."` -> `"."`), since it was never a word to begin with.
5. The parts' original-language text, concatenated back together and
   re-split per §2, must reproduce the exact same token sequence as the
   original stretch - nothing added, dropped, or reordered, just
   grouped differently.

## 4. How this works: approve the phrase list, then build everything at once

Two stages, in this order:

1. **Translation + the phrase list (once, gated).** If needed,
   translate the whole transcript, then extract key phrases from it in
   one pass - grounded strictly in what the transcript actually
   says, never invented (§5). Show both as JSON and **stop and wait**
   for approval or corrections. The person can correct the translation,
   and/or add, remove, or reword phrases here - this defines the scope
   of everything that follows, so get it right before building on top
   of it. This is the one mandatory pause point.
2. **Every phrase's full package, all at once (not gated).** Once the
   phrase list is approved, build every phrase's entire content package
   - question, word-by-word question translation, helpers, and all 3
   word-split translation tasks (§6) - for the whole list, one phrase
   after another, without stopping in between. Silently run each
   phrase's self-check (§6.5) as you build it. Once every phrase is
   done, show the **one final combined JSON** (§7) covering the whole
   set - that's the deliverable.

This trades the per-phrase review gate for speed: building the whole
set back-to-back is faster than pausing after each one, but it also
means nobody checks each phrase before the next is built on top of the
same approved list - the self-check in §6.5 is the only safety net
during the batch, not a human. If the person flags a problem with a
specific phrase after seeing the final combined JSON, fix just that
phrase and re-show either that phrase alone or the whole updated JSON,
whichever is clearer - don't make them re-approve the entire batch over
one correction.

## 5. Gate 1 - Translate the transcript, then extract the key phrase list

If you don't already have a translated text (§1), **translate the whole
original text first**: a natural, complete, fluent translation of the
full transcript into the translation language. This becomes the
official translation for the rest of the process. Get this right before
building on it - a mistranslated transcript quietly corrupts every
phrase pulled from it below.

Then read the original and translated text together and pick the key
phrases in **one pass**. The hard rule:

**Never invent a phrase.** Every phrase MUST be lifted from - or be a
minimal normalization of (dropping the subject, tense, filler, or
transcript-specific details around it, per the rules below) - words that
actually appear in the transcript. Never substitute a synonym,
paraphrase, or "better way to say this" that doesn't itself appear in
the text. If nothing genuine is there for a spot, return nothing for it
- don't manufacture a phrase to fill a quota.

### The goal: understanding, not a quota

Pick the smallest set of phrases that a learner needs in order to
understand **about 80% of what the text says**. Judge this by meaning,
not by counting: walk through the text and take the phrases without
which the main idea and the key events/points can't be followed. Skip
minor details, repetitions, asides, and filler.

- There is **no per-sentence quota**. A sentence may yield no phrase (bare
  interjection, one-word acknowledgment, pure filler, minor detail), one,
  or several - as many as the sentence's important content genuinely
  needs (e.g. a sentence listing parallel, independently important items
  can yield one phrase per item).
- **A sentence that's cut off or grammatically incomplete (e.g. the
  transcript ends mid-sentence) is NOT automatically skipped.** Look for
  a complete, self-contained span within what was actually said - a
  subject noun phrase is often fully intact and extractable even when
  its verb never got transcribed. Only skip it if there's nothing
  complete to extract.

### The form: reusable in any situation

Every phrase must be something the learner can use in their **own**
speech in many different situations, not only in the situation of this
transcript. So when you lift a phrase, strip everything specific to this
transcript and keep the transferable core - the verb + particle, the
collocation, the fixed expression - using only words that really appear
in the text.

- "He handed the drill press to Mike" -> `hand over` (or `hand [it]
  over`), not `hand the drill press to Mike`.
- "She ran out of patience with the contractor" -> `run out of patience`,
  not `run out of patience with the contractor`.
- If the phrase only makes sense with an object, mark the slot with a
  bracketed pronoun placeholder (`[it]`, `[them]`, `[one's]`). This is
  the only thing you may add that isn't in the transcript; the
  bracketed word doesn't count toward the word limit.
- **Fallback for concrete-noun sentences.** If a sentence is carried
  only by a concrete, situation-specific noun (a tool, an object, a
  place) and has no transferable core, don't skip it: take the noun with
  its most stable everyday surrounding from the transcript (e.g. `use a
  drill press`), so the learner still gets the word they need to follow
  the text. Prefer a phrase with a transferable verb/collocation over a
  bare noun phrase whenever the sentence offers one.

### Shared rules

Strip the subject, the tense, the filler, and the surrounding context,
but KEEP the articles and small words that belong to the expression. An
imperative counts as material too: from "Trust the process" take "trust
the process".

Each phrase must be:

- 2 to 5 words. Reject anything that reads as a full sentence or
  clause. Never slice across a grammatical boundary - a phrase must be a
  self-contained unit (a verb phrase, a prepositional phrase, a short
  fixed expression), never an arbitrary word-count slice that starts or
  ends mid-construction.
- in base / dictionary form: infinitive verbs (not "brushing"), no
  subject pronoun, lowercase, no punctuation (the bracketed placeholder
  above is the only exception). This normalization (verb tense, subject
  pronoun, surrounding filler, transcript-specific details) is the only
  kind of change allowed between the transcript's actual wording and the
  phrase you return - it must never introduce a word that wasn't there.
- never a proper name, a number or price, or pure filler ("okay",
  "alright", "oh my gosh").
- not a near-duplicate of another phrase you've already returned.

Translate each phrase as a phrase of the same kind - a verb phrase stays
an infinitive verb phrase ("take a break" -> "сделать перерыв", not the
bare noun "перерыв").

There's no fixed cap; the set scales with how much of the text needs
covering. Never return zero overall - if the transcript is short, still
return the strongest few you can find.

**Output** (assign short placeholder ids `kp1`, `kp2`, ... - these are
just handles for this conversation, not permanent database ids). List
phrases in the order they appear in the transcript. Include
`translatedText` only if you produced it yourself this step - omit the
field entirely if the person already supplied their own translation, so
it's clear whose translation is in play:

```json
{
  "translatedText": "string, full transcript translation - only if you produced it",
  "keyPhrases": [
    {"id": "kp1", "phrase": "string, original language", "translation": "string, translation language"}
  ]
}
```

Stop here and wait for approval or corrections - on the translation,
the phrase list, or both - before starting Gate 2. If the person
corrects the translation, re-check the phrase list against the
corrected text before moving on, since phrases were pulled from the
version you're now replacing.

## 6. Build every phrase's full package

For each approved phrase from Gate 1's list, in order, do all four of
the following, then move directly to the next phrase - no pause, no
individual display, per §4. Once every phrase in the list has been
built and self-checked (§6.5), assemble and show the one combined JSON
(§7).

### 6.1 Write the question, then gloss it word-by-word

Write one question, in the **original language**, that asks for the
learner's own opinion or personal experience on a subject related to
the phrase. The learner must be able to answer it naturally and
comfortably **using the phrase**, but the question must not steer them
toward it: it is an ordinary open question, and a good answer could
also be built without the phrase. The phrase should be one of several
natural ways to answer, not the only one the question points at.

- Do NOT ask the learner to explain, define, or give synonyms for the
  phrase, and do NOT mention the phrase (or a close variant of it) in
  the question.
- Do NOT word the question so that the phrase is the obvious or only
  fitting reply (no leading structure like "What do you do when you
  [run out of ...]?" that hands over the phrase's own scenario
  verbatim). Pick a broad enough subject that the phrase fits the
  answer without being implied by the question.
- The question must stand on its own as something you'd ask any
  person. Don't ground it in the transcript's specific content.
- Before settling on it, check both ways: (1) can you write a short,
  natural answer that uses the phrase? (2) would a learner who doesn't
  know the phrase still understand what is being asked and be able to
  answer some other way? If either is no, rewrite.

Example: for the phrase "pass away", a good question is "What funeral
rituals are special for the region you live in?" - the answer can
naturally use "pass away" ("when someone passes away, ...") without the
question hinting at it. Not "What does 'pass away' mean?", and not "How
do you talk about someone who has died?", which leads straight to the
phrase.

Then apply the **chunk-match method (§3)** to the question text,
translating into the **translation language**: translate the whole
question first, then group it into parts and pull each part's gloss
from that translation. Record each part as a `{word, translation}`
pair, in order - `word` is the part's original-language text (one or
more whitespace tokens, copied EXACTLY as they appear in the question),
`translation` is its non-empty gloss.

### 6.2 Write answering help ("helpers") for an A1-A2 learner

The primary users are **beginner (A1-A2)** learners. Helpers help them
build their own answer to the question, using the phrase. Write exactly
2, in this order:

1. **How the phrase connects to this question.** In the **translation
   language**, explain in 1-3 short sentences which angle of *this
   question* the phrase fits and when in an answer it becomes useful:
   what to think about or tell (a situation, an experience, a
   comparison), and what the phrase lets the learner say there. Name the
   phrase itself (in the original language) so the learner knows what
   to reach for. Do NOT give a ready-made example answer, and do NOT
   write any sentence that uses the phrase in a full answer - the
   learner has to build that themselves. Don't restate the question
   word for word.
2. **Grammar constructions for the answer.** In the **translation
   language**, name 2-3 simple grammatical constructions that will come
   in handy when answering *this kind* of question (e.g. past simple for
   telling about an experience, "I used to...", "It depends on...",
   "If I..., I would...", "because" + clause), each with a very short
   original-language example fragment. Choose constructions that fit the
   question type and the phrase, and keep them genuinely beginner-simple
   - no grammar jargon a beginner wouldn't already know. Where the
   phrase itself has a fixed pattern that a beginner would trip on
   (e.g. "+ verb-ing", a fixed preposition, which part changes in the
   past tense), mention that too, briefly.

Neither helper should restate or translate the question itself.

### 6.3 Write 3 translation-practice sentences

Write exactly 2 "forward" and 1 "backward" task:

- **Forward tasks (2)**: short, natural sentences in the **translation
  language**. Every sentence MUST contain the phrase's translation and
  use it meaningfully. Roughly 6-14 words each.
- **Backward task (1)**: a short, natural sentence in the **original
  language**. It MUST contain the key phrase itself and use it
  meaningfully. Roughly 6-14 words.

Make all 3 sentences different from each other in structure and
situation.

For every task, split its sentence into three parts with nothing added,
dropped, or overlapping:

- `before`: the text before the key phrase / its translation (may be
  empty)
- `target`: the phrase (or its translation) exactly as it appears in
  that sentence - inflected as the sentence requires, not necessarily
  the dictionary form
- `after`: the text after it (may be empty)

Concatenating `before + target + after` MUST reproduce the sentence
exactly, including every space and punctuation mark.

### 6.4 Gloss each task with the chunk-match method

For each task from §6.3, apply the **chunk-match method (§3)** to the
task's full sentence (`before + target + after`):

1. Translate the whole sentence first (this is the "other" language:
   for a backward task, into the translation language; for a forward
   task, into the original language).
2. The `target` span's gloss is whatever renders it in that full
   translation - pull it out as its own entry, marked `"isTarget":
   true`. Never re-split `target` into smaller parts, even if it's
   normally grouped into more than one word.
3. Group `before`'s tokens into parts and gloss each from the full
   translation, per §3. Do the same for `after`'s tokens.
4. Assemble one ordered `words` array: `before`'s parts, then the
   `target` part, then `after`'s parts - contiguous `index` starting at
   0. Exactly one entry has `isTarget: true`. No entry has an empty
   translation.

### 6.5 Self-check this phrase's package

Before moving to the next phrase (or to §7, if this was the last one),
silently verify, for this phrase only:

- Exactly one `question`, with exactly 2 `helpers` (an explanation of how
  the phrase connects to this question, with no ready-made example
  answer, then grammar constructions useful for answering) - neither restating the question.
- The question's `wordTranslations` parts, re-split per §2 and
  concatenated in order, reproduce the question's exact token
  sequence - and no entry's `translation` is empty.
- Exactly 3 `translationTasks`: 2 `"forward"`, 1 `"backward"`.
- Every task's `before + target + after` concatenates back to the exact
  sentence.
- Every task's `words` array has exactly one `isTarget: true` entry, no
  entry with an empty `translation`, and the rest of its entries, in
  order and re-split per §2, reproduce `before`'s token sequence then
  `after`'s token sequence with nothing missing.

Fix any violation before moving on. This phrase's shape (kept in memory
until §7 assembles the final combined JSON):

```json
{
  "id": "kp1",
  "phrase": "string",
  "translation": "string",
  "question": {
    "id": "q1",
    "text": "string",
    "wordTranslations": [
      {"index": 0, "word": "string, one or more words", "translation": "string, never empty"}
    ],
    "helpers": [
      {"id": "h1", "text": "string"}
    ]
  },
  "translationTasks": [
    {
      "id": "tt1",
      "direction": "backward",
      "before": "string",
      "target": "string",
      "after": "string",
      "words": [
        {"index": 0, "word": "string, one or more words", "translation": "string, never empty", "isTarget": false}
      ]
    }
  ]
}
```

## 7. Final output

Once every phrase from Gate 1's approved list has been built and
self-checked (§6), emit one final message: a short plain-language
summary of what was produced (how many phrases, etc.), then the full
combined JSON - every key phrase with its question, word translations,
helpers, and 3 fully word-split translation tasks - as ONE JSON object
in a single fenced code block, with no other text inside the block:

```json
{
  "originalLanguage": "string",
  "translationLanguage": "string",
  "keyPhrases": [
    { "...one approved Gate 2 package per phrase, unchanged from what was already approved...": "" }
  ]
}
```

---

## For engineers (optional reading)

This JSON's field names mirror PopKult Juicer's Go domain model
(`internal/domain/harvestingsession.go`, `translationtask.go`):
`keyPhrases[]` -> `KeyPhrase`, `question` -> `Question`,
`wordTranslations` -> `[]WordTranslation`, `helpers` -> `[]Helper`,
`translationTasks` -> `[]TranslationTask`, each task's `words` ->
`[]TaskWord`. All `id` fields here are throwaway placeholders - real
ids are assigned by Juicer's Go code, never trusted from a model.
`KeyPhrase.Words` (the lemmatized content-word list) is intentionally
not produced here - that's deterministic Go tokenization+lemmatization
(`internal/repository/lemma`), cheaper and more consistent computed in
Go from the returned `phrase` text than asked of a model.

**Known deviation from the production shape:** Juicer's real
`WordTranslation`/`TaskWord` are always exactly one Go-tokenized word
per entry (the mobile app highlights a question one word at a time as
the learner reads it). This skill deliberately groups tokens into
multi-word "parts" instead (§3), because forcing single-word glosses
produced empty/disconnected translations. If this JSON is ever imported
into the real app as-is, an entry whose `word` contains more than one
token would need to be re-split into individual `TaskWord`/
`WordTranslation` rows first (e.g. repeating the part's gloss across
its member tokens, or re-running §3's method at single-token
granularity) - this skill's output is a human-reviewed draft, not a
drop-in row format.
