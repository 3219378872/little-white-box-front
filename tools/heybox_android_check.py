"""Capture the installed Mock APK on a dedicated Android emulator."""

import argparse
import json
from pathlib import Path
import subprocess
import time
import xml.etree.ElementTree as ET

import uiautomator2 as u2


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--serial', default='emulator-5566')
parser.add_argument('--output', required=True)
args = parser.parse_args()
output = Path(args.output)
output.mkdir(parents=True, exist_ok=True, mode=0o700)
app = 'com.xiaobaihe.xiaobaihe_app'
device = u2.connect(args.serial)
device.jsonrpc.setConfigurator({'waitForIdleTimeout': 0})
reports = []


def capture(name):
    time.sleep(1)
    assert device.app_current()['package'] == app, 'Reference/private apps must not be captured'
    xml = device.dump_hierarchy()
    root = ET.fromstring(xml)
    nodes = [node.attrib for node in root.iter('node') if node.get('content-desc') or node.get('text')]
    assert any(node.get('package') == app for node in nodes), 'Application semantics must be nonempty'
    page = name.split('-', 1)[1]
    if page not in {'feed', 'search', 'search-results', 'messages', 'profile'}:
        assert not any(node.get('content-desc', '').endswith('个标签，共 5 个') for node in nodes), 'Secondary pages must hide primary navigation'
    device.screenshot(str(output / f'{name}.png'))
    (output / f'{name}.xml').write_text(xml, encoding='utf8')
    deviation = float(subprocess.check_output(['identify', '-format', '%[standard-deviation]', str(output / f'{name}.png')]))
    assert deviation > 500, 'Frame must not be blank'
    reports.append({'name': name, 'package': app, 'deviation': deviation, 'nodes': nodes})
    (output / 'report.json').write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding='utf8')
    print(name, flush=True)


def nav(name):
    device(descriptionMatches=f'^{name}\\n第 .*个标签，共 5 个$').click(timeout=10)
    time.sleep(.5)


def back():
    device(description='返回').click(timeout=5)
    time.sleep(.5)


def hide_keyboard():
    if 'mInputShown=true' in device.shell(['dumpsys', 'input_method']).output:
        device.press('back')
        time.sleep(.5)


try:
    for mode in ['light', 'dark']:
        device.shell(['cmd', 'uimode', 'night', 'yes' if mode == 'dark' else 'no'])
        device.app_stop(app)
        device.app_start(app)
        device(descriptionMatches='^推荐.*').wait(timeout=20)
        time.sleep(3)
        capture(f'{mode}-feed')
        device(descriptionContains='探店｜藏在巷子里的宝藏面馆').click()
        capture(f'{mode}-post')
        device(descriptionStartsWith='查看评论').click()
        capture(f'{mode}-comments')
        back()
        nav('搜索')
        capture(f'{mode}-search')
        field = device(className='android.widget.EditText')
        field.click()
        field.set_text('手机')
        device(description='搜索').click()
        hide_keyboard()
        capture(f'{mode}-search-results')
        nav('发布')
        capture(f'{mode}-editor')
        field = device(className='android.widget.EditText', instance=0)
        field.click()
        field.set_text('Android 界面验证草稿')
        capture(f'{mode}-editor-keyboard')
        hide_keyboard()
        back()
        nav('消息')
        capture(f'{mode}-messages')
        device(descriptionContains='小白盒 Agent').click()
        capture(f'{mode}-assistant')
        device(description='更多操作').click()
        capture(f'{mode}-assistant-menu')
        device(description='更多操作').click()
        back()
        nav('我的')
        capture(f'{mode}-profile')
        device(description='编辑资料').click()
        capture(f'{mode}-edit-profile')
        back()
        device(description='记忆').click()
        capture(f'{mode}-memory')
        back()
        device(description='追踪').click()
        capture(f'{mode}-watch')
        back()
finally:
    device.shell(['cmd', 'uimode', 'night', 'no'])
