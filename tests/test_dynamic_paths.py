import unittest

from app.dynamic_path_finder import (
    ALLOWED_RELATIONSHIP_TYPES,
    EXCLUDED_RELATIONSHIP_TYPES,
    START_LABELS,
    TARGET_LABELS,
    build_dynamic_path_query,
    run_dynamic_paths,
    validate_dynamic_path_params,
)
from app.path_finder import SCENARIOS


class FakeNode:
    def __init__(self, labels, **properties):
        self.labels = set(labels)
        self._properties = properties
        self._element_id = properties.get("id")

    def get(self, key, default=None):
        return self._properties.get(key, default)


class FakeRelationship:
    def __init__(self, rel_type, start_node, end_node, **properties):
        self.type = rel_type
        self.start_node = start_node
        self.end_node = end_node
        self.element_id = f"{start_node.get('id')}-{rel_type}-{end_node.get('id')}"
        self._properties = properties

    def get(self, key, default=None):
        return self._properties.get(key, default)


class FakePath:
    def __init__(self, nodes, relationships):
        self.nodes = nodes
        self.relationships = relationships


class FakeSession:
    def __init__(self, paths, findings_by_node_id=None):
        self.paths = paths
        self.findings_by_node_id = findings_by_node_id or {}
        self.dynamic_params = None
        self.dynamic_query = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def run(self, query, **params):
        if "HAS_FINDING" in query:
            rows = []
            for node_id in params["nodeIds"]:
                rows.extend(self.findings_by_node_id.get(node_id, []))
            return rows

        self.dynamic_query = query
        self.dynamic_params = params
        return [{"path": path} for path in self.paths]


class FakeDriver:
    def __init__(self, session):
        self._session = session

    def session(self, database="neo4j"):
        return self._session


def make_path(source_id, source_labels, target_id, target_labels, rel_type="CAN_ACCESS", **rel_props):
    source = FakeNode(source_labels, id=source_id)
    target = FakeNode(target_labels, id=target_id, sensitive=True)
    rel = FakeRelationship(rel_type, source, target, **rel_props)
    return FakePath([source, target], [rel])


class DynamicPathTest(unittest.TestCase):
    def test_max_depth_is_reflected_in_cypher(self):
        query = build_dynamic_path_query(5)

        self.assertIn("*1..5", query)
        self.assertIn("RETURN path", query)

    def test_invalid_bounds_are_rejected(self):
        with self.assertRaises(ValueError):
            validate_dynamic_path_params(max_depth=0)
        with self.assertRaises(ValueError):
            validate_dynamic_path_params(max_depth=13)
        with self.assertRaises(ValueError):
            validate_dynamic_path_params(limit=0)
        with self.assertRaises(ValueError):
            validate_dynamic_path_params(limit=201)
        with self.assertRaises(ValueError):
            validate_dynamic_path_params(min_risk_score=-0.1)
        with self.assertRaises(ValueError):
            validate_dynamic_path_params(min_risk_score=10.1)

    def test_default_start_and_target_labels_are_configured(self):
        self.assertIn("Internet", START_LABELS)
        self.assertIn("Credential", START_LABELS)
        self.assertIn("IAMAccessKey", START_LABELS)
        self.assertIn("S3Bucket", TARGET_LABELS)
        self.assertIn("RDS", TARGET_LABELS)
        self.assertIn("ECRRepository", TARGET_LABELS)

    def test_allowed_relationships_exclude_non_attack_edges(self):
        self.assertIn("CAN_ACCESS", ALLOWED_RELATIONSHIP_TYPES)
        self.assertIn("IRSA_LINKED_TO", ALLOWED_RELATIONSHIP_TYPES)
        self.assertIn("PULLS_IMAGE_FROM", ALLOWED_RELATIONSHIP_TYPES)

        for rel_type in EXCLUDED_RELATIONSHIP_TYPES:
            self.assertNotIn(rel_type, ALLOWED_RELATIONSHIP_TYPES)

    def test_dynamic_paths_are_deduped_and_sorted_by_risk(self):
        low_path = make_path("internet", ["Internet"], "hap-gitea-db", ["RDS"], "CONNECTS_TO")
        high_path = make_path(
            "hap-dev-01-access-key",
            ["Credential", "IAMAccessKey"],
            "hap-customer-data-s3",
            ["S3Bucket"],
            "CAN_ACCESS",
            action="s3:*",
        )
        findings = {
            "hap-dev-01-access-key": [
                {
                    "id": "finding-critical",
                    "source": "TRIVY",
                    "severity": "CRITICAL",
                    "cvss_score": 9.8,
                    "status": "OPEN",
                    "asset_id": "hap-dev-01-access-key",
                }
            ]
        }
        session = FakeSession([low_path, high_path, high_path], findings)
        response = run_dynamic_paths(FakeDriver(session), limit=10)

        self.assertEqual(response["pathCount"], 2)
        self.assertEqual(response["paths"][0]["sourceAssetId"], "hap-dev-01-access-key")
        self.assertGreaterEqual(response["paths"][0]["riskScore"], response["paths"][1]["riskScore"])
        self.assertEqual(response["paths"][0]["findingCount"], 1)

    def test_filter_parameters_are_passed_to_cypher(self):
        path = make_path("internet", ["Internet"], "hap-gitea-db", ["RDS"], "CONNECTS_TO")
        session = FakeSession([path])

        response = run_dynamic_paths(
            FakeDriver(session),
            max_depth=3,
            limit=5,
            source_id="internet",
            target_id="hap-gitea-db",
            min_risk_score=0,
        )

        self.assertEqual(response["filters"]["sourceId"], "internet")
        self.assertEqual(response["filters"]["targetId"], "hap-gitea-db")
        self.assertEqual(session.dynamic_params["sourceId"], "internet")
        self.assertEqual(session.dynamic_params["targetId"], "hap-gitea-db")
        self.assertEqual(session.dynamic_params["candidateLimit"], 50)
        self.assertIn("*1..3", session.dynamic_query)

    def test_min_risk_score_filters_paths_after_scoring(self):
        path = make_path("internet", ["Internet"], "hap-gitea-db", ["RDS"], "CONNECTS_TO")
        response = run_dynamic_paths(FakeDriver(FakeSession([path])), min_risk_score=10)

        self.assertEqual(response["pathCount"], 0)
        self.assertEqual(response["highestRiskScore"], 0.0)

    def test_existing_fixed_scenarios_are_preserved(self):
        self.assertEqual([scenario["scenarioId"] for scenario in SCENARIOS], ["S1-A", "S1-B", "S2", "S3", "S4"])


if __name__ == "__main__":
    unittest.main()
