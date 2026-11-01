#!/usr/bin/env python3
"""Validate harvester JSON shape, 2+1 tasks and ordered token coverage."""
import argparse
from collections import Counter
import json
from pathlib import Path
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def entries(words, label):
    require(isinstance(words, list) and words, f'{label}: expected nonempty array')
    for i, word in enumerate(words):
        require(isinstance(word, dict), f'{label}[{i}]: expected object')
        require(type(word.get('index')) is int and word['index'] == i,
                f'{label}[{i}]: indices must be contiguous from zero')
        require(nonempty(word.get('word')), f'{label}[{i}]: empty word')
        require(nonempty(word.get('translation')), f'{label}[{i}]: empty gloss')
    return [token for word in words for token in word['word'].split()]


def validate(doc):
    require(isinstance(doc, dict), 'Expected one JSON object')
    for key in ('originalLanguage', 'translationLanguage'):
        require(nonempty(doc.get(key)), f'Missing {key}')
    phrases = doc.get('keyPhrases')
    require(isinstance(phrases, list) and phrases, 'Expected nonempty keyPhrases')
    for i, phrase in enumerate(phrases):
        label = f'keyPhrases[{i}]'
        require(isinstance(phrase, dict), f'{label}: expected object')
        for key in ('phrase', 'translation'):
            require(nonempty(phrase.get(key)), f'{label}: missing {key}')
        question = phrase.get('question')
        require(isinstance(question, dict) and nonempty(question.get('text')),
                f'{label}: missing question text')
        tokens = entries(question.get('wordTranslations'), label + '.question.wordTranslations')
        require(tokens == question['text'].split(), f'{label}: question token coverage differs')
        helpers = question.get('helpers')
        require(isinstance(helpers, list) and len(helpers) == 2,
                f'{label}: expected exactly two helpers')
        require(all(isinstance(h, dict) and nonempty(h.get('text')) for h in helpers),
                f'{label}: helpers must contain text')
        tasks = phrase.get('translationTasks')
        require(isinstance(tasks, list) and len(tasks) == 3,
                f'{label}: expected exactly three tasks (2 forward + 1 backward)')
        require(all(isinstance(t, dict) for t in tasks), f'{label}: task must be an object')
        directions = [t.get('direction') for t in tasks]
        require(all(isinstance(d, str) for d in directions), f'{label}: missing task direction')
        require(Counter(directions) == {'forward': 2, 'backward': 1},
                f'{label}: expected 2 forward + 1 backward')
        for j, task in enumerate(tasks):
            prefix = f'{label}.translationTasks[{j}]'
            require(all(isinstance(task.get(k), str) for k in ('before', 'target', 'after')),
                    f'{prefix}: before/target/after must be strings')
            require(nonempty(task['target']), f'{prefix}: empty target')
            words = task.get('words')
            entries(words, prefix + '.words')
            require(all(type(w.get('isTarget')) is bool for w in words),
                    f'{prefix}: isTarget must be boolean')
            targets = [n for n, w in enumerate(words) if w['isTarget']]
            require(len(targets) == 1, f'{prefix}: expected exactly one target entry')
            n = targets[0]
            require(words[n]['word'] == task['target'], f'{prefix}: target must stay whole')
            before = [t for w in words[:n] for t in w['word'].split()]
            after = [t for w in words[n + 1:] for t in w['word'].split()]
            require(before == task['before'].split(), f'{prefix}: before token coverage differs')
            require(after == task['after'].split(), f'{prefix}: after token coverage differs')
    return len(phrases)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('json_file', type=Path)
    args = parser.parse_args()
    try:
        count = validate(json.loads(args.json_file.read_text()))
    except (OSError, ValueError) as exc:
        print(f'Invalid content: {exc}', file=sys.stderr)
        return 1
    print(f'OK: {count} phrases, each with 2 forward + 1 backward tasks')
    return 0


if __name__ == '__main__':
    sys.exit(main())
