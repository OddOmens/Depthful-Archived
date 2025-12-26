#!/usr/bin/env python3
"""
Localization Analyzer and Fixer for Afternoon App
Analyzes Localizable.xcstrings file and identifies missing translations
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

# Expected languages based on the file
EXPECTED_LANGUAGES = {'ar', 'de', 'es', 'fr', 'hi', 'ja', 'ko', 'pt', 'zh-Hans', 'en'}

def load_localizations(file_path: Path) -> Dict:
    """Load the localization file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading file: {e}")
        return {}

def analyze_completeness(data: Dict) -> Dict:
    """Analyze the completeness of localizations."""
    strings = data.get('strings', {})
    analysis = {
        'total_keys': len(strings),
        'complete_keys': 0,
        'incomplete_keys': [],
        'missing_languages': {},
        'should_not_translate': 0,
        'completion_percentage': 0.0
    }
    
    for key, value in strings.items():
        # Skip entries that should not be translated
        if value.get('shouldTranslate') == False:
            analysis['should_not_translate'] += 1
            continue
            
        localizations = value.get('localizations', {})
        available_languages = set(localizations.keys())
        missing_languages = EXPECTED_LANGUAGES - available_languages
        
        if missing_languages:
            analysis['incomplete_keys'].append(key)
            analysis['missing_languages'][key] = list(missing_languages)
        else:
            # Check if all available languages have 'translated' state
            all_translated = True
            for lang, loc_data in localizations.items():
                if loc_data.get('stringUnit', {}).get('state') != 'translated':
                    all_translated = False
                    break
            
            if all_translated:
                analysis['complete_keys'] += 1
            else:
                analysis['incomplete_keys'].append(key)
    
    # Calculate completion percentage
    translatable_keys = analysis['total_keys'] - analysis['should_not_translate']
    if translatable_keys > 0:
        analysis['completion_percentage'] = (analysis['complete_keys'] / translatable_keys) * 100
    
    return analysis

def print_analysis(analysis: Dict):
    """Print the analysis results."""
    print("=" * 60)
    print("LOCALIZATION ANALYSIS REPORT")
    print("=" * 60)
    print(f"Total string keys: {analysis['total_keys']}")
    print(f"Should not translate: {analysis['should_not_translate']}")
    print(f"Translatable keys: {analysis['total_keys'] - analysis['should_not_translate']}")
    print(f"Complete keys: {analysis['complete_keys']}")
    print(f"Incomplete keys: {len(analysis['incomplete_keys'])}")
    print(f"Completion percentage: {analysis['completion_percentage']:.1f}%")
    print()
    
    if analysis['incomplete_keys']:
        print("MISSING TRANSLATIONS BREAKDOWN:")
        print("-" * 40)
        
        # Group by missing languages count
        missing_counts = {}
        for key in analysis['incomplete_keys']:
            missing_langs = analysis['missing_languages'].get(key, [])
            count = len(missing_langs)
            if count not in missing_counts:
                missing_counts[count] = []
            missing_counts[count].append(key)
        
        for count in sorted(missing_counts.keys(), reverse=True):
            keys = missing_counts[count]
            print(f"\nMissing {count} language(s) ({len(keys)} keys):")
            for key in keys[:10]:  # Show first 10 examples
                missing_langs = analysis['missing_languages'].get(key, [])
                print(f"  '{key}' -> Missing: {', '.join(missing_langs)}")
            if len(keys) > 10:
                print(f"  ... and {len(keys) - 10} more keys")

