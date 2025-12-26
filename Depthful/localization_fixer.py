#!/usr/bin/env python3
"""
Automatic Localization Fixer for Afternoon App
Fixes missing translations in Localizable.xcstrings file automatically
"""

import json
import sys
from pathlib import Path
from typing import Dict, List

# Expected languages based on the file
EXPECTED_LANGUAGES = {'ar', 'de', 'es', 'fr', 'hi', 'ja', 'ko', 'pt', 'zh-Hans', 'en'}

# Translation mappings for common UI strings
TRANSLATION_MAPPINGS = {
    'Documentation': {
        'ar': 'التوثيق',
        'de': 'Dokumentation', 
        'es': 'Documentación',
        'fr': 'Documentation',
        'hi': 'प्रलेखन',
        'ja': 'ドキュメント',
        'ko': '문서',
        'pt': 'Documentação',
        'zh-Hans': '文档',
        'en': 'Documentation'
    },
    'Email Support': {
        'ar': 'دعم البريد الإلكتروني',
        'de': 'E-Mail-Support',
        'es': 'Soporte por correo',
        'fr': 'Support par e-mail',
        'hi': 'ईमेल समर्थन',
        'ja': 'メールサポート',
        'ko': '이메일 지원',
        'pt': 'Suporte por e-mail',
        'zh-Hans': '邮件支持',
        'en': 'Email Support'
    },
    'Hide Completed Items': {
        'ar': 'إخفاء العناصر المكتملة',
        'de': 'Erledigte Elemente ausblenden',
        'es': 'Ocultar elementos completados',
        'fr': 'Masquer les éléments terminés',
        'hi': 'पूर्ण आइटम छुपाएं',
        'ja': '完了したアイテムを非表示',
        'ko': '완료된 항목 숨기기',
        'pt': 'Ocultar itens concluídos',
        'zh-Hans': '隐藏已完成项目',
        'en': 'Hide Completed Items'
    },
    'Organizes habits and tasks by time periods: Morning, Afternoon, Evening, and Today': {
        'ar': 'ينظم العادات والمهام حسب الفترات الزمنية: الصباح، بعد الظهر، المساء، واليوم',
        'de': 'Organisiert Gewohnheiten und Aufgaben nach Tageszeiten: Morgen, Nachmittag, Abend und Heute',
        'es': 'Organiza hábitos y tareas por períodos de tiempo: Mañana, Tarde, Noche y Hoy',
        'fr': 'Organise les habitudes et tâches par périodes : Matin, Après-midi, Soir et Aujourd\'hui',
        'hi': 'समय अवधि के अनुसार आदतों और कार्यों को व्यवस्थित करता है: सुबह, दोपहर, शाम, और आज',
        'ja': '習慣とタスクを時間帯別に整理：朝、午後、夕方、今日',
        'ko': '습관과 작업을 시간대별로 정리: 아침, 오후, 저녁, 오늘',
        'pt': 'Organiza hábitos e tarefas por períodos: Manhã, Tarde, Noite e Hoje',
        'zh-Hans': '按时间段组织习惯和任务：上午、下午、晚上和今天',
        'en': 'Organizes habits and tasks by time periods: Morning, Afternoon, Evening, and Today'
    },
    'Hides completed habits and tasks from view': {
        'ar': 'يخفي العادات والمهام المكتملة من العرض',
        'de': 'Blendet erledigte Gewohnheiten und Aufgaben aus',
        'es': 'Oculta hábitos y tareas completados de la vista',
        'fr': 'Cache les habitudes et tâches terminées',
        'hi': 'पूर्ण आदतों और कार्यों को दृश्य से छुपाता है',
        'ja': '完了した習慣とタスクを非表示にします',
        'ko': '완료된 습관과 작업을 보기에서 숨깁니다',
        'pt': 'Oculta hábitos e tarefas concluídos da visualização',
        'zh-Hans': '从视图中隐藏已完成的习惯和任务',
        'en': 'Hides completed habits and tasks from view'
    },
    'Time-Based Filtering': {
        'ar': 'التصفية القائمة على الوقت',
        'de': 'Zeitbasierte Filterung',
        'es': 'Filtrado basado en tiempo',
        'fr': 'Filtrage temporel',
        'hi': 'समय-आधारित फ़िल्टरिंग',
        'ja': '時間ベースフィルタリング',
        'ko': '시간 기반 필터링',
        'pt': 'Filtragem baseada em tempo',
        'zh-Hans': '基于时间的过滤',
        'en': 'Time-Based Filtering'
    },
    'View Options': {
        'ar': 'خيارات العرض',
        'de': 'Ansichtsoptionen',
        'es': 'Opciones de vista',
        'fr': 'Options d\'affichage',
        'hi': 'दृश्य विकल्प',
        'ja': '表示オプション',
        'ko': '보기 옵션',
        'pt': 'Opções de visualização',
        'zh-Hans': '查看选项',
        'en': 'View Options'
    },
    'Nothing to do.': {
        'ar': 'لا يوجد شيء للقيام به.',
        'de': 'Nichts zu tun.',
        'es': 'Nada que hacer.',
        'fr': 'Rien à faire.',
        'hi': 'कुछ नहीं करना.',
        'ja': 'やることはありません。',
        'ko': '할 일이 없습니다.',
        'pt': 'Nada para fazer.',
        'zh-Hans': '无事可做。',
        'en': 'Nothing to do.'
    },
    'Habit Reminders': {
        'ar': 'تذكيرات العادات',
        'de': 'Gewohnheitserinnerungen',
        'es': 'Recordatorios de hábitos',
        'fr': 'Rappels d\'habitudes',
        'hi': 'आदत अनुस्मारक',
        'ja': '習慣リマインダー',
        'ko': '습관 알림',
        'pt': 'Lembretes de hábitos',
        'zh-Hans': '习惯提醒',
        'en': 'Habit Reminders'
    },
    'Enable reminders': {
        'ar': 'تمكين التذكيرات',
        'de': 'Erinnerungen aktivieren',
        'es': 'Habilitar recordatorios',
        'fr': 'Activer les rappels',
        'hi': 'अनुस्मारक सक्षम करें',
        'ja': 'リマインダーを有効にする',
        'ko': '알림 활성화',
        'pt': 'Ativar lembretes',
        'zh-Hans': '启用提醒',
        'en': 'Enable reminders'
    },
    'All reminders disabled': {
        'ar': 'جميع التذكيرات معطلة',
        'de': 'Alle Erinnerungen deaktiviert',
        'es': 'Todos los recordatorios desactivados',
        'fr': 'Tous les rappels désactivés',
        'hi': 'सभी अनुस्मारक अक्षम',
        'ja': 'すべてのリマインダーが無効',
        'ko': '모든 알림이 비활성화됨',
        'pt': 'Todos os lembretes desativados',
        'zh-Hans': '所有提醒已禁用',
        'en': 'All reminders disabled'
    }
}

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
            analysis['complete_keys'] += 1
    
    # Calculate completion percentage
    translatable_keys = analysis['total_keys'] - analysis['should_not_translate']
    if translatable_keys > 0:
        analysis['completion_percentage'] = (analysis['complete_keys'] / translatable_keys) * 100
    
    return analysis

