#!/usr/bin/env python3
"""
Quick Localization Status Checker for Afternoon App
Shows current localization completion status
"""

import json
from pathlib import Path

def check_localization_status():
    """Check and display localization status."""
    file_path = Path(__file__).parent / "Localizable.xcstrings"
    
    if not file_path.exists():
        print("❌ Localizable.xcstrings file not found")
        return
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"❌ Error loading file: {e}")
        return
    
    strings = data.get('strings', {})
    expected_languages = {'ar', 'de', 'es', 'fr', 'hi', 'ja', 'ko', 'pt', 'zh-Hans', 'en'}
    
    total_keys = len(strings)
    should_not_translate = 0
    complete_keys = 0
    
    for key, value in strings.items():
        if value.get('shouldTranslate') == False:
            should_not_translate += 1
            continue
        
        localizations = value.get('localizations', {})
        available_languages = set(localizations.keys())
        
        if expected_languages.issubset(available_languages):
            complete_keys += 1
    
    translatable_keys = total_keys - should_not_translate
    completion_percentage = (complete_keys / translatable_keys * 100) if translatable_keys > 0 else 0
    
    print("📱 Afternoon App - Localization Status")
    print("=" * 40)
    print(f"Total strings: {total_keys}")
    print(f"Translatable: {translatable_keys}")
    print(f"Complete: {complete_keys}")
    print(f"Completion: {completion_percentage:.1f}%")
    print()
    
    if completion_percentage >= 100.0:
        print("✅ 100% localization complete! 🎉")
    elif completion_percentage >= 95.0:
        print("🟡 Almost there! Just a few more strings to go.")
    elif completion_percentage >= 90.0:
        print("🟠 Good progress! Getting close to completion.")
    else:
        print("🔴 Needs work. Run localization_fixer.py to improve.")
    
    print()
    print("Supported languages:")
    for lang_code in sorted(expected_languages):
        lang_names = {
            'ar': '🇸🇦 Arabic',
            'de': '🇩🇪 German',
            'es': '🇪🇸 Spanish', 
            'fr': '🇫🇷 French',
            'hi': '🇮🇳 Hindi',
            'ja': '🇯🇵 Japanese',
            'ko': '🇰🇷 Korean',
            'pt': '🇵🇹 Portuguese',
            'zh-Hans': '🇨🇳 Chinese (Simplified)',
            'en': '🇺🇸 English'
        }
        print(f"  {lang_names.get(lang_code, lang_code)}")

if __name__ == "__main__":
    check_localization_status()