from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

from app.path_finder import (
    calculate_risk_details,
    dedupe_by_id,
    fetch_findings_for_node_ids,
    node_to_dict,
    relationship_to_dict,
    risk_level_from_score,
    _finding_key,
    _finding_weight,
    _normalise_finding,
)


PROJECT_NAME = "Hybrid Attack Path Analysis System"
ENGINE_NAME = "Backend 1 - Neo4j Dynamic Attack Path Engine"
DEFAULT_MAX_DEPTH = 8
MIN_MAX_DEPTH = 1
MAX_MAX_DEPTH = 12
DEFAULT_LIMIT = 100
MIN_LIMIT = 1
MAX_LIMIT = 200
DEFAULT_MIN_RISK_SCORE = 0.0
MIN_RISK_SCORE = 0.0
MAX_RISK_SCORE = 10.0
CANDIDATE_LIMIT_CAP = 1000

START_LABELS = [
    "Internet",
    "Credential",
    "IAMAccessKey",
    "IAMUser",
    "Pod",
    "ALB",
    "OnPremWeb",
    "OnPremDB",
]

TARGET_LABELS = [
    "S3Bucket",
    "RDS",
    "SecretsManager",
    "KMSKey",
    "ECRRepository",
]

ALLOWED_RELATIONSHIP_TYPES = [
    "EXPOSED_TO_INTERNET",
    "ALLOWS_TRAFFIC",
    "CAN_MOVE_TO",
    "CONNECTS_TO",
    "HAS_CREDENTIAL",
    "HAS_ACCESS_KEY",
    "AUTHENTICATES_AS",
    "ASSUMES_ROLE",
    "USES_SERVICE_ACCOUNT",
    "IRSA_LINKED_TO",
    "HAS_PERMISSION",
    "CAN_ACCESS",
    "CAN_ACCESS_SECRET",
    "PULLS_IMAGE_FROM",
]

EXCLUDED_RELATIONSHIP_TYPES = [
    "CONTAINS",
    "LOGS_TO",
    "HAS_FINDING",
    "ENCRYPTED_BY",
]


def validate_dynamic_path_params(
    max_depth: int = DEFAULT_MAX_DEPTH,
    limit: int = DEFAULT_LIMIT,
    min_risk_score: float = DEFAULT_MIN_RISK_SCORE,
    source_id: Optional[str] = None,
    target_id: Optional[str] = None,
) -> Dict[str, Any]:
    if not isinstance(max_depth, int):
        raise ValueError("maxDepth must be an integer")
    if max_depth < MIN_MAX_DEPTH or max_depth > MAX_MAX_DEPTH:
        raise ValueError(f"maxDepth must be between {MIN_MAX_DEPTH} and {MAX_MAX_DEPTH}")

    if not isinstance(limit, int):
        raise ValueError("limit must be an integer")
    if limit < MIN_LIMIT or limit > MAX_LIMIT:
        raise ValueError(f"limit must be between {MIN_LIMIT} and {MAX_LIMIT}")

    try:
        min_risk_score = float(min_risk_score)
    except (TypeError, ValueError) as exc:
        raise ValueError("minRiskScore must be numeric") from exc
    if min_risk_score < MIN_RISK_SCORE or min_risk_score > MAX_RISK_SCORE:
        raise ValueError(f"minRiskScore must be between {MIN_RISK_SCORE:g} and {MAX_RISK_SCORE:g}")

    source_id = _normalise_optional_id(source_id, "sourceId")
    target_id = _normalise_optional_id(target_id, "targetId")

    return {
        "sourceId": source_id,
        "targetId": target_id,
        "maxDepth": max_depth,
        "limit": limit,
        "minRiskScore": min_risk_score,
    }


