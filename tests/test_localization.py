"""Translation completeness and printf argument compatibility."""
import ast
import re
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def catalog(locale):
    return {ast.literal_eval(k):ast.literal_eval(v) for k,v in re.findall(r'^msgid (".+")\nmsgstr (".+")$', (ROOT/'locales'/f'{locale}.po').read_text(), re.M)}

class LocalizationTests(unittest.TestCase):
    def test_catalogs_and_placeholders(self):
        en,it=catalog('en'),catalog('it')
        self.assertEqual(en.keys(),it.keys())
        for key in en:
            self.assertTrue(it[key].strip(),key)
            self.assertEqual(re.findall(r'%(?:\d+\$)?[\d.]*[sdif]',key),re.findall(r'%(?:\d+\$)?[\d.]*[sdif]',it[key]),key)

    def test_scene_text_is_translated(self):
        translations=catalog('it')
        unchanged={'1 / 10','1 / 6','CATAN','T I D E S  &  T I M B E R','Voyager','×'}
        for path in (ROOT/'scenes/ui').glob('*.tscn'):
            for literal in re.findall(r'^(?:text|tooltip_text|placeholder_text) = ("(?:[^"\\]|\\.)*")',path.read_text(),re.M):
                text=ast.literal_eval(literal)
                if text and text not in unchanged:self.assertIn(text,translations,str(path))

    def test_rules_and_tutorial_are_translated(self):
        translations=catalog('it')
        rules=(ROOT/'scripts/rules.gd').read_text()
        literals=re.findall(r'(?:return |CatanI18n.message\()((?:"(?:[^"\\]|\\.)*"))',rules)
        literals+=re.findall(r'"(?:road|settlement|city|buy_card)":("To [^"]+")',rules)
        tutorial=(ROOT/'scripts/tutorial.gd').read_text()
        literals+=re.findall(r'"(?:title|body)":("(?:[^"\\]|\\.)*")',tutorial)
        for literal in literals:
            text=ast.literal_eval(literal)
            if text:self.assertTrue(text in translations,text)

if __name__=='__main__':unittest.main()
