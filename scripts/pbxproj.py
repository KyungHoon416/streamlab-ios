"""Read the OpenStep property-list subset used by our Xcode project files."""
import json
import re


def loads(source):
    tokens = re.findall(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,"/]+(?:/[^\s{}()=;,"/]*)*', source)
    tokens = [t for t in tokens if not t.startswith(('//', '/*'))]
    position = 0

    def take(expected=None):
        nonlocal position
        if position >= len(tokens):
            raise ValueError('Unexpected end of project')
        token = tokens[position]
        position += 1
        if expected is not None and token != expected:
            raise ValueError(f'Expected {expected}, got {token}')
        return token

    def value():
        token = take()
        if token == '{':
            result = {}
            while tokens[position] != '}':
                key = value()
                take('=')
                result[key] = value()
                take(';')
            take('}')
            return result
        if token == '(':
            result = []
            while tokens[position] != ')':
                result.append(value())
                if tokens[position] != ')':
                    take(',')
            take(')')
            return result
        return json.loads(token) if token.startswith('"') else token

    result = value()
    if position != len(tokens):
        raise ValueError('Unexpected trailing project tokens')
    return result


def source_paths(project):
    """Resolve file references through PBXGroup paths, not display names."""
    objects = project['objects']
    paths = {}

    def visit(identifier, parent):
        obj = objects[identifier]
        tree = obj.get('sourceTree', '<group>')
        if tree not in ('<group>', 'SOURCE_ROOT'):
            return
        base = '' if tree == 'SOURCE_ROOT' else parent
        path = '/'.join(p for p in (base, obj.get('path', '')) if p)
        if obj['isa'] == 'PBXFileReference':
            paths[identifier] = path
        for child in obj.get('children', []):
            visit(child, path)

    visit(objects[project['rootObject']]['mainGroup'], '')
    # Require membership in a Sources build phase, not just a file reference.
    return {paths.get(objects[build]['fileRef'])
            for obj in objects.values() if obj['isa'] == 'PBXSourcesBuildPhase'
            for build in obj.get('files', []) if 'fileRef' in objects[build]}
