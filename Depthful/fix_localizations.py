#!/usr/bin/env python3
import json
import sys

def fix_localizations(file_path):
    """Fix missing English localizations in Localizable.xcstrings file"""
    
    # Read the file
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    if 'strings' not in data:
        print("Error: No 'strings' section found in file")
        return
    
    missing_en_count = 0
    fixed_count = 0
    
    # Process each string entry
    for string_key, string_data in data['strings'].items():
        # Skip entries that shouldn't be translated
        if string_data.get('shouldTranslate') == False:
            continue
            
        # Check if this entry has localizations
        if 'localizations' not in string_data:
            continue
            
        localizations = string_data['localizations']
        
        # Check if English ("en") is missing but other languages exist
        if 'en' not in localizations and len(localizations) > 0:
            missing_en_count += 1
            print(f"Missing EN for key: '{string_key}'")
            
            # Add English localization using the string key as the value
            localizations['en'] = {
                "stringUnit": {
                    "state": "translated",
                    "value": string_key
                }
            }
            fixed_count += 1
            
        # Ensure all existing localizations have "state": "translated"
        for lang_code, localization in localizations.items():
            if 'stringUnit' in localization and 'state' not in localization['stringUnit']:
                localization['stringUnit']['state'] = 'translated'
            elif 'stringUnit' in localization and localization['stringUnit']['state'] != 'translated':
                localization['stringUnit']['state'] = 'translated'
    
    print(f"Found {missing_en_count} entries missing English localization")
    print(f"Fixed {fixed_count} entries")
    
    # Write back the fixed file
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"Successfully updated {file_path}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
        fix_localizations(file_path)
    else:
        print("Please provide the path to Localizable.xcstrings as an argument")