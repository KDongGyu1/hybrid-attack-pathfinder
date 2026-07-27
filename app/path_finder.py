import json
import os
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

try:
    from neo4j import GraphDatabase
except ModuleNotFoundError:
    GraphDatabase = None


NEO4J_URI = os.getenv("NEO4J_URI", "bolt://127.0.0.1:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "password1234")


SEVERITY_WEIGHTS = {
    "CRITICAL": 1.6,
    "HIGH": 1.1,
    "MEDIUM": 0.6,
    "LOW": 0.2,
    "UNKNOWN": 0.1,
}
FINDING_COUNT_CAP = 5
FINDING_RISK_CAP = 2.5
RISK_SCORE_CAP = 10.0
IGNORED_FINDING_STATUSES = {"RESOLVED", "SUPPRESSED"}


SCENARIOS = [
    {
        "scenarioId": "S1-A",
        "scenarioName": "dev-01 access key direct policy to customer S3",
        "scenarioStatus": "POTENTIAL",
        "sourceAssetId": "hap-dev-01-access-key",
        "targetAssetId": "hap-customer-data-s3",
        "summary": "Compromised dev-01 access key authenticates as hap-dev-01-user and reaches the customer data S3 bucket through the direct S3 policy.",
        "query": """
        MATCH path =
          (:Credential {id: $sourceAssetId})
          -[:AUTHENTICATES_AS]->
          (:IAMUser {id: "hap-dev-01-user"})
          -[:HAS_PERMISSION]->
          (:IAMPolicy {id: "hap-s3-access-policy"})
          -[:CAN_ACCESS]->
          (:S3Bucket {id: $targetAssetId})
        RETURN path
        ORDER BY length(path) ASC
        LIMIT 10
        """,
    },
    {
        "scenarioId": "S1-B",
        "scenarioName": "dev-01 access key assumes readonly role to customer S3",
        "scenarioStatus": "POTENTIAL",
        "sourceAssetId": "hap-dev-01-access-key",
        "targetAssetId": "hap-customer-data-s3",
        "summary": "Compromised dev-01 access key assumes hap-s3-readonly-role and reaches the customer data S3 bucket through the readonly policy.",
        "query": """
        MATCH path =
          (:Credential {id: $sourceAssetId})
          -[:AUTHENTICATES_AS]->
          (:IAMUser {id: "hap-dev-01-user"})
          -[:ASSUMES_ROLE]->
          (:IAMRole {id: "hap-s3-readonly-role"})
          -[:HAS_PERMISSION]->
          (:IAMPolicy {id: "hap-s3-readonly-policy"})
          -[:CAN_ACCESS]->
          (:S3Bucket {id: $targetAssetId})
        RETURN path
        ORDER BY length(path) ASC
        LIMIT 10
        """,
    },
    {
        "scenarioId": "S2",
        "scenarioName": "Internet to Gitea Pod and RDS",
        "scenarioStatus": "POTENTIAL",
        "sourceAssetId": "internet",
        "targetAssetId": "hap-gitea-db",
        "summary": "Internet traffic reaches hap-prod-alb on HTTP/80, the ALB can move to pod-gitea-app, and the Pod connects to the Gitea RDS PostgreSQL database.",
        "query": """
        MATCH path =
          (:Internet {id: $sourceAssetId})
          -[:EXPOSED_TO_INTERNET]->
          (:ALB {id: "hap-prod-alb"})
          -[:CAN_MOVE_TO]->
          (:Pod {id: "pod-gitea-app"})
          -[:CONNECTS_TO]->
          (:RDS {id: $targetAssetId})
        RETURN path
        ORDER BY length(path) ASC
        LIMIT 10
        """,
    },
    {
        "scenarioId": "S3",
        "scenarioName": "On-Prem WordPress key to customer S3 prefixes",
        "scenarioStatus": "POTENTIAL",
        "sourceAssetId": "hap-onprem-web",
        "targetAssetId": "hap-customer-data-s3",
        "summary": "Compromised On-Prem WordPress host uses hap-onprem-web-key to write to the allowed customer S3 backup prefixes only.",
        "query": """
        MATCH path =
          (:OnPremWeb {id: $sourceAssetId})
          -[:HAS_CREDENTIAL]->
          (:Credential {id: "hap-onprem-web-key"})
          -[:HAS_PERMISSION]->
          (:IAMPolicy {id: "hap-onprem-web-s3-policy"})
          -[access:CAN_ACCESS]->
          (:S3Bucket {id: $targetAssetId})
        WHERE access.resourcePrefix IN ["wordpress-files/", "wordpress-db/"]
        RETURN path
        ORDER BY access.resourcePrefix ASC
        LIMIT 10
        """,
    },
    {
        "scenarioId": "S4",
        "scenarioName": "Gitea Pod IRSA to Secret and RDS",
        "scenarioStatus": "POTENTIAL",
        "sourceAssetId": "pod-gitea-app",
        "targetAssetId": "hap-gitea-db",
        "summary": "Gitea Pod uses gitea-sa, assumes hap-irsa-gitea-role, reads gitea-db-credentials backed by hap-db-secret, and reaches the RDS database.",
        "query": """
        MATCH path =
          (:Pod {id: $sourceAssetId})
          -[:USES_SERVICE_ACCOUNT]->
          (:ServiceAccount {id: "gitea-sa"})
          -[:IRSA_LINKED_TO]->
          (:IAMRole {id: "hap-irsa-gitea-role"})
          -[:HAS_PERMISSION]->
          (:IAMPolicy {id: "hap-gitea-role-policy"})
          -[:CAN_ACCESS]->
          (:SecretsManager {id: "gitea-db-credentials"})
          -[:CONNECTS_TO]->
          (:RDS {id: $targetAssetId})
        RETURN path
        ORDER BY length(path) ASC
        LIMIT 10
        """,
    },
]


DETECTION_RULES = [
    {
        "scenario_id": "D1",
        "scenario_name": "IAM access key used from an unusual IP or region",
        "scenario_status": "DETECTABLE",
        "severity": "HIGH",
        "query": """
        MATCH (e:Event)
        WHERE coalesce(e.credential_id, e.access_key_id) IS NOT NULL
          AND (coalesce(e.is_unusual_ip, false) = true OR coalesce(e.is_unusual_region, false) = true)
        RETURN e
        """,
    },
    {
        "scenario_id": "D2",
        "scenario_name": "Repeated AssumeRole in a short time window",
        "scenario_status": "DETECTABLE",
        "severity": "MEDIUM",
        "query": """
        MATCH (e:Event)
        WHERE e.action = "sts:AssumeRole"
        WITH e.actor_id AS actor_id, e.role_arn AS role_arn, collect(e) AS events
        WHERE size(events) >= 5
        UNWIND events AS e
        RETURN e
        """,
    },
    {
        "scenario_id": "D3",
        "scenario_name": "AssumeRole followed by customer S3 read",
        "scenario_status": "DETECTABLE",
        "severity": "HIGH",
        "query": """
        MATCH (assume:Event)
        WHERE assume.action IN ["sts:AssumeRole", "sts:AssumeRoleWithWebIdentity"]
        MATCH (e:Event)
        WHERE e.bucket_name = "hap-customer-data-s3"
          AND e.action IN ["s3:ListBucket", "s3:GetObject"]
          AND e.event_time >= assume.event_time
          AND (e.session_id = assume.session_id OR e.actor_id = assume.actor_id)
        RETURN e
        """,
    },
    {
        "scenario_id": "D4",
        "scenario_name": "S3 PutObject outside allowed prefixes",
        "scenario_status": "DETECTABLE",
        "severity": "HIGH",
        "query": """
        MATCH (e:Event)
        WHERE e.bucket_name = "hap-customer-data-s3"
          AND e.action = "s3:PutObject"
          AND NOT (
            e.resource_prefix IN ["wordpress-files/", "wordpress-db/"]
            OR e.object_key STARTS WITH "wordpress-files/"
            OR e.object_key STARTS WITH "wordpress-db/"
          )
        RETURN e
        """,
    },
    {
        "scenario_id": "D5",
        "scenario_name": "WordPress compromise followed by hap-onprem-web-key use",
        "scenario_status": "DETECTABLE",
        "severity": "HIGH",
        "query": """
        MATCH (e:Event)
        WHERE e.source_asset_id = "hap-onprem-web"
          AND coalesce(e.credential_id, e.access_key_id) = "hap-onprem-web-key"
        RETURN e
        """,
    },
    {
        "scenario_id": "D6",
        "scenario_name": "Unexpected GetSecretValue from Pod",
        "scenario_status": "DETECTABLE",
        "severity": "HIGH",
        "query": """
        MATCH (e:Event)
        WHERE e.pod_id = "pod-gitea-app"
          AND e.action = "secretsmanager:GetSecretValue"
          AND NOT (
            e.target_asset_id = "gitea-db-credentials"
            OR coalesce(e.secret_arn, "") CONTAINS "hap-db-secret"
          )
        RETURN e
        """,
    },
    {
        "scenario_id": "D7",
        "scenario_name": "GetSecretValue followed by KMS decrypt and RDS access",
        "scenario_status": "DETECTABLE",
        "severity": "HIGH",
        "query": """
        MATCH (secretRead:Event)
        WHERE secretRead.action = "secretsmanager:GetSecretValue"
        MATCH (kms:Event)
        WHERE kms.action = "kms:Decrypt"
          AND kms.event_time >= secretRead.event_time
          AND (kms.session_id = secretRead.session_id OR kms.pod_id = secretRead.pod_id)
        MATCH (rds:Event)
        WHERE rds.target_asset_id = "hap-gitea-db"
          AND rds.event_time >= kms.event_time
          AND (rds.session_id = secretRead.session_id OR rds.pod_id = secretRead.pod_id)
        RETURN secretRead AS e, kms, rds
        """,
    },
    {
        "scenario_id": "D8",
        "scenario_name": "Abnormal Pod behavior after internal ALB attack",
        "scenario_status": "DETECTABLE",
        "severity": "HIGH",
        "query": """
        MATCH (alb:Event)
        WHERE alb.source_asset_id = "hap-prod-alb"
          AND alb.target_asset_id = "pod-gitea-app"
        MATCH (e:Event)
        WHERE e.pod_id = "pod-gitea-app"
          AND e.event_time >= alb.event_time
          AND coalesce(e.is_abnormal, false) = true
        RETURN e
        """,
    },
    {
        "scenario_id": "D9",
        "scenario_name": "Unexpected direct RDS access from Pod",
        "scenario_status": "DETECTABLE",
        "severity": "HIGH",
        "query": """
        MATCH (e:Event)
        WHERE e.pod_id = "pod-gitea-app"
          AND e.target_asset_id = "hap-gitea-db"
          AND coalesce(e.connection_path, "") <> "application"
        RETURN e
        """,
    },
    {
        "scenario_id": "D10",
        "scenario_name": "DB log-only credential attempts customer S3 access",
        "scenario_status": "DETECTABLE",
        "severity": "HIGH",
        "query": """
        MATCH (e:Event)
        WHERE coalesce(e.credential_id, e.access_key_id) = "hap-onprem-db-key"
          AND e.bucket_name = "hap-customer-data-s3"
        RETURN e
        """,
    },
    {
        "scenario_id": "D11",
        "scenario_name": "Repeated AccessDenied events",
        "scenario_status": "DETECTABLE",
        "severity": "MEDIUM",
        "query": """
        MATCH (e:Event)
        WHERE e.result = "AccessDenied"
        WITH coalesce(e.actor_id, e.credential_id, e.source_ip) AS principal, collect(e) AS events
        WHERE size(events) >= 5
        UNWIND events AS e
        RETURN e
        """,
    },
    {
        "scenario_id": "D12",
        "scenario_name": "AWS API calls from unusual User-Agent",
        "scenario_status": "DETECTABLE",
        "severity": "MEDIUM",
        "query": """
        MATCH (e:Event)
        WHERE coalesce(e.user_agent, "") <> ""
          AND (
            coalesce(e.is_unusual_user_agent, false) = true
            OR NOT e.user_agent STARTS WITH "aws-cli/"
          )
        RETURN e
        """,
    },
]


def _node_labels(node: Any) -> List[str]:
    return sorted(list(getattr(node, "labels", [])))


def node_to_dict(node: Any) -> Dict[str, Any]:
    return {
        "id": node.get("id"),
        "label": node.get("displayName") or node.get("label") or node.get("name") or node.get("id"),
        "type": node.get("type") or next((label for label in _node_labels(node) if label != "Credential"), None),
        "labels": _node_labels(node),
        "environment": node.get("environment"),
        "assetRole": node.get("assetRole"),
        "sensitivityLevel": node.get("sensitivityLevel"),
        "riskLevel": node.get("riskLevel"),
        "sensitive": node.get("sensitive"),
        "namespace": node.get("namespace"),
        "irsaSubject": node.get("irsaSubject"),
        "trustedSubject": node.get("trustedSubject"),
    }


def relationship_to_dict(rel: Any) -> Dict[str, Any]:
    return {
        "id": rel.get("id") or rel.element_id,
        "source": rel.start_node.get("id"),
        "target": rel.end_node.get("id"),
        "type": rel.type,
        "action": rel.get("action"),
        "resourcePrefix": rel.get("resourcePrefix"),
        "permissionLevel": rel.get("permissionLevel"),
        "subject": rel.get("subject"),
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


def _finding_key(finding: Dict[str, Any]) -> str:
    cve_id = finding.get("cve_id") or finding.get("cveId")
    if cve_id:
        return f"cve:{str(cve_id).upper()}"
    finding_type = finding.get("finding_type") or finding.get("findingType")
    asset_id = finding.get("asset_id") or finding.get("assetId")
    if finding_type and asset_id:
        return f"type:{finding_type}:{asset_id}"
    return f"id:{finding.get('id') or finding.get('name')}"


def _normalise_finding(finding: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    status = str(finding.get("status") or "OPEN").upper()
    if status in IGNORED_FINDING_STATUSES:
        return None

    severity = str(finding.get("severity") or "UNKNOWN").upper()
    if severity not in SEVERITY_WEIGHTS:
        severity = "UNKNOWN"

    cvss_score = finding.get("cvss_score") or finding.get("cvssScore")
    try:
        cvss_score = float(cvss_score) if cvss_score is not None else None
    except (TypeError, ValueError):
        cvss_score = None

    return {
        "id": finding.get("id"),
        "name": finding.get("name"),
        "source": str(finding.get("source") or "UNKNOWN").upper(),
        "severity": severity,
        "cvss_score": cvss_score,
        "cve_id": finding.get("cve_id") or finding.get("cveId"),
        "finding_type": finding.get("finding_type") or finding.get("findingType"),
        "status": status,
        "asset_id": finding.get("asset_id") or finding.get("assetId"),
    }


def summarise_findings(findings: Iterable[Dict[str, Any]]) -> Tuple[Dict[str, Any], float]:
    deduped: Dict[str, Dict[str, Any]] = {}
    for finding in findings:
        normalised = _normalise_finding(finding)
        if normalised is None:
            continue
        key = _finding_key(normalised)
        current = deduped.get(key)
        if current is None:
            deduped[key] = normalised
            continue
        current_weight = _finding_weight(current)
        new_weight = _finding_weight(normalised)
        if new_weight > current_weight:
            deduped[key] = normalised

    active_findings = list(deduped.values())
    severity_counts = {severity.lower(): 0 for severity in ["CRITICAL", "HIGH", "MEDIUM", "LOW"]}
    for finding in active_findings:
        severity = finding["severity"].lower()
        if severity in severity_counts:
            severity_counts[severity] += 1

    weighted = sorted((_finding_weight(finding) for finding in active_findings), reverse=True)
    finding_risk = min(sum(weighted[:FINDING_COUNT_CAP]), FINDING_RISK_CAP)
    max_cvss = max(
        [finding["cvss_score"] for finding in active_findings if finding["cvss_score"] is not None],
        default=None,
    )

    summary = {
        "total": len(active_findings),
        "critical": severity_counts["critical"],
        "high": severity_counts["high"],
        "medium": severity_counts["medium"],
        "low": severity_counts["low"],
        "maxCvss": max_cvss,
        "sources": sorted({finding["source"] for finding in active_findings}),
    }
    return summary, round(finding_risk, 2)


def _finding_weight(finding: Dict[str, Any]) -> float:
    severity = str(finding.get("severity") or "UNKNOWN").upper()
    severity_weight = SEVERITY_WEIGHTS.get(severity, SEVERITY_WEIGHTS["UNKNOWN"])
    cvss_score = finding.get("cvss_score")
    if cvss_score is None:
        return severity_weight
    cvss_weight = min(max(float(cvss_score), 0.0), 10.0) / 10.0 * FINDING_RISK_CAP
    return max(severity_weight, cvss_weight)


def _asset_sensitivity_score(target: Any) -> float:
    sensitivity = str(target.get("sensitivityLevel") or "").upper()
    labels = set(_node_labels(target))
    if sensitivity == "RESTRICTED" or target.get("sensitive") is True:
        return 2.0
    if sensitivity == "CONFIDENTIAL" or labels & {"S3Bucket", "RDS", "SecretsManager", "KMSKey"}:
        return 1.5
    if sensitivity == "INTERNAL":
        return 0.8
    return 0.3


def _internet_exposure_score(rel_types: Sequence[str], nodes: Sequence[Any]) -> float:
    if "EXPOSED_TO_INTERNET" in rel_types:
        return 1.2
    if any(node.get("exposed") is True for node in nodes):
        return 0.8
    return 0.0


def _permission_risk_score(rels: Sequence[Any], nodes: Sequence[Any]) -> float:
    rel_types = {rel.type for rel in rels}
    node_labels = {label for node in nodes for label in _node_labels(node)}
    score = 0.0
    if rel_types & {"AUTHENTICATES_AS", "HAS_CREDENTIAL"}:
        score += 0.6
    if "ASSUMES_ROLE" in rel_types or "IRSA_LINKED_TO" in rel_types:
        score += 0.5
    if "HAS_PERMISSION" in rel_types or "CAN_ACCESS" in rel_types:
        score += 0.7
    if node_labels & {"IAMUser", "IAMRole", "IAMPolicy", "Credential", "SecretsManager"}:
        score += 0.4
    if any(str(rel.get("action") or "").endswith(":*") for rel in rels):
        score += 0.4
    return min(score, 2.0)


def _hop_risk_score(hop_count: int) -> float:
    if hop_count <= 3:
        return 1.0
    if hop_count <= 5:
        return 0.7
    if hop_count <= 8:
        return 0.4
    return 0.2


def calculate_risk_details(path: Any, findings: Optional[Iterable[Dict[str, Any]]] = None) -> Dict[str, Any]:
    nodes = list(path.nodes)
    rels = list(path.relationships)
    rel_types = [rel.type for rel in rels]
    finding_summary, finding_risk = summarise_findings(findings or [])

    breakdown = {
        "assetSensitivity": _asset_sensitivity_score(nodes[-1]),
        "internetExposure": _internet_exposure_score(rel_types, nodes),
        "permissionRisk": _permission_risk_score(rels, nodes),
        "hopRisk": _hop_risk_score(len(rels)),
        "findingRisk": finding_risk,
    }

    risk_score = min(sum(breakdown.values()), RISK_SCORE_CAP)
    risk_score = round(risk_score, 1)

    return {
        "riskScore": risk_score,
        "riskLevel": risk_level_from_score(risk_score),
        "riskBreakdown": {key: round(value, 2) for key, value in breakdown.items()},
        "findingSummary": finding_summary,
    }


def calculate_risk_score(path: Any) -> float:
    return calculate_risk_details(path)["riskScore"]


def risk_level_from_score(score: float) -> str:
    if score >= 8.0:
        return "CRITICAL"
    if score >= 6.0:
        return "HIGH"
    if score >= 4.0:
        return "MEDIUM"
    return "LOW"


def fetch_findings_for_node_ids(session: Any, node_ids: List[str]) -> List[Dict[str, Any]]:
    result = session.run(
        """
        MATCH (n)-[:HAS_FINDING]->(finding:Finding)
        WHERE n.id IN $nodeIds
        RETURN
          finding.id AS id,
          finding.name AS name,
          finding.source AS source,
          finding.severity AS severity,
          finding.cvss_score AS cvss_score,
          finding.cve_id AS cve_id,
          finding.finding_type AS finding_type,
          finding.status AS status,
          n.id AS asset_id
        """,
        nodeIds=node_ids,
    )
    return [dict(record) for record in result]


def convert_path_to_response(
    scenario: Dict[str, Any],
    path: Any,
    index: int,
    findings: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    nodes = [node_to_dict(node) for node in path.nodes]
    edges = [relationship_to_dict(rel) for rel in path.relationships]
    risk = calculate_risk_details(path, findings)

    source_asset_id = nodes[0]["id"]
    target_asset_id = nodes[-1]["id"]

    return {
        "pathId": f"path-{scenario['scenarioId']}-{index + 1}",
        "sourceAssetId": source_asset_id,
        "targetAssetId": target_asset_id,
        "hopCount": len(edges),
        **risk,
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
        scenario_findings = []

        for index, record in enumerate(result):
            path = record["path"]
            node_ids = [node.get("id") for node in path.nodes if node.get("id")]
            findings = fetch_findings_for_node_ids(session, node_ids)
            scenario_findings.extend(findings)
            path_response = convert_path_to_response(scenario, path, index, findings)
            paths.append(path_response)
            all_nodes.extend(path_response["nodes"])
            all_edges.extend(path_response["edges"])

        nodes = dedupe_by_id(all_nodes)
        edges = dedupe_by_id(all_edges)
        finding_summary, finding_risk = summarise_findings(scenario_findings)

        max_risk_score = max([p["riskScore"] for p in paths], default=0.0)
        max_risk_level = risk_level_from_score(max_risk_score)
        max_breakdown = _breakdown_for_max_risk_path(paths)

        return {
            "scenarioId": scenario["scenarioId"],
            "scenarioName": scenario["scenarioName"],
            "scenarioStatus": scenario["scenarioStatus"],
            "sourceAssetId": scenario["sourceAssetId"],
            "targetAssetId": scenario["targetAssetId"],
            "riskScore": max_risk_score,
            "riskLevel": max_risk_level,
            "riskBreakdown": max_breakdown,
            "findingSummary": finding_summary,
            "pathCount": len(paths),
            "nodes": nodes,
            "edges": edges,
            "paths": paths,
            "summary": scenario["summary"],
        }


def _breakdown_for_max_risk_path(paths: List[Dict[str, Any]]) -> Dict[str, float]:
    keys = ["assetSensitivity", "internetExposure", "permissionRisk", "hopRisk", "findingRisk"]
    if not paths:
        return {key: 0.0 for key in keys}
    max_path = max(paths, key=lambda path: path.get("riskScore", 0.0))
    breakdown = max_path.get("riskBreakdown", {})
    return {key: round(breakdown.get(key, 0.0), 2) for key in keys}


def _record_to_detection_result(rule: Dict[str, Any], records: List[Any]) -> Dict[str, Any]:
    event_rows = []
    for record in records:
        for value in record.values():
            if hasattr(value, "get") and value.get("event_id"):
                event_rows.append(value)

    event_ids = sorted({event.get("event_id") for event in event_rows if event.get("event_id")})
    event_times = [event.get("event_time") for event in event_rows if event.get("event_time")]
    source_asset_id = next((event.get("source_asset_id") for event in event_rows if event.get("source_asset_id")), None)
    target_asset_id = next((event.get("target_asset_id") for event in event_rows if event.get("target_asset_id")), None)
    credential_id = next(
        (
            event.get("credential_id") or event.get("access_key_id")
            for event in event_rows
            if event.get("credential_id") or event.get("access_key_id")
        ),
        None,
    )
    actor_id = next((event.get("actor_id") for event in event_rows if event.get("actor_id")), None)
    graph_node_ids = sorted(
        {
            value
            for event in event_rows
            for value in [
                event.get("source_asset_id"),
                event.get("target_asset_id"),
                event.get("credential_id") or event.get("access_key_id"),
                event.get("actor_id"),
                event.get("pod_id"),
            ]
            if value
        }
    )

    return {
        "scenario_id": rule["scenario_id"],
        "scenario_name": rule["scenario_name"],
        "scenario_status": "DETECTED" if event_ids else rule["scenario_status"],
        "severity": rule["severity"],
        "first_event_time": min(event_times) if event_times else None,
        "last_event_time": max(event_times) if event_times else None,
        "evidence_count": len(event_ids),
        "event_ids": event_ids,
        "source_asset_id": source_asset_id,
        "target_asset_id": target_asset_id,
        "credential_id": credential_id,
        "actor_id": actor_id,
        "graph_node_ids": graph_node_ids,
    }


def list_detection_rules() -> List[Dict[str, Any]]:
    return [
        {
            "scenario_id": rule["scenario_id"],
            "scenario_name": rule["scenario_name"],
            "scenario_status": rule["scenario_status"],
            "severity": rule["severity"],
        }
        for rule in DETECTION_RULES
    ]


def run_detection_rules(driver: Any) -> Dict[str, Any]:
    with driver.session(database="neo4j") as session:
        results = []
        for rule in DETECTION_RULES:
            records = list(session.run(rule["query"]))
            results.append(_record_to_detection_result(rule, records))
        return {
            "count": len(results),
            "results": results,
        }


def main() -> None:
    if GraphDatabase is None:
        raise RuntimeError("neo4j package is required to connect to Neo4j")

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
