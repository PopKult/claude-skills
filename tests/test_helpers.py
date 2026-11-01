import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / 'skills/juicer-harvest-content/scripts/validate-content.py'
spec = importlib.util.spec_from_file_location('harvest_validator', VALIDATOR)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class InstallationTest(unittest.TestCase):
    def install(self, target):
        return subprocess.run(
            [sys.executable, str(ROOT / 'scripts/install-skills.py'), '--target', str(target)],
            capture_output=True, text=True,
        )

    def test_install_twice_preserves_resolvable_resources(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'skills'
            for _ in range(2):
                result = self.install(target)
                self.assertEqual(result.returncode, 0, result.stderr)
            skills = sorted((ROOT / 'skills').iterdir())
            self.assertEqual(len(list(target.iterdir())), len(skills))
            for skill in skills:
                self.assertEqual((target / skill.name).resolve(), skill)
                self.assertTrue((target / skill.name / 'SKILL.md').is_file())
            entrypoint = (target / 'add-feature/SKILL.md').resolve()
            self.assertTrue((entrypoint.parent / '../../references/development-workflow.md').is_file())
            result = subprocess.run(
                [sys.executable, str(target / 'juicer-harvest-content/scripts/validate-content.py'), '--help'],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_conflict_preflight_does_not_partially_install(self):
        for broken_link in (False, True):
            with self.subTest(broken_link=broken_link), tempfile.TemporaryDirectory() as directory:
                target = Path(directory)
                conflict = target / 'init-service'
                if broken_link:
                    conflict.symlink_to(target / 'missing')
                else:
                    conflict.write_text('keep me')
                result = self.install(target)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual([p.name for p in target.iterdir()], ['init-service'])
                if not broken_link:
                    self.assertEqual(conflict.read_text(), 'keep me')


def content():
    def task(direction):
        return {
            'direction': direction, 'before': 'We ', 'target': 'take a break', 'after': '.',
            'words': [
                {'index': 0, 'word': 'We', 'translation': 'мы', 'isTarget': False},
                {'index': 1, 'word': 'take a break', 'translation': 'делаем перерыв', 'isTarget': True},
                {'index': 2, 'word': '.', 'translation': '.', 'isTarget': False},
            ],
        }
    # Structural fixture only: language quality is deliberately outside the validator.
    return {
        'originalLanguage': 'EN', 'translationLanguage': 'RU',
        'keyPhrases': [{
            'phrase': 'take a break', 'translation': 'сделать перерыв',
            'question': {
                'text': 'How are you?',
                'wordTranslations': [
                    {'index': 0, 'word': 'How are', 'translation': 'как'},
                    {'index': 1, 'word': 'you?', 'translation': 'ты?'},
                ],
                'helpers': [{'text': 'First helper'}, {'text': 'Second helper'}],
            },
            'translationTasks': [task('forward'), task('forward'), task('backward')],
        }],
    }


class ContentValidationTest(unittest.TestCase):
    def test_accepts_chunks_and_attached_punctuation(self):
        self.assertEqual(validator.validate(content()), 1)

    def test_rejects_wrong_task_count_direction_coverage_and_target(self):
        mutations = [
            lambda p: p['translationTasks'].pop(),
            lambda p: p['translationTasks'][0].update(direction='backward'),
            lambda p: p['question']['wordTranslations'][0].update(word='How'),
            lambda p: p['translationTasks'][0]['words'][0].update(index=4),
            lambda p: p['translationTasks'][0]['words'][0].update(translation=''),
            lambda p: p['translationTasks'][0]['words'][0].update(isTarget=True),
            lambda p: p['translationTasks'][0]['words'][1].update(word='take'),
            lambda p: p['translationTasks'][0].update(before='They '),
            lambda p: p['translationTasks'][0].update(after='today.'),
        ]
        for change in mutations:
            with self.subTest(change=change):
                doc = copy.deepcopy(content())
                change(doc['keyPhrases'][0])
                with self.assertRaises(ValueError):
                    validator.validate(doc)

    def test_cli_reports_invalid_json_and_accepts_valid_document(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'content.json'
            for text, expected in [('not json', 1), ('[]', 1), (json.dumps(content()), 0)]:
                path.write_text(text)
                result = subprocess.run([sys.executable, str(VALIDATOR), str(path)],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stderr)


if __name__ == '__main__':
    unittest.main()
