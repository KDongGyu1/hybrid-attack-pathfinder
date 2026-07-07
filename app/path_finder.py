import json
import os
from pathlib import Path
from typing import Any, Dict, List

from neo4j import GraphDatabase


NEO4J_URI = os.getenv("NEO4J_URI", "bolt://127.0.0.1:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "password123")


SCENARIOS = [
    {
        "scenarioId": "scn-onprem-access-key-to-s3",
        "scenarioName": "온프레미스 서버 침해 후 AWS Access Key를 통한 S3 접근",
        "sourceAssetId": "onprem-admin-server",
        "targetAssetId": "hap-customer-data-s3",
        "summary": "온프레미스 관리 서버 침해 후 저장된 AWS Access Key를 탈취하여 IAM User와 IAM Policy를 거쳐 고객 데이터 S3 Bucket에 접근 가능한 경로",
        "query": """
        MATCH (source:Asset {id: $sourceAssetId})
        MATCH (target:Asset {id: $targetAssetId})
        MATCH path = (source)-[
          r:STORES_CREDENTIAL|BELONGS_TO|HAS_POLICY|HAS_PERMISSION*1..6
        ]->(target)
        RETURN path
        ORDER BY length(path) ASC
        LIMIT 10
        """
    },
    {
        "scenarioId": "scn-eks-irsa-to-secrets",
        "scenarioName": "EKS Pod 침해 후 IRSA를 통한 Secrets Manager 접근",
        "sourceAssetId": "eks-pod-gitea",
        "targetAssetId": "secret-gitea-db-password",
        "summary": "Gitea EKS Pod 침해 후 ServiceAccount와 IRSA Role을 거쳐 Secrets Manager의 DB 비밀번호 Secret에 접근 가능한 경로",
        "query": """
        MATCH (source:Asset {id: $sourceAssetId})
        MATCH (target:Asset {id: $targetAssetId})
        MATCH path = (source)-[
          r:USES_SERVICE_ACCOUNT|IRSA_LINKED_TO|HAS_POLICY|HAS_PERMISSION*1..6
        ]->(target)
        RETURN path
        ORDER BY length(path) ASC
        LIMIT 10
        """
    },
    {
        "scenarioId": "scn-eks-irsa-to-rds",
        "scenarioName": "EKS Pod 침해 후 Secrets Manager를 통한 RDS 접근",
        "sourceAssetId": "eks-pod-gitea",
        "targetAssetId": "rds-postgres-prod",
        "summary": "Gitea EKS Pod 침해 후 IRSA Role로 Secrets Manager에 접근하고, 저장된 DB Credential을 통해 RDS PostgreSQL까지 이어지는 경로",
        "query": """
        MATCH (source:Asset {id: $sourceAssetId})
        MATCH (target:Asset {id: $targetAssetId})
        MATCH path = (source)-[
          r:USES_SERVICE_ACCOUNT|IRSA_LINKED_TO|HAS_POLICY|HAS_PERMISSION|STORES_CREDENTIAL_FOR*1..8
        ]->(target)
        RETURN path
        ORDER BY length(path) ASC
        LIMIT 10
        """
    },
    {
        "scenarioId": "scn-internet-gitea-to-rds",
        "scenarioName": "인터넷 노출 Gitea를 통한 RDS 접근",
        "sourceAssetId": "internet",
        "targetAssetId": "rds-postgres-prod",
        "summary": "인터넷에 노출된 Gitea 애플리케이션 서버 침해 후 RDS PostgreSQL에 접근 가능한 네트워크 기반 공격 경로",
        "query": """
        MATCH (source:Asset {id: $sourceAssetId})
        MATCH (target:Asset {id: $targetAssetId})
        MATCH path = (source)-[
          r:EXPOSED_TO_INTERNET|CONNECTS_TO_DB*1..5
        ]->(target)
        RETURN path
        ORDER BY length(path) ASC
        LIMIT 10
        """
    },
    {
        "scenarioId": "scn-onprem-to-restricted-assets",
        "scenarioName": "온프레미스 서버 침해 후 Restricted 자산 접근 가능 경로",
        "sourceAssetId": "onprem-admin-server",
        "targetAssetId": None,
        "summary": "온프레미스 관리 서버 침해 후 저장된 AWS Access Key를 통해 접근 가능한 모든 Restricted 등급 자산 탐색",
        "query": """
        MATCH (source:Asset {id: $sourceAssetId})
        MATCH (target:Asset)
        WHERE target.sensitivityLevel = 'RESTRICTED'
          AND target.assetRole = 'TARGET'
          AND source.id <> target.id
        MATCH path = (source)-[
          r:STORES_CREDENTIAL|BELONGS_TO|HAS_POLICY|HAS_PERMISSION|STORES_CREDENTIAL_FOR*1..8
        ]->(target)
        RETURN path
        ORDER BY length(path) ASC
        LIMIT 20
        """
    }
]


def node_to_dict(node: Any) -> Dict[str, Any]:
    return {
        "id": node.get("id"),
        "label": node.get("label"),
        "type": node.get("type"),
        "environment": node.get("environment"),
        "assetRole": node.get("assetRole"),
        "sensitivityLevel": node.get("sensitivityLevel"),
        "riskLevel": node.get("riskLevel"),
    }


def relationship_to_dict(rel: Any) -> Dict[str, Any]:
    return {
        "id": rel.get("id") or rel.element_id,
        "source": rel.start_node.get("id"),
        "target": rel.end_node.get("id"),
        "type": rel.type,
        "action": rel.get("action"),
    }


def dedupe_by_id(items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seen = set()
    result = []

    for item in items:
        item_id = item.get("id")
        if item_id and item_id not in seen:
            seen.add(item_id)
            result.append(item)

    return result


def calculate_risk_score(path: Any) -> float:
    nodes = list(path.nodes)
    rels = list(path.relationships)

    score = 3.0

    target = nodes[-1]
    target_sensitivity = target.get("sensitivityLevel")

    if target_sensitivity == "RESTRICTED":
        score += 3.0
    elif target_sensitivity == "CONFIDENTIAL":
        score += 2.0
    elif target_sensitivity == "INTERNAL":
        score += 1.0

    rel_types = {rel.type for rel in rels}
    node_types = {node.get("type") for node in nodes}
    node_risks = {node.get("riskLevel") for node in nodes}

    if "EXPOSED_TO_INTERNET" in rel_types:
        score += 1.2

    if {"STORES_CREDENTIAL", "HAS_POLICY", "HAS_PERMISSION", "IRSA_LINKED_TO"} & rel_types:
        score += 1.5

    if {"AWS_ACCESS_KEY", "IAM_USER", "IAM_ROLE", "IAM_POLICY", "SECRETS_MANAGER"} & node_types:
        score += 1.0

    if "CRITICAL" in node_risks:
        score += 0.8

    hop_count = len(rels)
    if hop_count <= 4:
        score += 0.7

    return round(min(score, 10.0), 1)


def risk_level_from_score(score: float) -> str:
    if score >= 8.0:
        return "CRITICAL"
    if score >= 6.0:
        return "HIGH"
    if score >= 4.0:
        return "MEDIUM"
    return "LOW"


def convert_path_to_response(
    scenario: Dict[str, Any],
    path: Any,
    index: int
) -> Dict[str, Any]:
    nodes = [node_to_dict(node) for node in path.nodes]
    edges = [relationship_to_dict(rel) for rel in path.relationships]

    risk_score = calculate_risk_score(path)
    risk_level = risk_level_from_score(risk_score)

    source_asset_id = nodes[0]["id"]
    target_asset_id = nodes[-1]["id"]

    return {
        "pathId": f"path-{scenario['scenarioId']}-{index + 1}",
        "sourceAssetId": source_asset_id,
        "targetAssetId": target_asset_id,
        "hopCount": len(edges),
        "riskScore": risk_score,
        "riskLevel": risk_level,
        "nodeIds": [node["id"] for node in nodes],
        "edgeIds": [edge["id"] for edge in edges],
        "summary": scenario["summary"],
        "nodes": nodes,
        "edges": edges,
    }


def run_scenario(driver: Any, scenario: Dict[str, Any]) -> Dict[str, Any]:
    with driver.session(database="neo4j") as session:
        result = session.run(
            scenario["query"],
            sourceAssetId=scenario["sourceAssetId"],
            targetAssetId=scenario["targetAssetId"],
        )

        paths = []
        all_nodes = []
        all_edges = []

        for index, record in enumerate(result):
            path = record["path"]
            path_response = convert_path_to_response(scenario, path, index)
            paths.append(path_response)
            all_nodes.extend(path_response["nodes"])
            all_edges.extend(path_response["edges"])

        nodes = dedupe_by_id(all_nodes)
        edges = dedupe_by_id(all_edges)

        max_risk_score = max([p["riskScore"] for p in paths], default=0.0)
        max_risk_level = risk_level_from_score(max_risk_score)

        return {
            "scenarioId": scenario["scenarioId"],
            "scenarioName": scenario["scenarioName"],
            "sourceAssetId": scenario["sourceAssetId"],
            "targetAssetId": scenario["targetAssetId"],
            "riskScore": max_risk_score,
            "riskLevel": max_risk_level,
            "pathCount": len(paths),
            "nodes": nodes,
            "edges": edges,
            "paths": paths,
            "summary": scenario["summary"],
        }


def main() -> None:
    output_dir = Path("data")
    output_dir.mkdir(exist_ok=True)

    driver = GraphDatabase.driver(
        NEO4J_URI,
        auth=(NEO4J_USER, NEO4J_PASSWORD),
    )

    try:
        driver.verify_connectivity()

        results = []
        for scenario in SCENARIOS:
            scenario_result = run_scenario(driver, scenario)
            results.append(scenario_result)

        response = {
            "project": "Hybrid Attack Path Analysis System",
            "engine": "Backend 1 - Neo4j Attack Path Engine",
            "neo4jUri": NEO4J_URI,
            "scenarioCount": len(results),
            "results": results,
        }

        output_path = output_dir / "path_results_mvp.json"
        output_path.write_text(
            json.dumps(response, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        print(json.dumps(response, ensure_ascii=False, indent=2))
        print()
        print(f"[OK] Attack path results saved to: {output_path}")

    finally:
        driver.close()


if __name__ == "__main__":
    main()