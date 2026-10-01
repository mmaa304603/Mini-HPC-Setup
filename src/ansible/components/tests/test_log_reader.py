"""Reader requests cannot become arbitrary Elasticsearch operations."""
import importlib.util
import io
import json
from types import SimpleNamespace
from unittest.mock import patch, MagicMock
from pathlib import Path
import unittest
from test_components import COMPONENTS

spec = importlib.util.spec_from_file_location('reader', COMPONENTS / 'elk/files/log_reader.py')
READER = importlib.util.module_from_spec(spec)
spec.loader.exec_module(READER)


class ReaderTests(unittest.TestCase):
    def test_query_is_bounded_and_only_uses_allowed_filters(self):
        query = READER.query_body({'dataset': 'hpc.health', 'host': 'cpu01', 'limit': 10})
        self.assertEqual(query['size'], 10)
        self.assertEqual(query['timeout'], '5s')
        self.assertIn({'term': {'host.name': 'cpu01'}}, query['query']['bool']['filter'])
        self.assertNotIn('script', query)

    def test_arbitrary_dsl_paths_and_unbounded_requests_are_rejected(self):
        for options in [[], {'url': '/_delete_by_query'}, {'query': {'match_all': {}}},
                        {'script': 'anything'}, {'limit': 101}, {'limit': True},
                        {'seconds': 604801}, {'seconds': 0}, {'dataset': '.security'},
                        {'message': 'x' * 257}, {'host': {'wildcard': '*'}}]:
            with self.subTest(options=options), self.assertRaises(ValueError):
                READER.query_body(options)

    def request(self, path, token, body):
        handler = object.__new__(READER.Handler)
        raw = json.dumps(body).encode()
        handler.path = path
        handler.headers = {'Authorization': token, 'Content-Length': str(len(raw))}
        handler.rfile = io.BytesIO(raw)
        handler.server = SimpleNamespace(token='test-token', search_url='http://127.0.0.1:9200/hpc-logs-*/_search')
        replies = []
        handler.respond = lambda status, data: replies.append((status, data))
        handler.do_POST()
        return replies[0]

    def test_authentication_and_route_checks_precede_backend_access(self):
        with patch.object(READER.urllib.request, 'build_opener') as backend:
            self.assertEqual(self.request('/query', '', {})[0], 401)
            self.assertEqual(self.request('/query', 'Bearer wrong', {})[0], 401)
            self.assertEqual(self.request('/_delete_by_query', 'Bearer test-token', {})[0], 404)
            self.assertEqual(self.request('/query', 'Bearer test-token', {'script': 'bad'})[0], 400)
            backend.assert_not_called()

    def test_authorized_request_uses_only_fixed_search_and_reports_partial_results(self):
        with patch.object(READER.urllib.request, 'build_opener') as backend:
            response = backend.return_value.open.return_value.__enter__.return_value
            response.read.return_value = json.dumps({'hits': {'hits': [{'_source': {'message': 'test'}}]}}).encode()
            status, body = self.request('/query', 'Bearer test-token', {'limit': 1})
            self.assertEqual(status, 200)
            self.assertTrue(body['limit_reached'])
            request = backend.return_value.open.call_args.args[0]
            self.assertEqual(request.full_url, 'http://127.0.0.1:9200/hpc-logs-*/_search')
            self.assertNotIn('Authorization', request.headers)
            response.read.return_value = b'{"timed_out":true}'
            self.assertEqual(self.request('/query', 'Bearer test-token', {})[0], 503)

    def test_query_values_cannot_inject_json(self):
        query = READER.query_body({'message': '"},"script":{"source":"evil"}'})
        self.assertEqual(query['query']['bool']['filter'][-1],
                         {'match_phrase': {'message': '"},"script":{"source":"evil"}'}})


if __name__ == '__main__':
    unittest.main()
