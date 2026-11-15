#!/usr/bin/env python
"""Check the rendered reporting and control-plane contracts."""

import copy
import pathlib
import subprocess
import unittest
from urllib.parse import urlparse

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHART = ROOT / "charts" / "platform"


def render(*values):
    command = ["helm", "template", "platform", str(CHART)]
    for value in values:
        command.extend(["--set", value])
    output = subprocess.run(command, check=True, capture_output=True, text=True).stdout
    return [obj for obj in yaml.safe_load_all(output) if isinstance(obj, dict)]


def object_named(objects, kind, namespace, name):
    matches = [
        obj for obj in objects
        if obj.get("kind") == kind
        and obj.get("metadata", {}).get("namespace") == namespace
        and obj.get("metadata", {}).get("name") == name
    ]
    if len(matches) != 1:
        raise AssertionError(f"expected one {kind} {namespace}/{name}, found {len(matches)}")
    return matches[0]


def allows(policy, direction, peer, namespace, port):
    spec = policy["spec"]
    if spec.get("podSelector") != {} or direction.capitalize() not in spec.get("policyTypes", []):
        return False
    for rule in spec.get(direction, []):
        peers = rule.get(peer, [])
        ports = rule.get("ports", [])
        if any(
            p.get("namespaceSelector", {}).get("matchLabels", {}).get("kubernetes.io/metadata.name") == namespace
            and not p.get("podSelector") and not p.get("ipBlock")
            for p in peers
        ) and any(p.get("port") == port and p.get("protocol", "TCP") == "TCP" for p in ports):
            return True
    return False


class ChartContract(unittest.TestCase):
    def check_contract(self, objects, control_ns, broker_ns):
        service = object_named(objects, "Service", control_ns, "pestilence")
        port = service["spec"]["ports"][0]["port"]
        target_port = service["spec"]["ports"][0]["targetPort"]
        control = object_named(objects, "Deployment", control_ns, "pestilence")
        control_pod = control["spec"]["template"]
        for key, value in service["spec"]["selector"].items():
            self.assertEqual(control_pod["metadata"]["labels"].get(key), value)
        container_ports = control_pod["spec"]["containers"][0]["ports"]
        self.assertTrue(any(p.get("name") == target_port and p.get("containerPort") == 8080 for p in container_ports))
        town = object_named(objects, "Deployment", "town", "town")
        env = town["spec"]["template"]["spec"]["containers"][0]["env"]
        url = urlparse(next(item["value"] for item in env if item["name"] == "PESTILENCE_URL"))
        self.assertEqual((url.scheme, url.hostname, url.port), ("http", f"pestilence.{control_ns}.svc", port))
        self.assertEqual(target_port, "http")
        ingress = object_named(objects, "NetworkPolicy", control_ns, "allow-broker-reporting")
        egress = object_named(objects, "NetworkPolicy", broker_ns, "allow-reporting-control-plane")
        self.assertTrue(allows(ingress, "ingress", "from", broker_ns, 8080))
        self.assertTrue(allows(egress, "egress", "to", control_ns, 8080))

    def test_default_contract(self):
        self.check_contract(render(), "pestilence", "scarab")

    def test_rejects_contract_drift(self):
        base = render()
        for case in ("service URL", "ingress namespace", "egress port"):
            with self.subTest(case=case), self.assertRaises(AssertionError):
                objects = copy.deepcopy(base)
                if case == "service URL":
                    town = object_named(objects, "Deployment", "town", "town")
                    env = town["spec"]["template"]["spec"]["containers"][0]["env"]
                    next(item for item in env if item["name"] == "PESTILENCE_URL")["value"] = "http://other.pestilence.svc:8080"
                elif case == "ingress namespace":
                    ingress = object_named(objects, "NetworkPolicy", "pestilence", "allow-broker-reporting")
                    ingress["spec"]["ingress"][0]["from"][0]["namespaceSelector"]["matchLabels"]["kubernetes.io/metadata.name"] = "other"
                else:
                    egress = object_named(objects, "NetworkPolicy", "scarab", "allow-reporting-control-plane")
                    egress["spec"]["egress"][0]["ports"][0]["port"] = 9999
                self.check_contract(objects, "pestilence", "scarab")

    def test_namespace_overrides(self):
        objects = render(
            "pestilence.namespace.name=control-test",
            "pestilence.scarabNamespace.name=broker-test",
            "scarab.namespace.name=broker-test",
            "scarab.networkPolicy.controlPlaneNamespace=control-test",
            "town.config.pestilenceUrl=http://pestilence.control-test.svc:8080",
        )
        self.check_contract(objects, "control-test", "broker-test")


if __name__ == "__main__":
    unittest.main()