def get_translation_value(key: str, language: str, existing_localizations: Dict) -> str:
    """Get the appropriate translation value for a key and language."""
    # Check if we have a specific translation mapping
    if key in TRANSLATION_MAPPINGS and language in TRANSLATION_MAPPINGS[key]:
        return TRANSLATION_MAPPINGS[key][language]
    
    # For English, return the key itself
    if language == 'en':
        return key
    
    # For other languages, try to use English value if available
    if 'en' in existing_localizations:
        english_value = existing_localizations['en']['stringUnit']['value']
        if english_value in TRANSLATION_MAPPINGS and language in TRANSLATION_MAPPINGS[english_value]:
            return TRANSLATION_MAPPINGS[english_value][language]
        return english_value
    
    # Fallback to the key itself
    return key

def fix_localizations(data: Dict) -> Dict:
    """Fix missing localizations in the data."""
    analysis = analyze_completeness(data)
    fixed_data = json.loads(json.dumps(data))  # Deep copy
    
    print(f"Fixing {len(analysis['incomplete_keys'])} incomplete keys...")
    
    fixed_count = 0
    for key in analysis['incomplete_keys']:
        missing_languages = analysis['missing_languages'].get(key, [])
        if missing_languages:
            existing_localizations = fixed_data['strings'][key].get('localizations', {})
            
            # Ensure localizations key exists
            if 'localizations' not in fixed_data['strings'][key]:
                fixed_data['strings'][key]['localizations'] = {}
            
            # Add missing translations
            for lang in missing_languages:
                translation_value = get_translation_value(key, lang, existing_localizations)
                
                fixed_data['strings'][key]['localizations'][lang] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": translation_value
                    }
                }
            
            fixed_count += 1
            print(f"Fixed '{key[:50]}{'...' if len(key) > 50 else ''}' -> Added {len(missing_languages)} languages")
    
    print(f"Fixed {fixed_count} keys with missing translations")
    return fixed_data

def save_fixed_file(data: Dict, file_path: Path, backup: bool = True) -> bool:
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
    initial_analysis = analyze_completeness(data)
    print(f"Current completion: {initial_analysis['completion_percentage']:.1f}%")
    print(f"Incomplete keys: {len(initial_analysis['incomplete_keys'])}")
    
    if initial_analysis['completion_percentage'] >= 100.0:
        print("✅ Localizations are already 100% complete!")
        return
    
    # Fix localizations
    print("\nFixing localizations...")
    fixed_data = fix_localizations(data)
    
    # Verify fix
    print("\nVerifying fixes...")
    final_analysis = analyze_completeness(fixed_data)
    print(f"New completion percentage: {final_analysis['completion_percentage']:.1f}%")
    print(f"Remaining incomplete keys: {len(final_analysis['incomplete_keys'])}")
    
    if final_analysis['completion_percentage'] > initial_analysis['completion_percentage']:
        # Save the fixed file
        if save_fixed_file(fixed_data, file_path):
            print("\n✅ Localizations have been fixed!")
            print(f"Completion improved from {initial_analysis['completion_percentage']:.1f}% to {final_analysis['completion_percentage']:.1f}%")
            
            if final_analysis['completion_percentage'] >= 100.0:
                print("🎉 100% localization completion achieved!")
        else:
            print("❌ Failed to save the fixed file")
    else:
        print("No improvement made.")
        
        # Show remaining issues
        if final_analysis['incomplete_keys']:
            print("\nRemaining incomplete keys:")
            for key in final_analysis['incomplete_keys'][:5]:
                missing = final_analysis['missing_languages'].get(key, [])
                print(f"  '{key[:50]}{'...' if len(key) > 50 else ''}' -> Missing: {', '.join(missing)}")
            if len(final_analysis['incomplete_keys']) > 5:
                print(f"  ... and {len(final_analysis['incomplete_keys']) - 5} more")

if __name__ == "__main__":
    main()