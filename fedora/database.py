import sqlite3
import os
from pathlib import Path

def get_db_path() -> Path:
    root = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "dadlan"
    root.mkdir(parents=True, exist_ok=True)
    return root / "history.db"

def init_db():
    path = get_db_path()
    with sqlite3.connect(path) as conn:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                target TEXT,
                action TEXT,
                instance_id TEXT,
                status TEXT,
                duration TEXT,
                output TEXT
            )
        ''')
        conn.commit()

def log_action(target: str, action: str, instance_id: str, status: str, duration: str, output: str):
    path = get_db_path()
    with sqlite3.connect(path) as conn:
        conn.execute('''
            INSERT INTO history (target, action, instance_id, status, duration, output)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (target, action, instance_id, status, duration, output))
        conn.commit()

def get_history(limit: int = 50) -> list:
    path = get_db_path()
    with sqlite3.connect(path) as conn:
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute('SELECT * FROM history ORDER BY timestamp DESC LIMIT ?', (limit,))
        return [dict(row) for row in cur.fetchall()]
