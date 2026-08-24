import unittest
import json
from unittest.mock import MagicMock, patch
from diagnostics import get_diagnostic
from database import init_db, log_action, get_history
import os

class TestDadLAN(unittest.TestCase):
    def test_diagnostic_registry(self):
        diag = get_diagnostic("system_snapshot")
        self.assertEqual(diag["id"], "system_snapshot")
        self.assertIn("Get-CimInstance", diag["script"])
        
        with self.assertRaises(ValueError):
            get_diagnostic("unknown")

    def test_database_history(self):
        os.environ["XDG_DATA_HOME"] = "/tmp/dadlan_test_data"
        init_db()
        log_action("Laptop 02", "System Snapshot", "inst_123", "Success", "1000 ms", '{"test": "data"}')
        history = get_history(1)
        self.assertEqual(len(history), 1)
        self.assertEqual(history[0]["target"], "Laptop 02")
        self.assertEqual(history[0]["status"], "Success")

    @patch('action1_client.urllib.request.urlopen')
    def test_action1_client(self, mock_urlopen):
        from action1_client import Action1Client
        
        client = Action1Client("Australia", "cid", "sec")
        mock_response = MagicMock()
        mock_response.read.return_value = b'{"access_token": "token123", "expires_in": 3600}'
        mock_urlopen.return_value.__enter__.return_value = mock_response
        
        client.authenticate()
        self.assertEqual(client._access_token, "token123")
        
        mock_response.read.return_value = b'{"id": "inst_123"}'
        res = client.run_script("org1", "ep1", "echo 1")
        self.assertEqual(res.get("id"), "inst_123")

if __name__ == '__main__':
    unittest.main()