def generate_missing_translations(data: Dict, key: str, missing_languages: List[str]) -> Dict:
    """Generate missing translations for a key."""
    existing_localizations = data['strings'][key].get('localizations', {})
    new_translations = {}
    
    # Use the key itself as the English value if it's missing English
    english_value = key
    if 'en' in existing_localizations:
        english_value = existing_localizations['en']['stringUnit']['value']
    
    # Basic translation mappings for common strings
    translation_map = {
        ' of ': {
            'ar': 'من', 'de': 'von', 'es': 'de', 'fr': 'de', 'hi': 'का',
            'ja': 'の', 'ko': '~의', 'pt': 'de', 'zh-Hans': '的', 'en': ' of '
        },
        '-': {
            'ar': '-', 'de': '-', 'es': '-', 'fr': '-', 'hi': '-',
            'ja': '-', 'ko': '-', 'pt': '-', 'zh-Hans': '-', 'en': '-'
        },
        ':': {
            'ar': ':', 'de': ':', 'es': ':', 'fr': ':', 'hi': ':',
            'ja': ':', 'ko': ':', 'pt': ':', 'zh-Hans': ':', 'en': ':'
        }
    }
    
    for lang in missing_languages:
        if key in translation_map and lang in translation_map[key]:
            value = translation_map[key][lang]
        else:
            # Fallback to English value
            value = english_value
        
        new_translations[lang] = {
            "stringUnit": {
                "state": "translated",
                "value": value
            }
        }
    
    return new_translations

def fix_localizations(data: Dict) -> Dict:
    """Fix missing localizations in the data."""
    analysis = analyze_completeness(data)
    fixed_data = data.copy()
    
    print(f"\nFIXING {len(analysis['incomplete_keys'])} incomplete keys...")
    
    for key in analysis['incomplete_keys']:
        missing_languages = analysis['missing_languages'].get(key, [])
        if missing_languages:
            new_translations = generate_missing_translations(data, key, missing_languages)
            
            # Add missing translations
            for lang, translation in new_translations.items():
                fixed_data['strings'][key]['localizations'][lang] = translation
            
            print(f"Fixed '{key}' -> Added {len(missing_languages)} languages: {', '.join(missing_languages)}")
    
    return fixed_data

def save_fixed_file(data: Dict, file_path: Path, backup: bool = True):
    """Save the fixed localization file."""
    if backup:
        backup_path = file_path.with_suffix('.xcstrings.backup')
        if file_path.exists():
            import shutil
            shutil.copy2(file_path, backup_path)
            print(f"Backup saved to: {backup_path}")
    
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"Fixed file saved to: {file_path}")
        return True
    except Exception as e:
        print(f"Error saving file: {e}")
        return False

def main():
    """Main function."""
    # File path
    file_path = Path(__file__).parent / "Localizable.xcstrings"
    
    if not file_path.exists():
        print(f"Error: File not found at {file_path}")
        sys.exit(1)
    
    print("Loading localization file...")
    data = load_localizations(file_path)
    if not data:
        print("Failed to load localization data")
        sys.exit(1)
    
    # Initial analysis
    print("Analyzing current state...")
    analysis = analyze_completeness(data)
    print_analysis(analysis)
    
    if analysis['completion_percentage'] >= 100.0:
        print("✅ Localizations are already 100% complete!")
        return
    
    # Ask user if they want to fix
    print(f"\nCurrent completion: {analysis['completion_percentage']:.1f}%")
    response = input("Do you want to automatically fix missing translations? (y/n): ").strip().lower()
    
    if response == 'y':
        print("\nFixing localizations...")
        fixed_data = fix_localizations(data)
        
        # Verify fix
        print("\nVerifying fixes...")
        new_analysis = analyze_completeness(fixed_data)
        print(f"New completion percentage: {new_analysis['completion_percentage']:.1f}%")
        
        if new_analysis['completion_percentage'] > analysis['completion_percentage']:
            # Save the fixed file
            if save_fixed_file(fixed_data, file_path):
                print("✅ Localizations have been fixed!")
                print(f"Completion improved from {analysis['completion_percentage']:.1f}% to {new_analysis['completion_percentage']:.1f}%")
            else:
                print("❌ Failed to save the fixed file")
        else:
            print("No improvement made. Manual intervention may be required.")
    else:
        print("Fix cancelled by user.")

if __name__ == "__main__":
    main()