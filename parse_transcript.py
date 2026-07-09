import json

with open('/Users/ahnaguib/.gemini/antigravity/brain/37b245e7-cb2d-4534-91c0-b2844ae85721/.system_generated/logs/transcript.jsonl', 'r') as f:
    for line in f:
        try:
            data = json.loads(line)
            if data.get('type') == 'RUN_COMMAND' and 'flutter_launcher_icons' in str(data.get('content', '')):
                print("FOUND COMMAND:")
                print(data['content'])
            if data.get('type') == 'REPLACE_FILE_CONTENT' and 'pubspec.yaml' in str(data.get('content', '')):
                print("FOUND REPLACE IN PUBSPEC:")
                print(data['content'])
            if data.get('type') == 'USER_INPUT' and 'icon' in str(data.get('content', '')).lower():
                print("USER MENTIONED ICON:", data['content'])
        except Exception:
            pass
