import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from sync_gateway_sdk import default_backend_api_path, generated_differences, render_api, render_types

REPO = Path(__file__).resolve().parents[1]
SCRIPT = Path(__file__).with_name('sync_gateway_sdk.py')


def prop(kind, name, required=True, **extra):
    return {'x-dart-type': kind, 'x-dart-name': name, 'x-dart-required': required, **extra}


class OpenAPIGeneratorTest(unittest.TestCase):
    def test_lossless_ids_nullable_patch_arrays_and_aliases(self):
        spec = {'components': {'schemas': {'UpdateReq': {'properties': {
            'id': prop('Object', 'conversationId'),
            'mediaIds': prop('List<Object>?', 'mediaIds', False, **{'x-dart-omit-null': True}),
            'images': prop('List<String>?', 'images', False, **{'x-dart-omit-null': True}),
            'score': prop('double?', 'score', False),
            'published': prop('bool?', 'published', False),
        }}, 'Post': {'properties': {'mediaIds': prop('List<Object>', 'mediaIds', False, **{'x-dart-default': 'const []'})}}}}}
        text = render_types(spec)
        self.assertIn('final Object conversationId;', text)
        self.assertIn("conversationId: m['id'] ?? 0", text)
        self.assertIn("'id': conversationId", text)
        self.assertIn("if (mediaIds != null) 'mediaIds': mediaIds", text)
        self.assertIn("if (images != null) 'images': images", text)
        self.assertIn('this.mediaIds = const []', text)
        self.assertNotIn('?.fromJson', text)
        self.assertNotIn('?.toJson', text)
        self.assertNotIn('.toInt()', text)

    def test_path_encoding_query_whitelist_and_bodyless_operation(self):
        spec = {'components': {'schemas': {'ListReq': {'properties': {
            'id': prop('Object', 'conversationId'), 'beforeId': prop('Object?', 'beforeId', False),
        }}}}, 'paths': {'/api/conversations/{id}': {'get': {
            'operationId': 'ListMessages', 'x-request-type': 'ListReq', 'x-response-type': 'ListResp',
            'parameters': [{'name': 'id', 'in': 'path'}, {'name': 'beforeId', 'in': 'query'}],
        }}, '/api/session': {'post': {'operationId': 'CreateSession', 'x-response-type': 'Session'}}}}
        text = render_api(spec)
        self.assertIn('Uri.encodeComponent(id.toString())', text)
        self.assertIn("allowed=<String>{'beforeId'}", text)
        self.assertIn('ListReq? request', text)
        self.assertIn('await apiPost(url,const {}', text)

    def test_streaming_operations_generate_routes_without_json_requests(self):
        spec = {'components': {'schemas': {}}, 'paths': {
            '/media': {'post': {'operationId': 'Upload', 'x-response-type': 'Media',
                'requestBody': {'content': {'multipart/form-data': {}}}}},
            '/runs/{id}/events': {'get': {'operationId': 'Events', 'x-response-type': 'Event',
                'x-sse': True, 'parameters': [{'name': 'id', 'in': 'path'}]}},
        }}
        text = render_api(spec)
        self.assertIn('const uploadPath = "/media"', text)
        self.assertIn('String eventsPath(Object id)', text)
        self.assertNotIn('await apiPost', text)
        self.assertNotIn('await apiGet', text)

    def test_default_api_works_from_nested_task_checkout(self):
        with TemporaryDirectory() as temp:
            workspace = Path(temp)
            frontend = workspace / 'little-white-box-front/.worktree/task-sdk'
            api = workspace / 'little-white-box-content-community/app/gateway/openapi.yaml'
            frontend.mkdir(parents=True)
            api.parent.mkdir(parents=True)
            api.touch()
            self.assertEqual(default_backend_api_path(frontend), api)

    def test_detects_drift_without_writing(self):
        with TemporaryDirectory() as temp:
            root = Path(temp)
            for name, value in [('generated', 'new'), ('vendor', 'new'), ('app', 'old')]:
                path = root / name / 'api/gateway.dart'
                path.parent.mkdir(parents=True)
                path.write_text(value)
            self.assertEqual(generated_differences(root/'generated', [root/'vendor', root/'app'], ['api/gateway.dart']), [root/'app/api/gateway.dart'])
            self.assertEqual((root/'app/api/gateway.dart').read_text(), 'old')

    def test_checks_require_explicit_reviewed_contract(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--check'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('--check requires an explicit --api path', result.stderr)
        for target in ('sdk-check', 'check'):
            result = subprocess.run(['make', '--no-print-directory', target, 'BACKEND_API='], cwd=REPO, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('BACKEND_API is required', result.stderr)
            self.assertNotIn('flutter analyze', result.stdout)


if __name__ == '__main__':
    unittest.main()
