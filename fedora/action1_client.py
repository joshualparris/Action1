import json
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Optional, Dict, List

REGIONS = {
    "Australia": "https://app.au.action1.com/api/3.0",
    "Europe": "https://app.eu.action1.com/api/3.0",
    "NorthAmerica": "https://app.action1.com/api/3.0",
    "NorthAmerica-2": "https://app.na-2.action1.com/api/3.0",
}

class Action1Error(RuntimeError):
    pass

class Action1Client:
    def __init__(self, region: str, client_id: str, client_secret: str):
        if region not in REGIONS:
            raise Action1Error(f"Unsupported region: {region}")
        self.region = region
        self.base_url = REGIONS[region]
        self.client_id = client_id
        self._client_secret = client_secret
        self._access_token: Optional[str] = None
        self._token_expiry = 0.0

    def authenticate(self) -> None:
        payload = urllib.parse.urlencode({"client_id": self.client_id, "client_secret": self._client_secret}).encode("utf-8")
        req = urllib.request.Request(
            f"{self.base_url}/oauth2/token",
            data=payload,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        data = self._open_json(req)
        token = data.get("access_token")
        if not token:
            raise Action1Error("Action1 authentication response did not include an access_token.")
        self._access_token = token
        self._token_expiry = time.time() + max(60, int(data.get("expires_in", 3600)) - 60)
        self._client_secret = ""

    def _ensure_token(self) -> None:
        if not self._access_token or time.time() >= self._token_expiry:
            raise Action1Error("The Action1 token has expired. Reconnect; DadLAN does not persist the Client Secret.")

    @staticmethod
    def _open_json(req: urllib.request.Request) -> dict:
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                raw = response.read().decode("utf-8")
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            try:
                detail = json.loads(body)
                detail_text = detail.get("message") or detail.get("error_description") or body
            except Exception:
                detail_text = body
            raise Action1Error(f"Action1 HTTP {exc.code}: {detail_text}") from exc
        except urllib.error.URLError as exc:
            raise Action1Error(f"Could not reach Action1: {exc.reason}") from exc

    def get(self, path_or_url: str, params: Optional[Dict[str, str]] = None) -> dict:
        self._ensure_token()
        url = path_or_url if path_or_url.startswith(("http://", "https://")) else f"{self.base_url}/{path_or_url.lstrip('/')}"
        if params:
            query = urllib.parse.urlencode(params)
            url += ("&" if "?" in url else "?") + query
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {self._access_token}", "Accept": "application/json"}, method="GET")
        return self._open_json(req)

    def post(self, path_or_url: str, payload: dict) -> dict:
        self._ensure_token()
        url = path_or_url if path_or_url.startswith(("http://", "https://")) else f"{self.base_url}/{path_or_url.lstrip('/')}"
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=data, headers={"Authorization": f"Bearer {self._access_token}", "Accept": "application/json", "Content-Type": "application/json"}, method="POST")
        return self._open_json(req)

    def _paged_items(self, path: str, params: Optional[Dict[str, str]] = None) -> List[dict]:
        items: List[dict] = []
        url: Optional[str] = path
        first = True
        while url:
            page = self.get(url, params if first else None)
            first = False
            items.extend(page.get("items", []))
            url = page.get("next_page") or None
        return items

    def organizations(self) -> List[dict]:
        return self._paged_items("organizations", {"limit": "50"})

    def endpoints(self, org_id: str) -> List[dict]:
        return self._paged_items(f"endpoints/managed/{urllib.parse.quote(org_id, safe='')}", {"fields": "*", "limit": "50"})

    def endpoint(self, org_id: str, endpoint_id: str) -> dict:
        return self.get(f"endpoints/managed/{urllib.parse.quote(org_id, safe='')}/{urllib.parse.quote(endpoint_id, safe='')}", {"fields": "*"})

    def run_script(self, org_id: str, endpoint_id: str, script_content: str) -> dict:
        return self.post(f"automations/instances/{urllib.parse.quote(org_id, safe='')}", {
            "action": "run_script",
            "endpoints": [endpoint_id],
            "script": script_content
        })

    def automation_endpoint_results(self, org_id: str, instance_id: str) -> List[dict]:
        return self._paged_items(f"automations/instances/{urllib.parse.quote(org_id, safe='')}/{urllib.parse.quote(instance_id, safe='')}/endpoint-results")

    def automation_endpoint_details(self, org_id: str, instance_id: str, endpoint_id: str) -> dict:
        return self.get(f"automations/instances/{urllib.parse.quote(org_id, safe='')}/{urllib.parse.quote(instance_id, safe='')}/endpoint-results/{urllib.parse.quote(endpoint_id, safe='')}/details")
