// =====================================================
// Query 1. Internet -> S3 customer data attack path
// Scenario: EKS ServiceAccount -> IAM Role -> S3 access
// =====================================================
MATCH path = (start {id: "internet"})-[r*1..8]->(target {id: "s3-customer-data"})
WHERE ALL(rel IN relationships(path)
  WHERE type(rel) IN [
    "EXPOSED_TO_INTERNET",
    "ALLOWS_TRAFFIC",
    "CAN_MOVE_TO",
    "USES_SERVICE_ACCOUNT",
    "ASSUMES_ROLE",
    "HAS_POLICY",
    "GRANTS_PERMISSION",
    "CAN_READ",
    "CAN_WRITE",
    "CAN_ACCESS_SECRET"
  ]
)
RETURN path;


// =====================================================
// Query 2. Internet -> RDS attack path
// Scenario: Public entry point -> compromised workload -> RDS
// =====================================================
MATCH path = (start {id: "internet"})-[r*1..8]->(target {id: "rds-postgres-prod"})
WHERE ALL(rel IN relationships(path)
  WHERE type(rel) IN [
    "EXPOSED_TO_INTERNET",
    "ALLOWS_TRAFFIC",
    "CAN_MOVE_TO",
    "USES_SERVICE_ACCOUNT",
    "ASSUMES_ROLE",
    "HAS_POLICY",
    "GRANTS_PERMISSION",
    "CAN_READ",
    "CAN_WRITE",
    "CAN_ACCESS_SECRET"
  ]
)
RETURN path;


// =====================================================
// Query 3. Pod -> Secrets Manager -> RDS attack path
// Scenario: Over-permissive Secrets Manager access
// =====================================================
MATCH path = (start {id: "pod-gitea-app"})-[r*1..8]->(target {id: "rds-postgres-prod"})
WHERE ALL(rel IN relationships(path)
  WHERE type(rel) IN [
    "EXPOSED_TO_INTERNET",
    "ALLOWS_TRAFFIC",
    "CAN_MOVE_TO",
    "USES_SERVICE_ACCOUNT",
    "ASSUMES_ROLE",
    "HAS_POLICY",
    "GRANTS_PERMISSION",
    "CAN_READ",
    "CAN_WRITE",
    "CAN_ACCESS_SECRET"
  ]
)
RETURN path;