def build_dynamic_path_query(max_depth: int) -> str:
    validate_dynamic_path_params(max_depth=max_depth)
    rel_types = "|".join(ALLOWED_RELATIONSHIP_TYPES)
    return f"""
    MATCH path = (source)-[:{rel_types}*1..{max_depth}]->(target)
    WHERE (
        ($sourceId IS NULL AND any(label IN labels(source) WHERE label IN $startLabels))
        OR source.id = $sourceId
    )
      AND (
        ($targetId IS NULL AND (target.sensitive = true OR any(label IN labels(target) WHERE label IN $targetLabels)))
        OR target.id = $targetId
    )
      AND source.id IS NOT NULL
      AND target.id IS NOT NULL
      AND source.id <> target.id
      AND all(node IN nodes(path) WHERE node.id IS NOT NULL)
      AND all(i IN range(0, size(nodes(path)) - 1)
              WHERE single(node IN nodes(path) WHERE elementId(node) = elementId(nodes(path)[i])))
    RETURN path
    LIMIT $candidateLimit
    """


def run_dynamic_paths(
    driver: Any,
    max_depth: int = DEFAULT_MAX_DEPTH,
    limit: int = DEFAULT_LIMIT,
    min_risk_score: float = DEFAULT_MIN_RISK_SCORE,
    source_id: Optional[str] = None,
    target_id: Optional[str] = None,
) -> Dict[str, Any]:
    filters = validate_dynamic_path_params(
        max_depth=max_depth,
        limit=limit,
        min_risk_score=min_risk_score,
        source_id=source_id,
        target_id=target_id,
    )
    query = build_dynamic_path_query(filters["maxDepth"])
    candidate_limit = _candidate_limit(filters["limit"])

    with driver.session(database="neo4j") as session:
        records = session.run(
            query,
            sourceId=filters["sourceId"],
            targetId=filters["targetId"],
            startLabels=START_LABELS,
            targetLabels=TARGET_LABELS,
            candidateLimit=candidate_limit,
        )

        paths: List[Dict[str, Any]] = []
        all_nodes: List[Dict[str, Any]] = []
        all_edges: List[Dict[str, Any]] = []
        seen = set()

        for record in records:
            path = record["path"]
            signature = _path_signature(path)
            if signature in seen:
                continue
            seen.add(signature)

            node_ids = [node.get("id") for node in path.nodes if node.get("id")]
            findings = _dedupe_active_findings(fetch_findings_for_node_ids(session, node_ids))
            path_response = convert_dynamic_path_to_response(path, len(paths), findings)

            if path_response["riskScore"] < filters["minRiskScore"]:
                continue

            paths.append(path_response)
            all_nodes.extend(path_response["nodes"])
            all_edges.extend(path_response["edges"])

    paths = sorted(
        paths,
        key=lambda item: (
            -item["riskScore"],
            item["hopCount"],
            item["sourceAssetId"],
            item["targetAssetId"],
        ),
    )[: filters["limit"]]

    paths = [_renumber_path(path, index) for index, path in enumerate(paths)]
    nodes = dedupe_by_id([node for path in paths for node in path["nodes"]])
    edges = dedupe_by_id([edge for path in paths for edge in path["edges"]])
    elements = make_cytoscape_elements(nodes, edges)
    highest_risk_score = max([path["riskScore"] for path in paths], default=0.0)

    return {
        "project": PROJECT_NAME,
        "engine": ENGINE_NAME,
        "mode": "DYNAMIC",
        "filters": filters,
        "pathCount": len(paths),
        "nodeCount": len(nodes),
        "edgeCount": len(edges),
        "highestRiskScore": highest_risk_score,
        "highestRiskLevel": risk_level_from_score(highest_risk_score),
        "riskLevelCounts": _risk_level_counts(paths),
        "nodes": nodes,
        "edges": edges,
        "elements": elements,
        "paths": paths,
    }


