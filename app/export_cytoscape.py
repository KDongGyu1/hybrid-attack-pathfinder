import json
from pathlib import Path
from typing import Dict, Any, List


INPUT_PATH = Path("data/path_results_mvp.json")
OUTPUT_PATH = Path("data/cytoscape_elements_mvp.json")


def make_node_element(node: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "data": {
            "id": node.get("id"),
            "label": node.get("label"),
            "type": node.get("type"),
            "environment": node.get("environment"),
            "assetRole": node.get("assetRole"),
            "sensitivityLevel": node.get("sensitivityLevel"),
            "riskLevel": node.get("riskLevel"),
        }
    }


def make_edge_element(edge: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "data": {
            "id": edge.get("id"),
            "source": edge.get("source"),
            "target": edge.get("target"),
            "label": edge.get("type"),
            "type": edge.get("type"),
            "action": edge.get("action"),
        }
    }


def dedupe_elements(elements: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seen = set()
    result = []

    for element in elements:
        element_id = element.get("data", {}).get("id")
        if element_id and element_id not in seen:
            seen.add(element_id)
            result.append(element)

    return result


def main() -> None:
    if not INPUT_PATH.exists():
        raise FileNotFoundError(f"Input file not found: {INPUT_PATH}")

    raw = json.loads(INPUT_PATH.read_text(encoding="utf-8"))

    node_elements = []
    edge_elements = []

    for scenario_result in raw.get("results", []):
        for node in scenario_result.get("nodes", []):
            node_elements.append(make_node_element(node))

        for edge in scenario_result.get("edges", []):
            edge_elements.append(make_edge_element(edge))

    node_elements = dedupe_elements(node_elements)
    edge_elements = dedupe_elements(edge_elements)

    cytoscape_response = {
        "project": raw.get("project"),
        "engine": raw.get("engine"),
        "format": "cytoscape.js",
        "elements": {
            "nodes": node_elements,
            "edges": edge_elements,
        },
        "summary": {
            "nodeCount": len(node_elements),
            "edgeCount": len(edge_elements),
        },
    }

    OUTPUT_PATH.write_text(
        json.dumps(cytoscape_response, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(json.dumps(cytoscape_response["summary"], ensure_ascii=False, indent=2))
    print(f"[OK] Cytoscape elements saved to: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()