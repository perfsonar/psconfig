"""
Tests for Config.validate_refs() and context references on address labels.

A local address label with contexts used to raise
TypeError: 'method' object is not iterable, because the loop iterated over
label.context_refs instead of calling it.
"""

from unittest import TestCase

from psconfig.client.psconfig.config import Config


def make_config(label_contexts, remote_label_contexts, defined_contexts):
    return Config(data={
        "addresses": {
            "host-a": {
                "address": "host-a.example.net",
                "labels": {
                    "private": {"address": "10.0.0.1",
                                "contexts": label_contexts},
                },
                "remote-addresses": {
                    "host-b": {
                        "address": "host-a-remote.example.net",
                        "labels": {
                            "private": {"address": "10.0.1.1",
                                        "contexts": remote_label_contexts},
                        },
                    },
                },
            },
            "host-b": {"address": "host-b.example.net"},
        },
        "contexts": {name: {"context": "linuxnamespace",
                            "data": {"namespace": name}}
                     for name in defined_contexts},
        "groups": {},
        "tests": {},
        "tasks": {},
    })


class TestValidateRefsLabelContexts(TestCase):

    def test_label_contexts_that_exist_pass(self):
        psconfig = make_config(["ns1"], ["ns1"], ["ns1"])
        self.assertEqual([], psconfig.validate_refs())

    def test_missing_label_context_is_reported(self):
        psconfig = make_config(["missing"], ["ns1"], ["ns1"])
        errors = psconfig.validate_refs()
        self.assertEqual(1, len(errors))
        self.assertIn("label private", errors[0])
        self.assertIn("missing", errors[0])

    def test_missing_remote_label_context_is_reported(self):
        # the remote label branch already called context_refs(); this checks
        # the local label branch no longer aborts validation before it
        psconfig = make_config(["ns1"], ["missing"], ["ns1"])
        errors = psconfig.validate_refs()
        self.assertEqual(1, len(errors))
        self.assertIn("missing", errors[0])