def convert_dynamic_path_to_response(
    path: Any,
    index: int,
    findings: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    findings = findings or []
    nodes = [node_to_dict(node) for node in path.nodes]
    edges = [relationship_to_dict(rel) for rel in path.relationships]
    risk = calculate_risk_details(path, findings)
    node_ids = [node["id"] for node in nodes]
    edge_ids = [edge["id"] for edge in edges]
    source_asset_id = node_ids[0]
    target_asset_id = node_ids[-1]

    return {
        "pathId": f"dynamic-path-{index + 1}",
        "pathType": "DYNAMIC",
        "sourceAssetId": source_asset_id,
        "targetAssetId": target_asset_id,
        "hopCount": len(edges),
        "riskScore": risk["riskScore"],
        "riskLevel": risk["riskLevel"],
        "riskBreakdown": risk["riskBreakdown"],
        "findingSummary": risk["findingSummary"],
        "findingCount": len(findings),
        "findings": findings,
        "nodeIds": node_ids,
        "edgeIds": edge_ids,
        "summary": _path_summary(source_asset_id, target_asset_id, len(edges), risk["riskScore"]),
        "nodes": nodes,
        "edges": edges,
    }


def make_cytoscape_elements(nodes: Sequence[Dict[str, Any]], edges: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    return {
        "nodes": [
            {
                "data": {
                    "id": node.get("id"),
                    "label": node.get("label"),
                    "type": node.get("type"),
                    "environment": node.get("environment"),
                    "riskLevel": node.get("riskLevel"),
                    "sensitive": node.get("sensitive"),
                    "labels": node.get("labels"),
                    "namespace": node.get("namespace"),
                    "irsaSubject": node.get("irsaSubject"),
                    "trustedSubject": node.get("trustedSubject"),
                }
            }
            for node in nodes
        ],
        "edges": [
            {
                "data": {
                    "id": edge.get("id"),
                    "source": edge.get("source"),
                    "target": edge.get("target"),
                    "label": edge.get("type"),
                    "type": edge.get("type"),
                    "action": edge.get("action"),
                    "resourcePrefix": edge.get("resourcePrefix"),
                    "permissionLevel": edge.get("permissionLevel"),
                    "subject": edge.get("subject"),
                }
            }
            for edge in edges
        ],
    }


def _candidate_limit(limit: int) -> int:
    return min(max(limit * 10, limit), CANDIDATE_LIMIT_CAP)


def _dedupe_active_findings(findings: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    deduped: Dict[str, Dict[str, Any]] = {}
    for finding in findings:
        normalised = _normalise_finding(finding)
        if normalised is None:
            continue
        key = _finding_key(normalised)
        current = deduped.get(key)
        if current is None or _finding_weight(normalised) > _finding_weight(current):
            deduped[key] = normalised
    return sorted(deduped.values(), key=lambda item: (-_finding_weight(item), item.get("id") or ""))


def _normalise_optional_id(value: Optional[str], field_name: str) -> Optional[str]:
    if value is None:
        return None
    value = str(value).strip()
    if not value:
        return None
    if len(value) > 200:
        raise ValueError(f"{field_name} is too long")
    return value


def _path_signature(path: Any) -> Tuple[Tuple[str, ...], Tuple[Tuple[str, str, str], ...]]:
    node_ids = tuple(node.get("id") for node in path.nodes)
    edge_signature = tuple(
        (
            rel.start_node.get("id"),
            rel.type,
            rel.end_node.get("id"),
        )
        for rel in path.relationships
    )
    return node_ids, edge_signature


def _path_summary(source_asset_id: str, target_asset_id: str, hop_count: int, risk_score: float) -> str:
    return (
        f"Dynamic attack path from {source_asset_id} to {target_asset_id} "
        f"with {hop_count} hops and risk score {risk_score}."
    )


def _renumber_path(path: Dict[str, Any], index: int) -> Dict[str, Any]:
    return {
        **path,
        "pathId": f"dynamic-path-{index + 1}",
    }


def _risk_level_counts(paths: Sequence[Dict[str, Any]]) -> Dict[str, int]:
    counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
    for path in paths:
        level = path.get("riskLevel") or "LOW"
        if level in counts:
            counts[level] += 1
    return counts
