from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from neo4j import GraphDatabase

from app.path_finder import (
    NEO4J_PASSWORD,
    NEO4J_URI,
    NEO4J_USER,
    SCENARIOS,
    run_scenario,
)


app = FastAPI(
    title="Hybrid Attack Path Backend1 Engine",
    description="Neo4j 기반 하이브리드 공격 경로 탐색 엔진",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_driver():
    return GraphDatabase.driver(
        NEO4J_URI,
        auth=(NEO4J_USER, NEO4J_PASSWORD),
    )


def get_scenario_by_id(scenario_id: str) -> Optional[Dict[str, Any]]:
    for scenario in SCENARIOS:
        if scenario["scenarioId"] == scenario_id:
            return scenario
    return None


def make_cytoscape_elements(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    node_map = {}
    edge_map = {}

    for scenario_result in results:
        for node in scenario_result.get("nodes", []):
            node_id = node.get("id")
            if node_id:
                node_map[node_id] = {
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

        for edge in scenario_result.get("edges", []):
            edge_id = edge.get("id")
            if edge_id:
                edge_map[edge_id] = {
                    "data": {
                        "id": edge.get("id"),
                        "source": edge.get("source"),
                        "target": edge.get("target"),
                        "label": edge.get("type"),
                        "type": edge.get("type"),
                        "action": edge.get("action"),
                    }
                }

    return {
        "elements": {
            "nodes": list(node_map.values()),
            "edges": list(edge_map.values()),
        },
        "summary": {
            "nodeCount": len(node_map),
            "edgeCount": len(edge_map),
        },
    }


@app.get("/health")
def health_check() -> Dict[str, Any]:
    try:
        driver = get_driver()
        driver.verify_connectivity()
        driver.close()

        return {
            "status": "ok",
            "neo4j": "connected",
            "uri": NEO4J_URI,
        }

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Neo4j connection failed: {exc}",
        )


@app.get("/scenarios")
def list_scenarios() -> Dict[str, Any]:
    return {
        "count": len(SCENARIOS),
        "scenarios": [
            {
                "scenarioId": scenario["scenarioId"],
                "scenarioName": scenario["scenarioName"],
                "sourceAssetId": scenario["sourceAssetId"],
                "targetAssetId": scenario["targetAssetId"],
                "summary": scenario["summary"],
            }
            for scenario in SCENARIOS
        ],
    }


@app.get("/attack-paths")
def get_all_attack_paths() -> Dict[str, Any]:
    driver = get_driver()

    try:
        results = []

        for scenario in SCENARIOS:
            scenario_result = run_scenario(driver, scenario)
            results.append(scenario_result)

        return {
            "project": "Hybrid Attack Path Analysis System",
            "engine": "Backend 1 - Neo4j Attack Path Engine",
            "scenarioCount": len(results),
            "results": results,
        }

    finally:
        driver.close()


@app.get("/attack-paths/{scenario_id}")
def get_attack_path_by_scenario(scenario_id: str) -> Dict[str, Any]:
    scenario = get_scenario_by_id(scenario_id)

    if scenario is None:
        raise HTTPException(
            status_code=404,
            detail=f"Scenario not found: {scenario_id}",
        )

    driver = get_driver()

    try:
        return run_scenario(driver, scenario)

    finally:
        driver.close()


@app.get("/cytoscape")
def get_cytoscape_elements() -> Dict[str, Any]:
    driver = get_driver()

    try:
        results = []

        for scenario in SCENARIOS:
            scenario_result = run_scenario(driver, scenario)
            results.append(scenario_result)

        cytoscape = make_cytoscape_elements(results)

        return {
            "project": "Hybrid Attack Path Analysis System",
            "engine": "Backend 1 - Neo4j Attack Path Engine",
            "format": "cytoscape.js",
            **cytoscape,
        }

    finally:
        driver.close()