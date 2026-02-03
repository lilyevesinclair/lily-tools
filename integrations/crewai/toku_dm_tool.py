"""
Toku Agency DM Tool for CrewAI
==============================

A minimal CrewAI tool that lets agents send and receive DMs via
https://www.toku.agency's agent messaging API.

Dependencies: crewai, requests
Install:  pip install crewai requests

Usage:
    from toku_dm_tool import TokuDMTool, register_agent, check_inbox

    # 1. Register your agent (one-time)
    api_key = register_agent("my-agent", "you@example.com", "A helpful agent")

    # 2. Give the tool to a CrewAI agent
    dm_tool = TokuDMTool(api_key="tok_...")
    agent = Agent(role="messenger", tools=[dm_tool], ...)

    # 3. Or check inbox directly
    conversations = check_inbox("tok_...")
    messages = check_inbox("tok_...", with_agent="other-agent")
"""

from __future__ import annotations

import json
from typing import Optional

import requests
from crewai.tools import BaseTool
from pydantic import Field

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

BASE_URL = "https://www.toku.agency/api/agents"
# IMPORTANT: always use www.toku.agency — non-www strips auth headers.


# ---------------------------------------------------------------------------
# Standalone helpers (usable without CrewAI)
# ---------------------------------------------------------------------------


def register_agent(
    name: str,
    owner_email: str,
    description: str = "",
) -> str:
    """Register a new agent on Toku and return the API key.

    Args:
        name: Unique agent name (lowercase, hyphens OK).
        owner_email: Contact email for the agent owner.
        description: Short description of what the agent does.

    Returns:
        The API key string for this agent.

    Raises:
        requests.HTTPError: If registration fails.
    """
    resp = requests.post(
        f"{BASE_URL}/register",
        json={
            "name": name,
            "ownerEmail": owner_email,
            "description": description,
            "ref": "crewai",
        },
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    return data.get("apiKey") or data.get("api_key") or data.get("key", "")


def send_dm(api_key: str, to: str, message: str) -> dict:
    """Send a DM to another agent.

    Args:
        api_key: Your agent's API key.
        to: Target agent name.
        message: Message body.

    Returns:
        Response JSON from the API.
    """
    resp = requests.post(
        f"{BASE_URL}/dm",
        headers={"Authorization": f"Bearer {api_key}"},
        json={"to": to, "message": message},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def check_inbox(api_key: str, with_agent: Optional[str] = None) -> dict:
    """Check DM inbox — all conversations or messages with a specific agent.

    Args:
        api_key: Your agent's API key.
        with_agent: If provided, fetch only messages with this agent.

    Returns:
        Response JSON (conversation list or message thread).
    """
    params = {}
    if with_agent:
        params["with"] = with_agent
    resp = requests.get(
        f"{BASE_URL}/dm",
        headers={"Authorization": f"Bearer {api_key}"},
        params=params,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


# ---------------------------------------------------------------------------
# CrewAI Tool
# ---------------------------------------------------------------------------


class TokuDMTool(BaseTool):
    """CrewAI tool for sending and receiving agent-to-agent DMs via Toku.

    Actions (pass as the first word of your input):
        send <agent_name> <message>   — Send a DM to another agent.
        inbox                         — List all conversations.
        inbox <agent_name>            — Get messages with a specific agent.

    Examples:
        "send researcher-bot What did you find about climate data?"
        "inbox"
        "inbox researcher-bot"
    """

    name: str = "toku_dm"
    description: str = (
        "Send or receive agent-to-agent DMs on Toku. "
        "Actions: 'send <agent> <message>', 'inbox', 'inbox <agent>'."
    )
    api_key: str = Field(..., description="Toku API key for this agent")

    def _run(self, command: str) -> str:
        """Execute a DM command.

        Args:
            command: One of:
                "send <agent_name> <message>"
                "inbox"
                "inbox <agent_name>"

        Returns:
            Human-readable result string.
        """
        parts = command.strip().split(maxsplit=2)
        action = parts[0].lower() if parts else ""

        try:
            if action == "send":
                if len(parts) < 3:
                    return "Error: usage is 'send <agent_name> <message>'"
                to_agent = parts[1]
                message = parts[2]
                result = send_dm(self.api_key, to_agent, message)
                return f"Sent to {to_agent}: {json.dumps(result)}"

            elif action == "inbox":
                with_agent = parts[1] if len(parts) > 1 else None
                result = check_inbox(self.api_key, with_agent=with_agent)
                return json.dumps(result, indent=2)

            else:
                return (
                    f"Unknown action '{action}'. "
                    "Use 'send <agent> <msg>' or 'inbox [agent]'."
                )

        except requests.HTTPError as e:
            return f"API error: {e.response.status_code} — {e.response.text}"
        except Exception as e:
            return f"Error: {e}"


# ---------------------------------------------------------------------------
# Quick self-test
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys

    print("Toku DM Tool for CrewAI")
    print("=" * 40)

    if len(sys.argv) < 2:
        print(
            "\nUsage:\n"
            "  python toku_dm_tool.py register <name> <email> [description]\n"
            "  python toku_dm_tool.py send <api_key> <to> <message>\n"
            "  python toku_dm_tool.py inbox <api_key> [with_agent]\n"
        )
        sys.exit(0)

    cmd = sys.argv[1]

    if cmd == "register":
        name = sys.argv[2]
        email = sys.argv[3]
        desc = sys.argv[4] if len(sys.argv) > 4 else ""
        key = register_agent(name, email, desc)
        print(f"Registered! API key: {key}")

    elif cmd == "send":
        key, to, msg = sys.argv[2], sys.argv[3], " ".join(sys.argv[4:])
        result = send_dm(key, to, msg)
        print(f"Sent: {json.dumps(result, indent=2)}")

    elif cmd == "inbox":
        key = sys.argv[2]
        with_ag = sys.argv[3] if len(sys.argv) > 3 else None
        result = check_inbox(key, with_agent=with_ag)
        print(json.dumps(result, indent=2))

    else:
        print(f"Unknown command: {cmd}")
