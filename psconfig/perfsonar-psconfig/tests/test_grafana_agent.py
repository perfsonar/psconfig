"""
Tests for how the Grafana agent turns group dimensions into rows/cols.

Regression test for perfsonar/psconfig#189: a selector with a label used to
put the AddressLabel object into rows/cols, so the disjoint check
``sorted(rows) != sorted(cols)`` raised TypeError and the agent exited.
"""

from unittest import TestCase

from psconfig.client.psconfig.config import Config
from psconfig.grafana.agent import Agent

CONFIG = {
    "addresses": {
        "host-a": {
            "address": "host-a.example.net",
            "labels": {"private": {"address": "10.0.0.1"}},
        },
        "host-b": {
            "address": "host-b.example.net",
            "labels": {"private": {"address": "10.0.0.2"}},
        },
    },
    "groups": {
        "labelled-mesh": {
            "type": "mesh",
            "addresses": [
                {"name": "host-a", "label": "private"},
                {"name": "host-b", "label": "private"},
            ],
        },
        "plain-mesh": {
            "type": "mesh",
            "addresses": [{"name": "host-a"}, {"name": "host-b"}],
        },
        "mixed-disjoint": {
            "type": "disjoint",
            "a-addresses": [{"name": "host-a", "label": "private"}],
            "b-addresses": [{"name": "host-b"}],
        },
        "missing-label-mesh": {
            "type": "mesh",
            "addresses": [
                {"name": "host-a", "label": "private"},
                {"name": "host-b", "label": "no-such-label"},
            ],
        },
    },
    "tests": {},
    "tasks": {},
}


class TestGrafanaAgentDimensionAddresses(TestCase):

    def setUp(self):
        self.psconfig = Config(data=CONFIG)

    def rows_cols(self, group_name):
        group = self.psconfig.group(group_name)
        return (Agent._dimension_addresses(group, self.psconfig, 0),
                Agent._dimension_addresses(group, self.psconfig, 1))

    def test_labelled_addresses_are_label_address_strings(self):
        rows, cols = self.rows_cols("labelled-mesh")
        self.assertEqual(["10.0.0.1", "10.0.0.2"], rows)
        self.assertEqual(rows, cols)
        for addr in rows + cols:
            self.assertIsInstance(addr, str)

    def test_unlabelled_addresses_are_address_strings(self):
        rows, cols = self.rows_cols("plain-mesh")
        self.assertEqual(["host-a.example.net", "host-b.example.net"], rows)
        self.assertEqual(rows, cols)

    def test_disjoint_check_does_not_raise(self):
        # same comparison as Agent._run_handle_psconfig uses for disjoint groups
        rows, cols = self.rows_cols("mixed-disjoint")
        self.assertEqual(["10.0.0.1"], rows)
        self.assertEqual(["host-b.example.net"], cols)
        self.assertNotEqual(sorted(rows), sorted(cols))

    def test_labelled_mesh_sorts(self):
        rows, cols = self.rows_cols("labelled-mesh")
        self.assertEqual(sorted(rows), sorted(cols))

    def test_missing_label_is_skipped(self):
        rows, _ = self.rows_cols("missing-label-mesh")
        self.assertEqual(["10.0.0.1"], rows)
