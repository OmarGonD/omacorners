"""Execute the QML settings logic against the installed-plugin shell facade."""
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ScopedSettingsTests(unittest.TestCase):
    def test_read_and_save_with_scoped_shell(self):
        qml = (ROOT / 'Omacorners.qml').read_text()
        binding = qml.split('readonly property var pluginEntry: {', 1)[1].split('\n  readonly property bool active:', 1)[0].rsplit('}', 1)[0]
        persist = qml.split('  function persist(changes) {', 1)[1].split('\n  function writeEntryInto', 1)[0].rsplit('}', 1)[0]
        script = '''
const vm = require('vm');
const assert = require('assert');
const fs = require('fs');
const Actions = vm.createContext({});
const Corners = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[1], 'utf8').replace(/^\\.pragma library/m, ''), Actions);
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8').replace(/^\\.pragma library/m, ''), Corners);
const pluginId = 'io.github.omargond.omacorners';
const shell = {
  barConfig: {layout: {}},
  mutateShellConfig() { throw Error('Scoped mutator must not be used'); },
  updateEntryInline(id, entry) {
    assert.equal(id, pluginId);
    shell.barConfig.layout.centerEnd[0] = entry;
    return true;
  }
};
const read = new Function('shell', 'pluginId', 'Actions', BINDING);
for (const section of ['left', 'centerBegin', 'center', 'centerEnd', 'right', 'tray']) {
  shell.barConfig.layout = {[section]: [{id: pluginId, topLeft: 'app:google-chrome'}]};
  assert.equal(read(shell, pluginId, Actions).topLeft, 'app:google-chrome');
}
shell.barConfig.layout = {centerEnd: [{id: pluginId}]};
const context = {shell, pluginId, Actions, Corners,
 active: true, delayMs: 400, thresholdPx: 8, powerDelayMs: 800,
 requireSuper: true, suppressFullscreen: true, suppressDrag: true,
 suppressOverlay: true, topLeft: 'none', topRight: 'none',
 bottomLeft: 'none', bottomRight: 'none', workspaceMap: {}, welcomed: true};
vm.runInNewContext('(function(changes) {' + PERSIST + '})({topLeft: "app:google-chrome"})', context);
assert.equal(read(shell, pluginId, Actions).topLeft, 'app:google-chrome');
'''.replace('BINDING', json.dumps(binding)).replace('PERSIST', json.dumps(persist))
        subprocess.run(['node', '-e', script, str(ROOT / 'Actions.js'), str(ROOT / 'Corners.js')], check=True, capture_output=True, text=True)
