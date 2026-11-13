"""Install Vesta's ACME certificates on JetKVMs (firmware 0.5.10).

Usage: jetkvm-tls-sync LOCAL_IP NAME=OVERLAY_IP=CERT_DIR ...

For each KVM, compare the certificate it serves on port 443 with
CERT_DIR/fullchain.pem and, when they differ, push the chain and key through
JetKVM's `setTLSState` JSON-RPC. JetKVM only takes RPC over the WebRTC data
channel `rpc` (signalling on /webrtc/signaling/client, no auth in noPassword
mode), so this opens a WebRTC session restricted to the overlay addresses.
That session replaces any viewer connected at the time, which is why the
push only happens when the served certificate is out of date.
"""

import asyncio
import base64
import hashlib
import json
import socket
import ssl
import sys
from pathlib import Path

from aiortc import RTCConfiguration, RTCPeerConnection, RTCSessionDescription
from aiortc.sdp import candidate_from_sdp
from websockets.asyncio.client import connect

TIMEOUT = 60


def leaf_fingerprint(chain_pem: str) -> str:
    leaf = chain_pem.split("-----END CERTIFICATE-----")[0]
    der = ssl.PEM_cert_to_DER_cert(leaf + "-----END CERTIFICATE-----\n")
    return hashlib.sha256(der).hexdigest()


def served_fingerprint(name: str, ip: str) -> str | None:
    """SHA-256 of the certificate served for NAME at IP:443, or None."""
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    try:
        with socket.create_connection((ip, 443), timeout=10) as raw:
            with context.wrap_socket(raw, server_hostname=name) as tls:
                return hashlib.sha256(tls.getpeercert(binary_form=True)).hexdigest()
    except OSError:
        return None


def verify_trusted(name: str, ip: str) -> None:
    """Fail unless IP serves a chain valid for NAME from the system CAs."""
    context = ssl.create_default_context()
    with socket.create_connection((ip, 443), timeout=10) as raw:
        with context.wrap_socket(raw, server_hostname=name):
            pass


async def rpc(local_ip: str, kvm_ip: str, method: str, params: dict) -> dict:
    pc = RTCPeerConnection(RTCConfiguration(iceServers=[]))
    channel = pc.createDataChannel("rpc")
    pc.addTransceiver("video", direction="recvonly")
    reply = asyncio.get_running_loop().create_future()

    @channel.on("open")
    def opened():
        channel.send(json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}))

    @channel.on("message")
    def received(raw):
        message = json.loads(raw)
        if message.get("id") == 1 and not reply.done():
            reply.set_result(message)

    async def add_candidate(data):
        value = data.get("candidate")
        if not value:
            return
        candidate = candidate_from_sdp(value.removeprefix("candidate:"))
        if candidate.ip != kvm_ip:
            return
        candidate.sdpMid = data.get("sdpMid")
        candidate.sdpMLineIndex = data.get("sdpMLineIndex")
        await pc.addIceCandidate(candidate)

    try:
        async with connect(f"ws://{kvm_ip}/webrtc/signaling/client", proxy=None, open_timeout=10) as ws:
            await ws.recv()  # device-metadata
            await pc.setLocalDescription(await pc.createOffer())
            # Offer only the overlay address, so the session never depends
            # on the LAN, STUN or TURN.
            lines = pc.localDescription.sdp.splitlines()
            sdp = "\r\n".join(
                line for line in lines
                if not line.startswith("a=candidate:") or line.split()[4] == local_ip
            ) + "\r\n"
            offer = base64.b64encode(json.dumps({"type": "offer", "sdp": sdp}).encode()).decode()
            await ws.send(json.dumps({"type": "offer", "data": {"sd": offer}}))

            async def signalling():
                pending = []
                async for raw in ws:
                    if raw == "ping":
                        await ws.send("pong")
                        continue
                    if raw == "pong":
                        continue
                    message = json.loads(raw)
                    if message.get("type") == "answer":
                        answer = json.loads(base64.b64decode(message["data"]))
                        await pc.setRemoteDescription(RTCSessionDescription(**answer))
                        for data in pending:
                            await add_candidate(data)
                        pending.clear()
                    elif message.get("type") == "new-ice-candidate":
                        if pc.remoteDescription:
                            await add_candidate(message["data"])
                        else:
                            pending.append(message["data"])
                    elif "error" in message:
                        raise RuntimeError(message["error"])

            reader = asyncio.create_task(signalling())
            try:
                result = await asyncio.wait_for(reply, TIMEOUT)
            finally:
                reader.cancel()
                await asyncio.gather(reader, return_exceptions=True)
    finally:
        await pc.close()
    if "error" in result:
        raise RuntimeError(f"{method}: {result['error']}")
    return result


async def sync(local_ip: str, name: str, kvm_ip: str, cert_dir: Path) -> None:
    chain = (cert_dir / "fullchain.pem").read_text()
    wanted = leaf_fingerprint(chain)
    if served_fingerprint(name, kvm_ip) == wanted:
        verify_trusted(name, kvm_ip)
        print(f"{name}: up to date")
        return
    print(f"{name}: installing certificate {wanted[:16]}")
    state = {"mode": "custom", "certificate": chain, "privateKey": (cert_dir / "key.pem").read_text()}
    await asyncio.wait_for(rpc(local_ip, kvm_ip, "setTLSState", {"state": state}), TIMEOUT + 30)
    for _ in range(10):
        if served_fingerprint(name, kvm_ip) == wanted:
            verify_trusted(name, kvm_ip)
            print(f"{name}: serving the new certificate")
            return
        await asyncio.sleep(3)
    raise RuntimeError(f"{name}: still not serving certificate {wanted[:16]}")


def main() -> int:
    local_ip, *targets = sys.argv[1:]
    failed = False
    for target in targets:
        name, kvm_ip, cert_dir = target.split("=", 2)
        try:
            asyncio.run(sync(local_ip, name, kvm_ip, Path(cert_dir)))
        except Exception as error:  # report every KVM, then fail
            print(f"{name}: {error!r}", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
