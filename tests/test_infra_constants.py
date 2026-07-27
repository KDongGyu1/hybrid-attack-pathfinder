from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SEED = (ROOT / "scripts" / "seed.cypher").read_text(encoding="utf-8")
ATTACK_QUERIES = (ROOT / "scripts" / "attack-path-queries.cypher").read_text(encoding="utf-8")
PATH_FINDER = (ROOT / "app" / "path_finder.py").read_text(encoding="utf-8")


class InfraConstantsTest(unittest.TestCase):
    def test_gitea_pod_and_service_account_namespace_are_prod(self):
        self.assertIn('pod.namespace = "prod"', SEED)
        self.assertIn('sa.namespace = "prod"', SEED)
        self.assertNotIn('namespace = "gitea"', SEED)

    def test_irsa_subject_uses_prod_namespace(self):
        subject = "system:serviceaccount:prod:gitea-sa"

        self.assertIn(subject, SEED)
        self.assertIn(subject, ATTACK_QUERIES)
        self.assertNotIn("system:serviceaccount:gitea:gitea-sa", SEED)

    def test_ecr_id_is_hap_ecr(self):
        self.assertIn('ECRRepository {id: "hap-ecr"}', SEED)
        self.assertIn('PULLS_IMAGE_FROM]->(ecr)', SEED)
        self.assertIn("hap-ecr", ATTACK_QUERIES)
        self.assertNotIn("hap-gitea-ecr", SEED)

    def test_api_serialises_kubernetes_and_irsa_metadata(self):
        self.assertIn('"namespace": node.get("namespace")', PATH_FINDER)
        self.assertIn('"irsaSubject": node.get("irsaSubject")', PATH_FINDER)
        self.assertIn('"trustedSubject": node.get("trustedSubject")', PATH_FINDER)
        self.assertIn('"subject": rel.get("subject")', PATH_FINDER)


if __name__ == "__main__":
    unittest.main()
