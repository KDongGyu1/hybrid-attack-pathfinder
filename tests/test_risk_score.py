import unittest

from app.path_finder import calculate_risk_details, summarise_findings


class FakeNode:
    def __init__(self, labels, **properties):
        self.labels = set(labels)
        self._properties = properties

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


def make_path(target_sensitive=True):
    key = FakeNode(["Credential", "IAMAccessKey"], id="hap-dev-01-access-key")
    user = FakeNode(["IAMUser"], id="hap-dev-01-user")
    policy = FakeNode(["IAMPolicy"], id="hap-s3-access-policy")
    bucket = FakeNode(
        ["S3Bucket"],
        id="hap-customer-data-s3",
        sensitive=target_sensitive,
    )
    rels = [
        FakeRelationship("AUTHENTICATES_AS", key, user),
        FakeRelationship("HAS_PERMISSION", user, policy),
        FakeRelationship("CAN_ACCESS", policy, bucket, action="s3:*"),
    ]
    return FakePath([key, user, policy, bucket], rels)


class RiskScoreTest(unittest.TestCase):
    def test_finding_absent_path_still_scores(self):
        risk = calculate_risk_details(make_path(), [])

        self.assertGreater(risk["riskScore"], 0)
        self.assertEqual(risk["findingSummary"]["total"], 0)
        self.assertEqual(risk["riskBreakdown"]["findingRisk"], 0)

    def test_low_finding_increases_score_less_than_critical(self):
        low = calculate_risk_details(
            make_path(),
            [{"id": "low-1", "severity": "LOW", "source": "TRIVY", "status": "OPEN"}],
        )
        critical = calculate_risk_details(
            make_path(),
            [{"id": "crit-1", "severity": "CRITICAL", "source": "TRIVY", "status": "OPEN"}],
        )

        self.assertLess(low["riskScore"], critical["riskScore"])
        self.assertEqual(low["findingSummary"]["low"], 1)
        self.assertEqual(critical["findingSummary"]["critical"], 1)

    def test_duplicate_cve_is_counted_once(self):
        summary, finding_risk = summarise_findings(
            [
                {
                    "id": "finding-a",
                    "source": "TRIVY",
                    "severity": "HIGH",
                    "cvss_score": 8.1,
                    "cve_id": "CVE-2026-0001",
                    "status": "OPEN",
                },
                {
                    "id": "finding-b",
                    "source": "TRIVY",
                    "severity": "CRITICAL",
                    "cvss_score": 9.8,
                    "cve_id": "CVE-2026-0001",
                    "status": "OPEN",
                },
            ]
        )

        self.assertEqual(summary["total"], 1)
        self.assertEqual(summary["critical"], 1)
        self.assertGreater(finding_risk, 0)

    def test_resolved_and_suppressed_findings_are_excluded(self):
        summary, finding_risk = summarise_findings(
            [
                {"id": "resolved", "severity": "CRITICAL", "status": "RESOLVED"},
                {"id": "suppressed", "severity": "HIGH", "status": "SUPPRESSED"},
            ]
        )

        self.assertEqual(summary["total"], 0)
        self.assertEqual(finding_risk, 0)

    def test_finding_count_and_score_are_capped(self):
        findings = [
            {
                "id": f"critical-{index}",
                "source": "TRIVY",
                "severity": "CRITICAL",
                "cvss_score": 10.0,
                "status": "OPEN",
            }
            for index in range(20)
        ]
        summary, finding_risk = summarise_findings(findings)
        risk = calculate_risk_details(make_path(), findings)

        self.assertEqual(summary["total"], 20)
        self.assertLessEqual(finding_risk, 2.5)
        self.assertLessEqual(risk["riskScore"], 10.0)


if __name__ == "__main__":
    unittest.main()
