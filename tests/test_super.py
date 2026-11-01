"""Run the actual QML guard and modifier handlers as JavaScript."""
from pathlib import Path
import subprocess
import unittest

class SuperTests(unittest.TestCase):
    def test_super_required_and_release_cancels(self):
        source = (Path(__file__).resolve().parents[1] / 'Omacorners.qml').read_text()
        code = source[source.index('  function setSuperKey('):source.index('  function onCursor(')]
        fire = source[source.index('  function fire('):source.index('  function confirmPower(')]
        script = '''
const assert = require('assert');
let active=true, requireSuper=true, superArmed=false, superSeen=false;
let leftSuperHeld=false, rightSuperHeld=false, pendingPower='', suppressDrag=false;
let dragging=false, suppressFullscreen=false, fullscreenActive=false, suppressOverlay=false;
let cursorX=0, cursorY=0, dwellCorner='tl', latched=false, fired=0;
function clearDwell() { dwellCorner=''; }
function onCursor() {}
function overlayBlocking() { return false; }
''' + code + fire + '''
assert(blocked()); // Unknown modifier state must never authorize a corner.
fire(); // Must return before touching the action or timer.
setSuperKey('left', true); assert(!blocked());
setSuperKey('right', true);
setSuperKey('left', false); assert(!blocked());
setSuperKey('right', false); assert(blocked()); assert.equal(dwellCorner, '');
dwellCorner='tl'; fire();
requireSuper=false; assert(!blocked());
'''
        subprocess.run(['node','-e',script],check=True,capture_output=True,text=True)
