"""Translation completeness and printf argument compatibility."""
import ast
import re
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def catalog(locale):
    return {ast.literal_eval(k):ast.literal_eval(v) for k,v in re.findall(r'^msgid (".+")\nmsgstr (".*")$', (ROOT/'locales'/f'{locale}.po').read_text(), re.M)}

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

    def test_script_translation_calls(self):
        translations=catalog('it')
        literal=r'("(?:[^"\\]|\\.)*")'
        for path in (ROOT/'scripts').glob('*.gd'):
            # Explicit translation calls and local/wire message entry points.
            source=path.read_text()
            for raw in re.findall(r'(?:\btr|TranslationServer.translate|CatanI18n.message|CatanI18n.term|notice.emit)\('+literal,source):
                key=ast.literal_eval(raw)
                if key:self.assertIn(key,translations,f'{path.name}: {key}')

    def test_data_driven_ui_text(self):
        translations=catalog('it')
        settings=(ROOT/'scripts/settings_menu.gd').read_text()
        options=ast.literal_eval(settings.split('const OPTIONS=',1)[1].split('\nvar preferences',1)[0])
        keys=[]
        for spec in options:
            keys.extend([spec[0],spec[3],spec[6],spec[7]])
            if spec[4]=='option':keys.extend(spec[5])
        for filename,fields in [('soundtrack.gd',['title','mood']),('tutorial.gd',['title','body'])]:
            source=(ROOT/'scripts'/filename).read_text()
            for field in fields:
                keys.extend(ast.literal_eval(raw) for raw in re.findall(r'"'+field+r'":("(?:[^"\\]|\\.)*")',source))
        cards=(ROOT/'scripts/dev_card.gd').read_text()
        for constant in ['TITLES','EFFECTS','TIPS']:
            keys.extend(ast.literal_eval(re.search(r'^const '+constant+r'=([^\n]+)',cards,re.M)[1]))
        cosmetics=(ROOT/'scripts/cosmetics_menu.gd').read_text()
        swatches=ast.literal_eval(cosmetics.split('const COLOR_SWATCHES=',1)[1].split('\nvar color_buttons',1)[0])
        keys.extend(swatch[0] for swatch in swatches)
        for key in keys:self.assertIn(key,translations,key)

if __name__=='__main__':unittest.main()
