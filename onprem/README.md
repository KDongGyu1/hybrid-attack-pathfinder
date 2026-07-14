# onprem/ — 온프레미스 랩 (Vagrant + VirtualBox)

하이브리드 공격 경로 탐색 시스템의 "온프레미스" 절반. WordPress 서버에 저장된 IAM 액세스 키가
AWS(S3)로 넘어가는 경계 이동을 재현한다 (시나리오 S1/S3의 진입점).

## 구성

| VM | 역할 | IP | 노출 |
| --- | --- | --- | --- |
| `hap-onprem-web` | Apache+PHP+WordPress, AWS CLI, 백업/로그 에이전트 | `192.168.0.10` | host:8080 → 80 |
| `hap-onprem-db` | MySQL 8.0 (WordPress 백엔드), 로그 에이전트 | `192.168.0.30` | 없음 (web에서만 접근) |

두 VM은 private network `192.168.0.0/24`로 통신한다 (web → db:3306).

```
onprem/
├─ Vagrantfile              # VM 2대(web·db) + network + provision
├─ provision/
│  ├─ web.sh                # Apache/PHP/WordPress/AWS CLI/로그·백업 cron
│  └─ db.sh                 # MySQL 8.0 + 로그 cron
├─ scripts/
│  ├─ backup-to-s3.sh       # WordPress 데이터 → hap-customer-data-s3
│  └─ ship-logs-to-s3.sh    # 로그 → hap-soc-log-s3/onprem/...
└─ README.md
```

## 실행 방법

```bash
cd onprem

# IAM 키가 확정되면 아래 환경변수로 주입 (미설정 시 placeholder 사용)
export HAP_WEB_AWS_ACCESS_KEY_ID=...
export HAP_WEB_AWS_SECRET_ACCESS_KEY=...
export HAP_DB_AWS_ACCESS_KEY_ID=...
export HAP_DB_AWS_SECRET_ACCESS_KEY=...

vagrant up
```

기동 후 `http://localhost:8080` 에서 WordPress 설치 마법사 접근 가능.

## 로그/백업 흐름

- collector는 AWS private 이라 온프렘에서 직접 전송 불가 → **IAM 키로 S3에 직접 저장**하고
  SOC collector가 S3에서 읽어 정제한다.
- 전송 방식은 **AWS CLI + cron** (`aws s3 cp`), Filebeat는 S3 직접 출력을 지원하지 않아 채택하지 않음.

| 출처 | 저장 위치(S3 prefix) |
| --- | --- |
| WordPress 웹/앱 (Apache access/error) | `hap-soc-log-s3/onprem/wordpress/` |
| MySQL (general/slow query) | `hap-soc-log-s3/onprem/mysql/` |
| OS (syslog, auth.log, auditd) | `hap-soc-log-s3/onprem/os/` |
| 백업 실행 로그 | `hap-soc-log-s3/onprem/backup/` |
| WordPress 데이터(파일+DB 덤프) | `hap-customer-data-s3` |

백업 로그(성공/실패·버킷·실행 계정)는 CloudTrail의 S3 PutObject 기록과 대조해
"정상 백업 vs 키 탈취 악용"을 판별하는 데 쓰인다 (시나리오 S3 탐지 핵심).

## 주의사항

1. **IAM 키 실값을 이 폴더 어디에도 하드코딩하지 않는다.** Vagrantfile은 항상 환경변수를
   읽어 placeholder(`REPLACE_WITH_IAM_ACCESS_KEY` 등)로 대체한다. 실값은 별도 키 설계 확정 후 주입.
2. **의도적 취약 앱(플러그인 CVE 등)을 심지 않는다.** WordPress는 표준 설치이며, 공격 표면은
   앱 취약점이 아니라 **web 서버 로컬에 저장된 IAM 키**뿐이다.
3. AWS 인프라(S3 버킷, collector 등)는 Terraform이 관리 — 이 폴더는 접근만 한다.
